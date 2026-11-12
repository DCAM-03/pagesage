#include "pagesage_native_channels.h"

#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "pdf_render_budget.h"

// WinRT PDF raster + OCR. Requires Windows 10+ and linked WindowsApp.lib.
// IMPORTANT: Flutter platform channels run on an STA UI thread. Blocking
// WinRT .get() on that thread asserts (!is_sta_thread). All WinRT work is
// dispatched to a dedicated MTA worker thread.
#include <windows.h>
#include <winrt/Windows.Data.Pdf.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Storage.h>
#include <winrt/base.h>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()), nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size);
  return result;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

const std::string* ReadString(const EncodableMap& map, const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return std::get_if<std::string>(&it->second);
}

const std::vector<uint8_t>* ReadBytes(const EncodableMap& map,
                                      const char* key) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return std::get_if<std::vector<uint8_t>>(&it->second);
}

int32_t ReadInt(const EncodableMap& map, const char* key, int32_t fallback) {
  const auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }
  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int32_t>(*value);
  }
  return fallback;
}

struct CachedPdfDocument {
  winrt::Windows::Data::Pdf::PdfDocument document{nullptr};
  FILETIME last_write{};
  std::mutex mutex;
};

std::mutex g_pdf_cache_mutex;
std::unordered_map<std::string, std::shared_ptr<CachedPdfDocument>> g_pdf_cache;

std::mutex g_ocr_engine_mutex;
std::unordered_map<std::string, winrt::Windows::Media::Ocr::OcrEngine>
    g_ocr_engines;
std::mutex g_ocr_recognition_mutex;

bool GetFileLastWrite(const std::wstring& path, FILETIME* out) {
  const HANDLE handle =
      CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                  OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (handle == INVALID_HANDLE_VALUE) {
    return false;
  }
  FILETIME create{}, access{}, write{};
  const BOOL ok = GetFileTime(handle, &create, &access, &write);
  CloseHandle(handle);
  if (!ok) {
    return false;
  }
  *out = write;
  return true;
}

bool SameFileTime(const FILETIME& a, const FILETIME& b) {
  return a.dwLowDateTime == b.dwLowDateTime &&
         a.dwHighDateTime == b.dwHighDateTime;
}

std::shared_ptr<CachedPdfDocument> GetOrOpenPdf(const std::string& path) {
  const auto wide_path = Utf8ToWide(path);
  FILETIME write{};
  if (!GetFileLastWrite(wide_path, &write)) {
    throw std::runtime_error("file not found");
  }

  {
    std::lock_guard<std::mutex> lock(g_pdf_cache_mutex);
    const auto it = g_pdf_cache.find(path);
    if (it != g_pdf_cache.end() &&
        SameFileTime(it->second->last_write, write)) {
      return it->second;
    }
  }

  auto file =
      winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(wide_path)
          .get();
  auto document =
      winrt::Windows::Data::Pdf::PdfDocument::LoadFromFileAsync(file).get();
  auto cached = std::make_shared<CachedPdfDocument>();
  cached->document = document;
  cached->last_write = write;

  std::lock_guard<std::mutex> lock(g_pdf_cache_mutex);
  // Bound cache: keep the document just opened, drop others.
  g_pdf_cache.clear();
  g_pdf_cache.emplace(path, cached);
  return cached;
}

winrt::Windows::Graphics::Imaging::SoftwareBitmap RenderPageBitmap(
    const std::shared_ptr<CachedPdfDocument>& cached, int32_t page_number,
    int32_t dpi, int32_t max_edge, int32_t max_pixels, uint32_t* out_width,
    uint32_t* out_height) {
  std::lock_guard<std::mutex> lock(cached->mutex);
  auto document = cached->document;
  if (page_number < 1 ||
      page_number > static_cast<int32_t>(document.PageCount())) {
    throw std::runtime_error("page_out_of_range");
  }

  auto page = document.GetPage(static_cast<uint32_t>(page_number - 1));
  const auto size = page.Size();
  pagesage::ComputeOutputSize(size.Width, size.Height, dpi, max_edge,
                              max_pixels, out_width, out_height);

  winrt::Windows::Data::Pdf::PdfPageRenderOptions options;
  options.DestinationWidth(*out_width);
  options.DestinationHeight(*out_height);

  auto stream = winrt::Windows::Storage::Streams::InMemoryRandomAccessStream();
  page.RenderToStreamAsync(stream, options).get();
  page.Close();
  stream.Seek(0);

  auto decoder =
      winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(stream)
          .get();
  return decoder
      .GetSoftwareBitmapAsync(
          winrt::Windows::Graphics::Imaging::BitmapPixelFormat::Bgra8,
          winrt::Windows::Graphics::Imaging::BitmapAlphaMode::Premultiplied)
      .get();
}

