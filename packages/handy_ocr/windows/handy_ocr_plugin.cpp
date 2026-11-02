#include "handy_ocr_plugin.h"

#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <cstdint>
#include <string>
#include <vector>

namespace handy_ocr {
using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Result = flutter::MethodResult<EncodableValue>;

namespace {

const EncodableValue* Field(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  return it == map.end() ? nullptr : &it->second;
}

EncodableValue Box(winrt::Windows::Foundation::Rect const& r) {
  return EncodableValue(EncodableMap{
      {EncodableValue("x"), EncodableValue(static_cast<double>(r.X))},
      {EncodableValue("y"), EncodableValue(static_cast<double>(r.Y))},
      {EncodableValue("w"), EncodableValue(static_cast<double>(r.Width))},
      {EncodableValue("h"), EncodableValue(static_cast<double>(r.Height))},
  });
}

EncodableValue Languages() {
  using namespace winrt::Windows::Media::Ocr;
  EncodableList tags;
  for (auto const& language : OcrEngine::AvailableRecognizerLanguages()) {
    tags.push_back(EncodableValue(winrt::to_string(language.LanguageTag())));
  }
  return EncodableValue(EncodableMap{
      {EncodableValue("languages"), EncodableValue(tags)},
      {EncodableValue("maxEdge"),
       EncodableValue(static_cast<int32_t>(OcrEngine::MaxImageDimension()))},
  });
}

// Runs on the platform thread; each co_await resumes there, so the reply is
// always sent from the thread that received the call.
winrt::fire_and_forget Recognize(std::vector<uint8_t> pixels,
                                 int32_t width,
                                 int32_t height,
                                 std::string language,
                                 std::shared_ptr<Result> reply) {
  using namespace winrt;
  using namespace Windows::Globalization;
  using namespace Windows::Graphics::Imaging;
  using namespace Windows::Media::Ocr;
  using namespace Windows::Storage::Streams;
  try {
    OcrEngine engine{nullptr};
    if (language.empty()) {
      engine = OcrEngine::TryCreateFromUserProfileLanguages();
    } else {
      Language wanted{to_hstring(language)};
      if (!OcrEngine::IsLanguageSupported(wanted)) {
        reply->Error("language_missing",
                     "This OCR language is not installed: " + language);
        co_return;
      }
      engine = OcrEngine::TryCreateFromLanguage(wanted);
    }
    if (!engine) {
      reply->Error("language_missing", "No OCR language is installed");
      co_return;
    }
    DataWriter writer;
    writer.WriteBytes(array_view<uint8_t const>(pixels));
    auto bitmap = SoftwareBitmap::CreateCopyFromBuffer(
        writer.DetachBuffer(), BitmapPixelFormat::Bgra8, width, height,
        BitmapAlphaMode::Premultiplied);
    auto result = co_await engine.RecognizeAsync(bitmap);
    EncodableList lines;
    for (auto const& line : result.Lines()) {
      EncodableList words;
      for (auto const& word : line.Words()) {
        words.push_back(EncodableValue(EncodableMap{
            {EncodableValue("text"),
             EncodableValue(to_string(word.Text()))},
            {EncodableValue("box"), Box(word.BoundingRect())},
        }));
      }
      lines.push_back(EncodableValue(EncodableMap{
          {EncodableValue("text"), EncodableValue(to_string(line.Text()))},
          {EncodableValue("words"), EncodableValue(words)},
      }));
    }
    EncodableMap out{
        {EncodableValue("language"),
         EncodableValue(to_string(engine.RecognizerLanguage().LanguageTag()))},
        {EncodableValue("lines"), EncodableValue(lines)},
    };
    if (auto angle = result.TextAngle()) {
      out[EncodableValue("angle")] = EncodableValue(angle.Value());
    }
    reply->Success(EncodableValue(out));
  } catch (hresult_error const& e) {
    reply->Error("failed", to_string(e.message()));
  } catch (...) {
    reply->Error("failed", "Text recognition failed");
  }
}

}  // namespace

void HandyOcrPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "handy_ocr",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<HandyOcrPlugin>();
  channel->SetMethodCallHandler(
      [pointer = plugin.get()](const auto& call, auto result) {
        pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

HandyOcrPlugin::HandyOcrPlugin() = default;
HandyOcrPlugin::~HandyOcrPlugin() = default;

void HandyOcrPlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<Result> result) {
  const auto& method = call.method_name();
  if (method == "languages") {
    try {
      result->Success(Languages());
    } catch (winrt::hresult_error const& e) {
      result->Error("failed", winrt::to_string(e.message()));
    }
    return;
  }
  {
    if (method != "recognize") {
      result->NotImplemented();
      return;
    }
    const auto* arguments = std::get_if<EncodableMap>(call.arguments());
    if (!arguments) {
      result->Error("bad_input", "Missing arguments");
      return;
    }
    const auto* bytes = Field(*arguments, "bgra");
    const auto* width = Field(*arguments, "width");
    const auto* height = Field(*arguments, "height");
    const auto* language = Field(*arguments, "language");
    const auto* pixels =
        bytes ? std::get_if<std::vector<uint8_t>>(bytes) : nullptr;
    const auto* w = width ? std::get_if<int32_t>(width) : nullptr;
    const auto* h = height ? std::get_if<int32_t>(height) : nullptr;
    if (!pixels || !w || !h || *w < 1 || *h < 1 || *w > 10000 || *h > 10000 ||
        pixels->size() != static_cast<size_t>(*w) * *h * 4) {
      result->Error("bad_input", "Pixels do not match the image size");
      return;
    }
    std::string tag;
    if (language) {
      if (const auto* value = std::get_if<std::string>(language)) tag = *value;
    }
    Recognize(*pixels, *w, *h, tag, std::shared_ptr<Result>(std::move(result)));
  }
}

}  // namespace handy_ocr
