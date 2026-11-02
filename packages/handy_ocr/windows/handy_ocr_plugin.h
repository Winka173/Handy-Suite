#ifndef FLUTTER_PLUGIN_HANDY_SCAN_PLUGIN_H_
#define FLUTTER_PLUGIN_HANDY_SCAN_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace handy_ocr {

// On-device text recognition through Windows.Media.Ocr. Pixels arrive from
// Dart, are read in memory and never written to disk or sent anywhere.
class HandyOcrPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  HandyOcrPlugin();
  virtual ~HandyOcrPlugin();

  HandyOcrPlugin(const HandyOcrPlugin&) = delete;
  HandyOcrPlugin& operator=(const HandyOcrPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace handy_ocr

#endif  // FLUTTER_PLUGIN_HANDY_SCAN_PLUGIN_H_