std::vector<uint8_t> EncodeBitmap(
    const winrt::Windows::Graphics::Imaging::SoftwareBitmap& software_bitmap,
    bool jpeg, int32_t quality) {
  auto encoder_stream =
      winrt::Windows::Storage::Streams::InMemoryRandomAccessStream();
  const auto encoder_id =
      jpeg ? winrt::Windows::Graphics::Imaging::BitmapEncoder::JpegEncoderId()
           : winrt::Windows::Graphics::Imaging::BitmapEncoder::PngEncoderId();
  auto encoder = winrt::Windows::Graphics::Imaging::BitmapEncoder::CreateAsync(
                     encoder_id, encoder_stream)
                     .get();
  encoder.SetSoftwareBitmap(software_bitmap);
  if (jpeg) {
    // Quality 0-1 for BitmapPropertySet is not used here; Jpeg encoder uses
    // default quality which is fine for OCR fallback path.
    (void)quality;
  }
  encoder.FlushAsync().get();
  encoder_stream.Seek(0);
  const uint64_t size_bytes = encoder_stream.Size();
  auto reader = winrt::Windows::Storage::Streams::DataReader(encoder_stream);
  reader.LoadAsync(static_cast<uint32_t>(size_bytes)).get();
  std::vector<uint8_t> bytes(static_cast<size_t>(size_bytes));
  reader.ReadBytes(bytes);
  return bytes;
}

EncodableMap RenderPdfPage(const EncodableMap& args) {
  const std::string* path = ReadString(args, "path");
  if (path == nullptr || path->empty()) {
    throw std::runtime_error("missing path");
  }
  const int32_t page_number = ReadInt(args, "pageNumber", 0);
  const int32_t dpi = ReadInt(args, "dpi", 200);
  const int32_t max_edge = ReadInt(args, "maxEdge", 2200);
  const int32_t max_pixels = ReadInt(args, "maxPixels", 5000000);
  const std::string* format_ptr = ReadString(args, "format");
  const bool jpeg =
      format_ptr == nullptr || format_ptr->empty() || *format_ptr == "jpeg";
  const int32_t quality = ReadInt(args, "quality", 85);
  if (page_number < 1) {
    throw std::runtime_error("page_out_of_range");
  }

  auto cached = GetOrOpenPdf(*path);
  uint32_t out_width = 0;
  uint32_t out_height = 0;
  auto software_bitmap = RenderPageBitmap(cached, page_number, dpi, max_edge,
                                          max_pixels, &out_width, &out_height);
  auto bytes = EncodeBitmap(software_bitmap, jpeg, quality);

  EncodableMap result;
  result[EncodableValue("bytes")] = EncodableValue(bytes);
  result[EncodableValue("width")] =
      EncodableValue(static_cast<int32_t>(out_width));
  result[EncodableValue("height")] =
      EncodableValue(static_cast<int32_t>(out_height));
  return result;
}

winrt::Windows::Media::Ocr::OcrEngine GetOcrEngine(
    const std::string& language_hint) {
  std::lock_guard<std::mutex> lock(g_ocr_engine_mutex);
  const auto found = g_ocr_engines.find(language_hint);
  if (found != g_ocr_engines.end()) return found->second;
  const winrt::Windows::Globalization::Language language(
      winrt::to_hstring(language_hint));
  if (!winrt::Windows::Media::Ocr::OcrEngine::IsLanguageSupported(language)) {
    throw std::runtime_error("ocr_language_unavailable");
  }
  auto engine =
      winrt::Windows::Media::Ocr::OcrEngine::TryCreateFromLanguage(language);
  if (engine) g_ocr_engines.emplace(language_hint, engine);
  return engine;
}

