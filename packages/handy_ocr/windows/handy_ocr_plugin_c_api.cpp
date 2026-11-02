#include "include/handy_ocr/handy_ocr_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "handy_ocr_plugin.h"

void HandyOcrPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  handy_ocr::HandyOcrPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
