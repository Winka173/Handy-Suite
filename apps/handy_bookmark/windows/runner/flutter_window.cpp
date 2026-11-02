#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  shares_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "handy.save/share",
      &flutter::StandardMethodCodec::GetInstance());
  shares_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "drain") {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
    } else if (call.method_name() == "ack") {
      result->Success(flutter::EncodableValue(false));
    } else if (call.method_name() == "dropAvailable") {
      result->Success(flutter::EncodableValue(child_drop_registered_ || parent_drop_registered_));
    } else {
      result->NotImplemented();
    }
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  drop_target_ = new ShareDropTarget(
      [this](const std::string& text) {
        if (shares_) shares_->InvokeMethod("incomingText", std::make_unique<flutter::EncodableValue>(text));
      },
      [this]() {
        if (shares_) shares_->InvokeMethod("shareError", std::make_unique<flutter::EncodableValue>("DROP_INPUT_ERROR"));
      });
  drop_child_window_ = flutter_controller_->view()->GetNativeWindow();
  drop_parent_window_ = GetHandle();
  child_drop_registered_ = SUCCEEDED(RegisterDragDrop(drop_child_window_, drop_target_));
  parent_drop_registered_ = SUCCEEDED(RegisterDragDrop(drop_parent_window_, drop_target_));

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (child_drop_registered_) {
    RevokeDragDrop(drop_child_window_);
    child_drop_registered_ = false;
  }
  if (parent_drop_registered_) { RevokeDragDrop(drop_parent_window_); parent_drop_registered_ = false; }
  drop_child_window_ = nullptr;
  drop_parent_window_ = nullptr;
  if (drop_target_) { drop_target_->Release(); drop_target_ = nullptr; }
  shares_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
