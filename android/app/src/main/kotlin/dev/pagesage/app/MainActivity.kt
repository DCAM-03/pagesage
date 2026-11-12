package dev.pagesage.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.content.Intent
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var fileExports: FileExportHandler? = null
    @Volatile private var destroyed = false

    // Reuse PdfRenderer per absolute path — opening large PDFs dominates cost.
    private val pdfCache = ConcurrentHashMap<String, CachedPdf>()

    // Reuse ML Kit clients (model load is expensive).
    @Volatile private var chineseRecognizer: TextRecognizer? = null
    @Volatile private var latinRecognizer: TextRecognizer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        fileExports = FileExportHandler(this, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pagesage/pdf_raster",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "renderPage" -> executor.execute {
                    try {
                        val payload = renderPdfPage(call)
                        reply { result.success(payload) }
                    } catch (error: Exception) {
                        reply {
                            result.error(
                                rasterErrorCode(error),
                                error.message ?: "render_failed",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pagesage/ocr",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(true)
                "supportedLanguages" ->
                    result.success(listOf("zh-Hans", "zh-Hant", "zh", "en"))
                "recognizePdfPage" -> executor.execute {
                    try {
                        val payload = recognizePdfPage(call)
                        reply { result.success(payload) }
                    } catch (error: Exception) {
                        reply {
                            result.error(
                                ocrErrorCode(error),
                                error.message ?: "ocr_failed",
                                null,
                            )
                        }
                    }
                }
                "recognize" -> executor.execute {
                    try {
                        val payload = recognizeImageBytes(call)
                        reply { result.success(payload) }
                    } catch (error: Exception) {
                        reply {
                            result.error(
                                ocrErrorCode(error),
                                error.message ?: "ocr_failed",
                                null,
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        destroyed = true
        fileExports?.dispose()
        fileExports = null
        executor.execute {
            closePdfCache()
            chineseRecognizer?.close()
            latinRecognizer?.close()
            chineseRecognizer = null
            latinRecognizer = null
        }
        executor.shutdown()
        super.onDestroy()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (fileExports?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun reply(action: () -> Unit) {
        runOnUiThread { if (!destroyed) action() }
    }

    private fun renderPdfPage(call: MethodCall): Map<String, Any> {
        val path = call.argument<String>("path")
            ?: throw IllegalArgumentException("missing path")
        val pageNumber = call.argument<Int>("pageNumber")
            ?: throw IllegalArgumentException("missing pageNumber")
        val dpi = call.argument<Int>("dpi") ?: 200
        val maxEdge = call.argument<Int>("maxEdge") ?: 2200
        val maxPixels = call.argument<Int>("maxPixels") ?: 5000000
        val format = (call.argument<String>("format") ?: "jpeg").lowercase(Locale.ROOT)
        val quality = (call.argument<Int>("quality") ?: 85).coerceIn(40, 100)

        val bitmap = renderBitmap(path, pageNumber, dpi, maxEdge, maxPixels)
        return try {
            val stream = ByteArrayOutputStream()
            val ok = if (format == "png") {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            } else {
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
            }
            if (!ok) {
                throw RuntimeException("image_encode_failed")
            }
            mapOf(
                "bytes" to stream.toByteArray(),
                "width" to bitmap.width,
                "height" to bitmap.height,
            )
        } finally {
            bitmap.recycle()
        }
    }

    /** Fast path: bitmap stays on native heap — no JPEG/PNG channel transfer. */
    private fun recognizePdfPage(call: MethodCall): Map<String, Any?> {
        val path = call.argument<String>("path")
            ?: throw IllegalArgumentException("missing path")
        val pageNumber = call.argument<Int>("pageNumber")
            ?: throw IllegalArgumentException("missing pageNumber")
        val languageHint = call.argument<String>("languageHint") ?: "zh-Hans"
        val dpi = call.argument<Int>("dpi") ?: 200
        val maxEdge = call.argument<Int>("maxEdge") ?: 2200

        val bitmap = renderBitmap(path, pageNumber, dpi, maxEdge)
        return try {
            ocrBitmap(bitmap, languageHint)
        } finally {
            bitmap.recycle()
        }
    }

    private fun recognizeImageBytes(call: MethodCall): Map<String, Any?> {
        val imageBytes = call.argument<ByteArray>("imageBytes")
            ?: throw IllegalArgumentException("missing imageBytes")
        val languageHint = call.argument<String>("languageHint") ?: "zh-Hans"
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
        require(options.outWidth > 0 && options.outHeight > 0) { "invalid_image" }
        options.inSampleSize = 1
        while (options.outWidth.toDouble() * options.outHeight /
            options.inSampleSize / options.inSampleSize > 5000000 ||
            max(options.outWidth, options.outHeight) / options.inSampleSize > 4096) {
            options.inSampleSize *= 2
        }
        options.inJustDecodeBounds = false
        val bitmap = BitmapFactory.decodeByteArray(
            imageBytes,
            0,
            imageBytes.size,
            options,
        ) ?: throw RuntimeException("invalid_image")
        return try {
            ocrBitmap(bitmap, languageHint)
        } finally {
            bitmap.recycle()
        }
    }

    private fun ocrBitmap(bitmap: Bitmap, languageHint: String): Map<String, Any?> {
        val recognizer = recognizerFor(languageHint)
        val image = InputImage.fromBitmap(bitmap, 0)
        val visionText = com.google.android.gms.tasks.Tasks.await(recognizer.process(image))
        val imageWidth = bitmap.width.coerceAtLeast(1).toDouble()
        val imageHeight = bitmap.height.coerceAtLeast(1).toDouble()
        val blocks = ArrayList<Map<String, Any?>>()

        // Line-level boxes: native ::selection paints as one continuous range per
        // line (EPUB/PDF.js feel). Word boxes look like per-glyph islands.
        for (block in visionText.textBlocks) {
            for (line in block.lines) {
                val lineText = line.text?.trim().orEmpty()
                if (lineText.isEmpty()) {
                    continue
                }
                val box = line.boundingBox
                if (box != null && box.width() > 0 && box.height() > 0) {
                    blocks.add(
                        mapOf(
                            "text" to lineText,
                            "left" to (box.left.toDouble() / imageWidth).coerceIn(0.0, 1.0),
                            "top" to (box.top.toDouble() / imageHeight).coerceIn(0.0, 1.0),
                            "width" to (box.width().toDouble() / imageWidth).coerceIn(0.0, 1.0),
                            "height" to (box.height().toDouble() / imageHeight).coerceIn(0.0, 1.0),
                        ),
                    )
                } else {
                    blocks.add(mapOf("text" to lineText))
                }
            }
        }

        return mapOf(
            "text" to (visionText.text ?: ""),
            "engine" to "mlkit",
            "language" to languageHint,
            "confidence" to null,
            "imageWidth" to bitmap.width,
            "imageHeight" to bitmap.height,
            "blocks" to blocks,
        )
    }

    private fun recognizerFor(languageHint: String): TextRecognizer {
        return if (prefersChinese(languageHint)) {
            chineseRecognizer ?: TextRecognition
                .getClient(ChineseTextRecognizerOptions.Builder().build())
                .also { chineseRecognizer = it }
        } else {
            latinRecognizer ?: TextRecognition
                .getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                .also { latinRecognizer = it }
        }
    }

    private fun renderBitmap(
        path: String,
        pageNumber: Int,
        dpi: Int,
        maxEdge: Int,
        maxPixels: Int = 5000000,
    ): Bitmap {
        require(dpi > 0 && maxEdge > 0 && maxPixels > 0) { "invalid render budget" }
        val file = File(path)
        if (!file.exists()) {
            throw FileNotFound(path)
        }
        val absolute = file.absolutePath
        val lastModified = file.lastModified()
        val cached = pdfCache[absolute]
        val pdf = if (cached != null && cached.lastModified == lastModified) {
            cached
        } else {
            cached?.closeQuietly()
            val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            val renderer = try {
                PdfRenderer(pfd)
            } catch (error: Exception) {
                pfd.close()
                throw error
            }
            val created = CachedPdf(pfd, renderer, lastModified)
            pdfCache[absolute] = created
            // Keep cache bounded (one book is typical; drop others).
            if (pdfCache.size > 2) {
                val keys = pdfCache.keys.filter { it != absolute }
                for (key in keys) {
                    pdfCache.remove(key)?.closeQuietly()
                }
            }
            created
        }

        synchronized(pdf.lock) {
            if (pageNumber < 1 || pageNumber > pdf.renderer.pageCount) {
                throw PageOutOfRange(pageNumber, pdf.renderer.pageCount)
            }
            pdf.renderer.openPage(pageNumber - 1).use { page ->
                val scale = dpi / 72.0
                var width = max(1, (page.width * scale).roundToInt())
                var height = max(1, (page.height * scale).roundToInt())
                val longest = max(width, height)
                if (longest > maxEdge) {
                    val factor = maxEdge.toDouble() / longest.toDouble()
                    width = max(1, (width * factor).roundToInt())
                    height = max(1, (height * factor).roundToInt())
                }
                val pixels = width.toDouble() * height.toDouble()
                val budget = maxPixels.coerceAtMost(5000000)
                if (pixels > budget) {
                    val factor = sqrt(budget / pixels)
                    width = max(1, (width * factor).toInt())
                    height = max(1, (height * factor).toInt())
                }
                width = width.coerceAtMost(budget)
                height = height.coerceAtMost(budget / width)
                val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                bitmap.eraseColor(Color.WHITE)
                try {
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                } catch (error: Exception) {
                    bitmap.recycle()
                    throw error
                }
                return bitmap
            }
        }
    }

    private fun closePdfCache() {
        for (entry in pdfCache.values) {
            entry.closeQuietly()
        }
        pdfCache.clear()
    }

    private fun prefersChinese(languageHint: String): Boolean {
        val normalized = languageHint.lowercase(Locale.ROOT)
        return normalized.startsWith("zh") ||
            normalized.contains("hans") ||
            normalized.contains("hant") ||
            normalized.contains("chinese")
    }

    private fun rasterErrorCode(error: Exception): String {
        return when (error) {
            is FileNotFound -> "file_not_found"
            is PageOutOfRange -> "page_out_of_range"
            else -> "render_failed"
        }
    }

    private fun ocrErrorCode(error: Exception): String {
        return when (error) {
            is FileNotFound -> "file_not_found"
            is PageOutOfRange -> "page_out_of_range"
            else -> "ocr_failed"
        }
    }

    private class CachedPdf(
        val pfd: ParcelFileDescriptor,
        val renderer: PdfRenderer,
        val lastModified: Long,
    ) {
        val lock = Any()

        fun closeQuietly() {
            try {
                renderer.close()
            } catch (_: Exception) {
            }
            try {
                pfd.close()
            } catch (_: Exception) {
            }
        }
    }

    private class FileNotFound(path: String) :
        Exception("file not found: $path")

    private class PageOutOfRange(page: Int, count: Int) :
        Exception("page $page out of range 1..$count")
}