EncodableMap OcrSoftwareBitmap(
    const winrt::Windows::Graphics::Imaging::SoftwareBitmap& software_bitmap,
    const std::string& language_hint) {
  std::lock_guard<std::mutex> lock(g_ocr_recognition_mutex);
  auto engine = GetOcrEngine(language_hint);
  if (!engine) {
    throw std::runtime_error("ocr_unavailable");
  }
  auto ocr_result = engine.RecognizeAsync(software_bitmap).get();
  const std::wstring text_wide = ocr_result.Text().c_str();
  const std::string text = WideToUtf8(text_wide);

  const double image_width = static_cast<double>(
      software_bitmap.PixelWidth() < 1 ? 1 : software_bitmap.PixelWidth());
  const double image_height = static_cast<double>(
      software_bitmap.PixelHeight() < 1 ? 1 : software_bitmap.PixelHeight());

  EncodableList blocks;
  try {
    // Line-level boxes so native ::selection paints as one continuous range
    // per line (EPUB/PDF.js feel). Word boxes look like per-glyph islands.
    for (auto const& line : ocr_result.Lines()) {
      const std::wstring line_wide = line.Text().c_str();
      const std::string line_text = WideToUtf8(line_wide);
      if (line_text.empty()) {
        continue;
      }
      EncodableMap block;
      block[EncodableValue("text")] = EncodableValue(line_text);
      try {
        // WinRT OCR: Words have BoundingRect; line box = union of words.
        double min_x = image_width;
        double min_y = image_height;
        double max_x = 0.0;
        double max_y = 0.0;
        bool any = false;
        for (auto const& word : line.Words()) {
          const auto rect = word.BoundingRect();
          const double x1 = static_cast<double>(rect.X);
          const double y1 = static_cast<double>(rect.Y);
          const double x2 = static_cast<double>(rect.X + rect.Width);
          const double y2 = static_cast<double>(rect.Y + rect.Height);
          if (!any || x1 < min_x) min_x = x1;
          if (!any || y1 < min_y) min_y = y1;
          if (!any || x2 > max_x) max_x = x2;
          if (!any || y2 > max_y) max_y = y2;
          any = true;
        }
        if (any && max_x > min_x && max_y > min_y) {
          block[EncodableValue("left")] = EncodableValue((min_x / image_width));
          block[EncodableValue("top")] = EncodableValue((min_y / image_height));
          block[EncodableValue("width")] =
              EncodableValue(((max_x - min_x) / image_width));
          block[EncodableValue("height")] =
              EncodableValue(((max_y - min_y) / image_height));
        }
      } catch (...) {
        // Geometry optional.
      }
      blocks.emplace_back(block);
    }
  } catch (...) {
    // If line enumeration fails, still return plain text.
  }

  EncodableMap result;
  result[EncodableValue("text")] = EncodableValue(text);
  result[EncodableValue("engine")] = EncodableValue(std::string("winrt"));
  result[EncodableValue("language")] = EncodableValue(
      winrt::to_string(engine.RecognizerLanguage().LanguageTag()));
  result[EncodableValue("imageWidth")] =
      EncodableValue(static_cast<int32_t>(software_bitmap.PixelWidth()));
  result[EncodableValue("imageHeight")] =
      EncodableValue(static_cast<int32_t>(software_bitmap.PixelHeight()));
  result[EncodableValue("blocks")] = EncodableValue(blocks);
  return result;
}

