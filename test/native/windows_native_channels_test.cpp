// Exercise the production handlers and WinRT worker threads without a window.
// Only the MethodResult sink is replaced; PDF raster and OCR are real OS calls.
#include "../../windows/runner/pagesage_native_channels.cpp"

#include <chrono>
#include <filesystem>
#include <future>
#include <iostream>
#include <stdexcept>

namespace {
struct Response {
  EncodableValue value;
  std::string error;
  bool implemented = true;
};

class Result final : public flutter::MethodResult<EncodableValue> {
 public:
  std::promise<Response> completion;

 protected:
  void SuccessInternal(const EncodableValue* value) override {
    completion.set_value({value ? *value : EncodableValue(), "", true});
  }
  void ErrorInternal(const std::string& code, const std::string&,
                     const EncodableValue*) override {
    completion.set_value({EncodableValue(), code, true});
  }
  void NotImplementedInternal() override {
    completion.set_value({EncodableValue(), "", false});
  }
};

void Check(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

Response Call(bool raster, const std::string& method,
              const EncodableValue* arguments = nullptr) {
  auto result = std::make_unique<Result>();
  auto future = result->completion.get_future();
  flutter::MethodCall<EncodableValue> call(
      method, arguments ? std::make_unique<EncodableValue>(*arguments) : nullptr);
  if (raster) {
    HandleRasterCall(call, std::move(result));
  } else {
    HandleOcrCall(call, std::move(result));
  }
  Check(future.wait_for(std::chrono::seconds(30)) == std::future_status::ready,
        "native handler did not complete");
  return future.get();
}

const EncodableMap& Payload(const Response& response) {
  Check(response.implemented && response.error.empty(), "native call failed");
  return std::get<EncodableMap>(response.value);
}

EncodableValue Arguments(const std::filesystem::path& pdf, int page = 1) {
  return EncodableValue(EncodableMap{
      {EncodableValue("path"), EncodableValue(pdf.u8string())},
      {EncodableValue("pageNumber"), EncodableValue(page)},
      {EncodableValue("maxEdge"), EncodableValue(480)},
      {EncodableValue("maxPixels"), EncodableValue(120000)}});
}

void TestErrors(const std::filesystem::path& pdf) {
  Check(Call(true, "renderPage").error == "render_failed", "null raster args");
  Check(Call(false, "recognizePdfPage").error == "ocr_failed", "null OCR args");
  Check(!Call(true, "unknown").implemented, "unknown raster method");
  Check(!Call(false, "unknown").implemented, "unknown OCR method");
  auto missing = Arguments(pdf.parent_path() / "does-not-exist.pdf");
  Check(Call(true, "renderPage", &missing).error == "file_not_found",
        "missing PDF error mapping");
  auto invalid = Arguments(pdf, 99999);
  Check(Call(true, "renderPage", &invalid).error == "page_out_of_range",
        "out-of-range PDF error mapping");
}

std::vector<uint8_t> TestRaster(const std::filesystem::path& pdf) {
  auto args = Arguments(pdf);
  const auto response = Call(true, "renderPage", &args);
  const auto& map = Payload(response);
  const int width = ReadInt(map, "width", 0);
  const int height = ReadInt(map, "height", 0);
  Check(width > 0 && height > 0 && width <= 480 && height <= 480,
        "PDF edge budget");
  Check(width * height <= 120000, "PDF pixel budget");
  const auto* bytes = ReadBytes(map, "bytes");
  Check(bytes != nullptr && bytes->size() > 100, "PDF image bytes");
  Check((*bytes)[0] == 0xff && (*bytes)[1] == 0xd8, "JPEG image signature");
  const auto repeated = Call(true, "renderPage", &args);
  Check(ReadInt(Payload(repeated), "width", 0) == width, "cached PDF session");
  return *bytes;
}

void CheckOcr(const Response& response) {
  const auto& map = Payload(response);
  const auto* text = ReadString(map, "text");
  Check(text && !text->empty(), "OCR should read the real PDF sample");
  Check(*ReadString(map, "engine") == "winrt", "WinRT engine identity");
  const auto& blocks = std::get<EncodableList>(map.at(EncodableValue("blocks")));
  Check(!blocks.empty(), "OCR line geometry");
  for (const auto& block : blocks) {
    const auto& box = std::get<EncodableMap>(block);
    const double left = std::get<double>(box.at(EncodableValue("left")));
    const double top = std::get<double>(box.at(EncodableValue("top")));
    const double width = std::get<double>(box.at(EncodableValue("width")));
    const double height = std::get<double>(box.at(EncodableValue("height")));
    Check(left >= 0 && top >= 0 && width > 0 && height > 0 &&
              left + width <= 1.001 && top + height <= 1.001,
          "OCR coordinates must be normalized");
  }
}

void TestOcr(const std::filesystem::path& pdf) {
  const auto reported = Call(false, "supportedLanguages");
  Check(reported.error.empty(), "language capability call");
  const auto& languages = std::get<EncodableList>(reported.value);
  const auto available = Call(false, "isAvailable");
  Check(std::get<bool>(available.value) == !languages.empty(), "OCR availability");
  // No language pack is a legitimate platform capability, never a fake pass.
  Check(!languages.empty(), "Install an OCR language pack to run OCR acceptance");
  std::string language = std::get<std::string>(languages.front());
  for (const auto& value : languages) {
    const auto& tag = std::get<std::string>(value);
    std::cout << "Installed OCR language: " << tag << std::endl;
    if (tag.rfind("en", 0) == 0) language = tag;
  }
  auto args = std::get<EncodableMap>(Arguments(pdf));
  args[EncodableValue("languageHint")] = EncodableValue(language);
  args[EncodableValue("maxEdge")] = EncodableValue(1600);
  auto page = EncodableValue(args);
  CheckOcr(Call(false, "recognizePdfPage", &page));
  auto image = EncodableValue(EncodableMap{
      {EncodableValue("imageBytes"), EncodableValue(TestRaster(pdf))},
      {EncodableValue("languageHint"), EncodableValue(language)}});
  CheckOcr(Call(false, "recognize", &image));
  // Exercise a valid but missing language, without installing anything.
  for (const auto* tag : {"ja-JP", "ko-KR", "fr-FR", "zu-ZA"}) {
    if (!winrt::Windows::Media::Ocr::OcrEngine::IsLanguageSupported(
            winrt::Windows::Globalization::Language(winrt::to_hstring(tag)))) {
      args[EncodableValue("languageHint")] = EncodableValue(std::string(tag));
      auto absent = EncodableValue(args);
      Check(Call(false, "recognizePdfPage", &absent).error ==
                "ocr_language_unavailable", "missing language error mapping");
      return;
    }
  }
  throw std::runtime_error("No missing language found for negative test");
}
}  // namespace

int main(int argc, char** argv) {
  try {
    Check(argc == 3, "Usage: windows_native_channels_test errors|raster|ocr sample.pdf");
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    const auto directory = std::filesystem::temp_directory_path() /
        std::filesystem::u8path("PageSage 原生测试 " + std::to_string(GetCurrentProcessId()));
    std::filesystem::create_directories(directory);
    const auto pdf = directory / std::filesystem::u8path("中文 空格.pdf");
    std::filesystem::copy_file(std::filesystem::u8path(argv[2]), pdf,
                              std::filesystem::copy_options::overwrite_existing);
    try {
      const std::string scenario(argv[1]);
      if (scenario == "errors") TestErrors(pdf);
      else if (scenario == "raster") TestRaster(pdf);
      else if (scenario == "ocr") TestOcr(pdf);
      else throw std::runtime_error("Unknown scenario");
    } catch (...) {
      g_pdf_cache.clear();
      std::filesystem::remove_all(directory);
      throw;
    }
    g_pdf_cache.clear();
    std::filesystem::remove_all(directory);
    std::cout << argv[1] << " PASS" << std::endl;
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
  } catch (const winrt::hresult_error& error) {
    std::cerr << "WinRT failure: " << winrt::to_string(error.message()) << '\n';
  }
  return 1;
}
