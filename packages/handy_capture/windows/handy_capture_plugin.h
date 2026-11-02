#ifndef FLUTTER_PLUGIN_HANDY_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_HANDY_CAPTURE_PLUGIN_H_

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <windows.h>

#include <cstdint>
#include <deque>
#include <memory>
#include <string>
#include <vector>

namespace handy_capture {

// One screenshot kept in memory for this session only. Nothing is written
// to disk; "clear" and closing the app drop it.
struct Shot {
  std::string uri;
  std::vector<uint8_t> png;
  int width = 0;
  int height = 0;
};

// The desktop as it was when captured: a 32-bit top-down bitmap of the
// rectangle |left|, |top|, |width| x |height| in physical pixels.
struct Frozen {
  HBITMAP bitmap = nullptr;
  HDC dc = nullptr;
  HGDIOBJ old = nullptr;
  uint8_t* bits = nullptr;
  int left = 0, top = 0, width = 0, height = 0;
  ~Frozen();
};

// Windows screenshots: the whole screen under the pointer, or an area
// dragged out on a frozen, dimmed copy of every screen. GDI BitBlt with
// CAPTUREBLT in physical pixels (the runner is per-monitor DPI aware v2),
// PNG through WIC. Screen recording is not offered on Windows.
class HandyCapturePlugin : public flutter::Plugin {
 public:
  using Result = flutter::MethodResult<flutter::EncodableValue>;

  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit HandyCapturePlugin(HWND view);
  virtual ~HandyCapturePlugin();
  HandyCapturePlugin(const HandyCapturePlugin&) = delete;
  HandyCapturePlugin& operator=(const HandyCapturePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<Result> result);

 private:
  static void CALLBACK OnTimer(HWND, UINT, UINT_PTR, DWORD);
  static LRESULT CALLBACK OverlayProc(HWND, UINT, WPARAM, LPARAM);

  void Capture();
  void ShowOverlay();
  LRESULT OnOverlay(HWND hwnd, UINT message, WPARAM w, LPARAM l);
  void PaintOverlay(HWND hwnd);
  RECT Selection() const;
  void Finish(const RECT* area);
  void Fail(const std::string& code, const std::string& message);
  void Restore();
  flutter::EncodableValue Describe(const Shot& shot) const;

  void CloseOverlay();
  HWND Window() const;

  HWND view_ = nullptr;  // The Flutter view; its root is the app window.
  HWND hidden_ = nullptr;  // The app window while it steps aside.
  std::unique_ptr<Result> pending_;
  UINT_PTR timer_ = 0;
  bool region_ = false;
  std::wstring hint_;
  std::unique_ptr<Frozen> frozen_;
  HWND overlay_ = nullptr;
  RECT hint_monitor_{};
  RECT hint_rect_{};
  HFONT font_ = nullptr;
  HDC shade_dc_ = nullptr;
  HBITMAP shade_bitmap_ = nullptr;
  HGDIOBJ shade_old_ = nullptr;
  POINT anchor_{}, point_{};
  bool dragging_ = false;
  std::deque<Shot> shots_;
  int counter_ = 0;
  std::string error_;
};

}  // namespace handy_capture

#endif  // FLUTTER_PLUGIN_HANDY_CAPTURE_PLUGIN_H_