EncodableMap RecognizePdfPage(const EncodableMap& args) {
  const std::string* path = ReadString(args, "path");
  if (path == nullptr || path->empty()) {
    throw std::runtime_error("missing path");
  }
  const int32_t page_number = ReadInt(args, "pageNumber", 0);
  const int32_t dpi = ReadInt(args, "dpi", 200);
  const int32_t max_edge =
      (std::min)(ReadInt(args, "maxEdge", 2200),
                 static_cast<int32_t>(winrt::Windows::Media::Ocr::OcrEngine::
                                          MaxImageDimension()));
  const std::string* language_hint_ptr = ReadString(args, "languageHint");
  const std::string language_hint =
      language_hint_ptr == nullptr || language_hint_ptr->empty()
          ? "zh-Hans"
          : *language_hint_ptr;
  if (page_number < 1) {
    throw std::runtime_error("page_out_of_range");
  }

  auto cached = GetOrOpenPdf(*path);
  uint32_t out_width = 0;
  uint32_t out_height = 0;
  auto software_bitmap = RenderPageBitmap(cached, page_number, dpi, max_edge,
                                          5000000, &out_width, &out_height);
  (void)out_width;
  (void)out_height;
  return OcrSoftwareBitmap(software_bitmap, language_hint);
}

EncodableMap RecognizeImage(const EncodableMap& args) {
  const auto* image_bytes = ReadBytes(args, "imageBytes");
  if (image_bytes == nullptr || image_bytes->empty()) {
    throw std::runtime_error("missing imageBytes");
  }
  const std::string* language_hint_ptr = ReadString(args, "languageHint");
  const std::string language_hint =
      language_hint_ptr == nullptr || language_hint_ptr->empty()
          ? "zh-Hans"
          : *language_hint_ptr;

  auto stream = winrt::Windows::Storage::Streams::InMemoryRandomAccessStream();
  auto writer = winrt::Windows::Storage::Streams::DataWriter(stream);
  writer.WriteBytes(*image_bytes);
  writer.StoreAsync().get();
  writer.FlushAsync().get();
  stream.Seek(0);

  auto decoder =
      winrt::Windows::Graphics::Imaging::BitmapDecoder::CreateAsync(stream)
          .get();
  uint32_t width = 0;
  uint32_t height = 0;
  pagesage::ComputeOutputSize(
      decoder.PixelWidth(), decoder.PixelHeight(), 72,
      static_cast<int32_t>(
          winrt::Windows::Media::Ocr::OcrEngine::MaxImageDimension()),
      5000000, &width, &height);
  winrt::Windows::Graphics::Imaging::BitmapTransform transform;
  transform.ScaledWidth(width);
  transform.ScaledHeight(height);
  auto software_bitmap =
      decoder
          .GetSoftwareBitmapAsync(
              winrt::Windows::Graphics::Imaging::BitmapPixelFormat::Bgra8,
              winrt::Windows::Graphics::Imaging::BitmapAlphaMode::Premultiplied,
              transform,
              winrt::Windows::Graphics::Imaging::ExifOrientationMode::
                  IgnoreExifOrientation,
              winrt::Windows::Graphics::Imaging::ColorManagementMode::
                  DoNotColorManage)
          .get();
  return OcrSoftwareBitmap(software_bitmap, language_hint);
}

void ReplySuccess(std::shared_ptr<flutter::MethodResult<EncodableValue>> result,
                  EncodableValue value) {
  result->Success(std::move(value));
}

void ReplyError(std::shared_ptr<flutter::MethodResult<EncodableValue>> result,
                const std::string& code, const std::string& message) {
  result->Error(code, message);
}

void HandleRasterCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (call.method_name() != "renderPage") {
    result->NotImplemented();
    return;
  }
  const auto* args_ptr = call.arguments() == nullptr
                             ? nullptr
                             : std::get_if<EncodableMap>(call.arguments());
  if (args_ptr == nullptr) {
    result->Error("render_failed", "missing arguments");
    return;
  }
  // Copy args so the worker thread owns them.
  const EncodableMap args = *args_ptr;
  auto shared =
      std::shared_ptr<flutter::MethodResult<EncodableValue>>(std::move(result));

  std::thread([args, shared]() {
    try {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {
    }
    try {
      const EncodableMap payload = RenderPdfPage(args);
      ReplySuccess(shared, EncodableValue(payload));
    } catch (const std::exception& error) {
      const std::string message = error.what();
      if (message == "page_out_of_range") {
        ReplyError(shared, "page_out_of_range", "page out of range");
      } else if (message.find("path") != std::string::npos ||
                 message.find("file") != std::string::npos) {
        ReplyError(shared, "file_not_found", message);
      } else {
        ReplyError(shared, "render_failed", message);
      }
    } catch (...) {
      ReplyError(shared, "render_failed", "unknown render error");
    }
  }).detach();
}

void HandleOcrCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  auto shared =
      std::shared_ptr<flutter::MethodResult<EncodableValue>>(std::move(result));
  const std::string method = call.method_name();
  EncodableMap args;
  if (const auto* args_ptr =
          call.arguments() == nullptr
              ? nullptr
              : std::get_if<EncodableMap>(call.arguments())) {
    args = *args_ptr;
  }

  if (method == "isAvailable" || method == "supportedLanguages") {
    std::thread([shared, method]() {
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
      } catch (...) {
      }
      try {
        const auto installed = winrt::Windows::Media::Ocr::OcrEngine::
            AvailableRecognizerLanguages();
        if (method == "isAvailable") {
          ReplySuccess(shared, EncodableValue(installed.Size() > 0));
        } else {
          EncodableList languages;
          for (const auto& language : installed) {
            languages.emplace_back(winrt::to_string(language.LanguageTag()));
          }
          ReplySuccess(shared, EncodableValue(languages));
        }
      } catch (...) {
        ReplySuccess(shared, method == "isAvailable"
                                 ? EncodableValue(false)
                                 : EncodableValue(EncodableList{}));
      }
    }).detach();
    return;
  }

  if (method == "recognizePdfPage") {
    if (call.arguments() == nullptr ||
        !std::holds_alternative<EncodableMap>(*call.arguments())) {
      ReplyError(shared, "ocr_failed", "missing arguments");
      return;
    }
    std::thread([args, shared]() {
      try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
      } catch (...) {
      }
      try {
        const EncodableMap payload = RecognizePdfPage(args);
        ReplySuccess(shared, EncodableValue(payload));
      } catch (const std::exception& error) {
        const std::string message = error.what();
        if (message == "ocr_language_unavailable") {
          ReplyError(shared, "ocr_language_unavailable",
                     "Install the requested OCR language in Windows Settings");
        } else if (message == "ocr_unavailable") {
          ReplyError(shared, "ocr_unavailable",
                     "Windows OCR engine unavailable");
        } else if (message == "page_out_of_range") {
          ReplyError(shared, "page_out_of_range", "page out of range");
        } else if (message.find("file") != std::string::npos ||
                   message.find("path") != std::string::npos) {
          ReplyError(shared, "file_not_found", message);
        } else {
          ReplyError(shared, "ocr_failed", message);
        }
      } catch (...) {
        ReplyError(shared, "ocr_failed", "unknown ocr error");
      }
    }).detach();
    return;
  }

  if (method != "recognize") {
    // unique_ptr already moved into shared; use shared for NotImplemented.
    shared->NotImplemented();
    return;
  }

  std::thread([args, shared]() {
    try {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {
    }
    try {
      if (args.empty()) {
        ReplyError(shared, "ocr_failed", "missing arguments");
        return;
      }
      const EncodableMap payload = RecognizeImage(args);
      ReplySuccess(shared, EncodableValue(payload));
    } catch (const std::exception& error) {
      const std::string message = error.what();
      if (message == "ocr_language_unavailable") {
        ReplyError(shared, "ocr_language_unavailable",
                   "Install the requested OCR language in Windows Settings");
      } else if (message == "ocr_unavailable") {
        ReplyError(shared, "ocr_unavailable", "Windows OCR engine unavailable");
      } else {
        ReplyError(shared, "ocr_failed", message);
      }
    } catch (...) {
      ReplyError(shared, "ocr_failed", "unknown ocr error");
    }
  }).detach();
}

}  // namespace

void RegisterPagesageNativeChannels(flutter::BinaryMessenger* messenger) {
  auto raster_channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "pagesage/pdf_raster",
          &flutter::StandardMethodCodec::GetInstance());
  raster_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleRasterCall(call, std::move(result));
      });
  // Keep channel alive for process lifetime.
  static auto s_raster = std::move(raster_channel);

  auto ocr_channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "pagesage/ocr", &flutter::StandardMethodCodec::GetInstance());
  ocr_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        HandleOcrCall(call, std::move(result));
      });
  static auto s_ocr = std::move(ocr_channel);
}
