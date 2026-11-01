#ifndef FLUTTER_PLUGIN_HANDY_STORE_PLUGIN_H_
#define FLUTTER_PLUGIN_HANDY_STORE_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <windows.h>

namespace handy_store {

class HandyStorePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  HandyStorePlugin();

  virtual ~HandyStorePlugin();

  // Disallow copy and assign.
  HandyStorePlugin(const HandyStorePlugin&) = delete;
  HandyStorePlugin& operator=(const HandyStorePlugin&) = delete;
  HWND window_ = nullptr;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace handy_store

#endif  // FLUTTER_PLUGIN_HANDY_STORE_PLUGIN_H_
