#include "include/handy_store/handy_store_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "handy_store_plugin.h"

void HandyStorePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  handy_store::HandyStorePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
