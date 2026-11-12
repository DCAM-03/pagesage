package dev.pagesage.app

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class FileExportHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "pagesage/files")
    private val executor = Executors.newSingleThreadExecutor()
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSource: File? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "saveExport") {
                result.notImplemented()
            } else if (pendingResult != null) {
                result.error("export_busy", "Another export is in progress", null)
            } else {
                val sourcePath = call.argument<String>("sourcePath")
                val source = sourcePath?.let { File(it) }
                if (source == null || !source.isFile) {
                    result.error("file_not_found", "Export file is unavailable", null)
                } else {
                    pendingResult = result
                    pendingSource = source
                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = call.argument<String>("mimeType") ?: "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: source.name)
                        }
                        activity.startActivityForResult(intent, REQUEST_EXPORT)
                    } catch (_: Exception) {
                        pendingResult = null
                        pendingSource = null
                        result.error("export_unavailable", "Document picker is unavailable", null)
                    }
                }
            }
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_EXPORT) return false
        val result = pendingResult ?: return true
        val source = pendingSource
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) {
            pendingResult = null
            pendingSource = null
            result.success(null)
            return true
        }
        executor.execute {
            var succeeded = false
            try {
                activity.contentResolver.openOutputStream(uri, "wt").use { output ->
                    checkNotNull(output)
                    source.inputStream().use { input -> input.copyTo(output) }
                    output.flush()
                }
                succeeded = true
            } catch (_: Exception) {
            }
            activity.runOnUiThread {
                if (pendingResult === result) {
                    pendingResult = null
                    pendingSource = null
                    if (succeeded) {
                        result.success(uri.toString())
                    } else {
                        result.error("export_write_failed", "Could not save the exported document", null)
                    }
                }
            }
        }
        return true
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingResult?.error("export_interrupted", "Export activity was closed", null)
        pendingResult = null
        pendingSource = null
        executor.shutdown()
    }

    companion object {
        private const val REQUEST_EXPORT = 7354
    }
}
