#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>

#include <memory>

#include "win32_window.h"
#include "share_drop_target.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  ShareDropTarget* drop_target_ = nullptr;
  bool child_drop_registered_ = false;
  bool parent_drop_registered_ = false;
  HWND drop_child_window_ = nullptr;
  HWND drop_parent_window_ = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> shares_;

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
