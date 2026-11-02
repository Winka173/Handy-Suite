#include "include/handy_capture/handy_capture_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "handy_capture_plugin.h"

void HandyCapturePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  handy_capture::HandyCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
