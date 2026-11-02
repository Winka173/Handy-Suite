#include "handy_capture_plugin.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <wincodec.h>
#include <windowsx.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstring>

namespace handy_capture {

using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

namespace {

// Matches CaptureResult.parse and NativeCapture.read on the Dart side.
constexpr int kMaxEdge = 16384;
constexpr long long kMaxPixels = 16000000;
constexpr size_t kMaxPng = 8000000;
// The frozen desktop may span several screens.
constexpr long long kMaxFrozenPixels = 40000000;
constexpr size_t kKeptShots = 4;
// Time for the app window to leave the screen before the capture.
constexpr UINT kMinDelayMs = 400;
// Media's hue, #C2255C, for the selection's edge.
constexpr COLORREF kHue = RGB(194, 37, 92);
constexpr COLORREF kInk = RGB(29, 31, 32);
constexpr wchar_t kOverlayClass[] = L"HandyCaptureOverlay";

HandyCapturePlugin* g_plugin = nullptr;

const EncodableValue* Arg(const EncodableMap* args, const char* name) {
  if (!args) return nullptr;
  auto it = args->find(EncodableValue(name));
  return it == args->end() ? nullptr : &it->second;
}

std::wstring Wide(const std::string& text) {
  if (text.empty()) return L"";
  int n = MultiByteToWideChar(CP_UTF8, 0, text.data(),
                              static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(n, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      out.data(), n);
  return out;
}

// Encodes |width| x |height| rows of BGR as PNG with WIC, in memory.
bool EncodePng(const std::vector<uint8_t>& bgr, int width, int height,
               std::vector<uint8_t>* out) {
  ComPtr<IWICImagingFactory> factory;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(&factory)))) {
    return false;
  }
  ComPtr<IStream> stream;
  if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream))) return false;
  ComPtr<IWICBitmapEncoder> encoder;
  if (FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr,
                                    &encoder)) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache))) {
    return false;
  }
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IPropertyBag2> options;
  if (FAILED(encoder->CreateNewFrame(&frame, &options)) ||
      FAILED(frame->Initialize(options.Get())) ||
      FAILED(frame->SetSize(width, height))) {
    return false;
  }
  WICPixelFormatGUID format = GUID_WICPixelFormat24bppBGR;
  if (FAILED(frame->SetPixelFormat(&format)) ||
      !IsEqualGUID(format, GUID_WICPixelFormat24bppBGR)) {
    return false;
  }
  const UINT stride = static_cast<UINT>(width) * 3;
  if (FAILED(frame->WritePixels(height, stride,
                                static_cast<UINT>(bgr.size()),
                                const_cast<BYTE*>(bgr.data()))) ||
      FAILED(frame->Commit()) || FAILED(encoder->Commit())) {
    return false;
  }
  ULARGE_INTEGER size{};
  LARGE_INTEGER zero{};
  if (FAILED(stream->Seek(zero, STREAM_SEEK_CUR, &size))) return false;
  HGLOBAL memory = nullptr;
  if (FAILED(GetHGlobalFromStream(stream.Get(), &memory))) return false;
  const void* data = GlobalLock(memory);
  if (!data) return false;
  out->assign(static_cast<const uint8_t*>(data),
              static_cast<const uint8_t*>(data) + size.QuadPart);
  GlobalUnlock(memory);
  return true;
}

}  // namespace

Frozen::~Frozen() {
  if (dc) {
    if (old) SelectObject(dc, old);
    DeleteDC(dc);
  }
  if (bitmap) DeleteObject(bitmap);
}

void HandyCapturePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      registrar->messenger(), "handy_capture",
      &flutter::StandardMethodCodec::GetInstance());
  HWND view = registrar->GetView() ? registrar->GetView()->GetNativeWindow()
                                   : nullptr;
  auto plugin = std::make_unique<HandyCapturePlugin>(view);
  channel->SetMethodCallHandler(
      [pointer = plugin.get()](const auto& call, auto result) {
        pointer->HandleMethodCall(call, std::move(result));
      });
  registrar->AddPlugin(std::move(plugin));
}

HandyCapturePlugin::HandyCapturePlugin(HWND view) : view_(view) {
  g_plugin = this;
}

HandyCapturePlugin::~HandyCapturePlugin() {
  if (timer_) KillTimer(nullptr, timer_);
  CloseOverlay();
  if (hidden_) ShowWindow(hidden_, SW_SHOW);
  if (g_plugin == this) g_plugin = nullptr;
}

// The view is parented to the app window after plugins register, so the
// window is looked up when it is needed.
HWND HandyCapturePlugin::Window() const {
  return view_ ? GetAncestor(view_, GA_ROOT) : nullptr;
}

EncodableValue HandyCapturePlugin::Describe(const Shot& shot) const {
  return EncodableValue(EncodableMap{
      {EncodableValue("uri"), EncodableValue(shot.uri)},
      {EncodableValue("mime"), EncodableValue("image/png")},
      {EncodableValue("width"), EncodableValue(shot.width)},
      {EncodableValue("height"), EncodableValue(shot.height)},
  });
}

void HandyCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<Result> result) {
  const auto& method = call.method_name();
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  if (method == "status") {
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("recording"), EncodableValue(false)},
        {EncodableValue("pending"), EncodableValue(pending_ != nullptr)},
        {EncodableValue("lastResult"),
         shots_.empty() ? EncodableValue() : Describe(shots_.back())},
        {EncodableValue("error"),
         error_.empty() ? EncodableValue() : EncodableValue(error_)},
    }));
    return;
  }
  if (method == "screenshot") {
    if (pending_) {
      result->Error("E_BUSY", "A capture is already running");
      return;
    }
    HWND window = Window();
    const auto* delay = Arg(args, "delayMs");
    const auto* area = Arg(args, "area");
    const auto* hint = Arg(args, "hint");
    const int* ms = delay ? std::get_if<int>(delay) : nullptr;
    const std::string* where = area ? std::get_if<std::string>(area) : nullptr;
    if (!window || !ms || *ms < 0 || *ms > 10000 ||
        (where && *where != "screen" && *where != "region")) {
      result->Error("E_ARGUMENT", "Invalid screenshot request");
      return;
    }
    region_ = where && *where == "region";
    const std::string* words = hint ? std::get_if<std::string>(hint) : nullptr;
    hint_ = words && words->size() <= 400 ? Wide(*words) : L"";
    error_.clear();
    pending_ = std::move(result);
    // Step out of the way, then capture once the window has left the screen.
    hidden_ = window;
    // No fade-out: the window must be gone, not fading, when the screen
    // is read.
    BOOL instant = TRUE;
    DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED, &instant,
                          sizeof(instant));
    ShowWindow(window, SW_HIDE);
    timer_ = SetTimer(nullptr, 0,
                      std::max<UINT>(kMinDelayMs, static_cast<UINT>(*ms)),
                      OnTimer);
    if (!timer_) Fail("E_CAPTURE", "Could not start the capture");
    return;
  }
  if (method == "read") {
    const auto* uri = Arg(args, "uri");
    const std::string* text = uri ? std::get_if<std::string>(uri) : nullptr;
    for (const auto& shot : shots_) {
      if (text && shot.uri == *text) {
        result->Success(EncodableValue(shot.png));
        return;
      }
    }
    result->Error("E_NOT_FOUND", "This capture is no longer kept");
    return;
  }
  if (method == "clear") {
    shots_.clear();
    result->Success();
    return;
  }
  if (method == "cancel") {
    if (pending_) {
      if (timer_) {
        KillTimer(nullptr, timer_);
        timer_ = 0;
      }
      Finish(nullptr);
    }
    result->Success();
    return;
  }
  // Recording, video tools and imports are Android/iOS only.
  result->NotImplemented();
}

void CALLBACK HandyCapturePlugin::OnTimer(HWND, UINT, UINT_PTR id, DWORD) {
  KillTimer(nullptr, id);
  if (!g_plugin || g_plugin->timer_ != id) return;
  g_plugin->timer_ = 0;
  g_plugin->Capture();
}

void HandyCapturePlugin::Capture() {
  POINT cursor{};
  GetCursorPos(&cursor);
  MONITORINFO info{sizeof(info)};
  GetMonitorInfo(MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST), &info);
  hint_monitor_ = info.rcMonitor;
  RECT area = info.rcMonitor;
  if (region_) {
    area.left = GetSystemMetrics(SM_XVIRTUALSCREEN);
    area.top = GetSystemMetrics(SM_YVIRTUALSCREEN);
    area.right = area.left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
    area.bottom = area.top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
  }
  const int width = area.right - area.left, height = area.bottom - area.top;
  if (width < 1 || height < 1 || width > kMaxEdge || height > kMaxEdge ||
      static_cast<long long>(width) * height > kMaxFrozenPixels) {
    Fail("E_TOO_LARGE", "The screens are too large to capture together");
    return;
  }
  auto frozen = std::make_unique<Frozen>();
  frozen->left = area.left;
  frozen->top = area.top;
  frozen->width = width;
  frozen->height = height;
  BITMAPINFO bi{};
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = width;
  bi.bmiHeader.biHeight = -height;  // Top-down rows.
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  bi.bmiHeader.biCompression = BI_RGB;
  DwmFlush();  // Let the compositor drop the hidden window first.
  HDC screen = GetDC(nullptr);
  void* bits = nullptr;
  frozen->dc = CreateCompatibleDC(screen);
  frozen->bitmap =
      CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
  bool ok = frozen->dc && frozen->bitmap && bits;
  if (ok) {
    frozen->bits = static_cast<uint8_t*>(bits);
    frozen->old = SelectObject(frozen->dc, frozen->bitmap);
    ok = BitBlt(frozen->dc, 0, 0, width, height, screen, area.left, area.top,
                SRCCOPY | CAPTUREBLT) != 0;
    GdiFlush();
  }
  ReleaseDC(nullptr, screen);
  if (!ok) {
    Fail("E_CAPTURE", "The screen could not be read");
    return;
  }
  frozen_ = std::move(frozen);
  if (region_) {
    ShowOverlay();
  } else {
    RECT all{0, 0, width, height};
    Finish(&all);
  }
}

void HandyCapturePlugin::ShowOverlay() {
  HINSTANCE instance = GetModuleHandle(nullptr);
  WNDCLASSEXW wc{sizeof(wc)};
  wc.lpfnWndProc = OverlayProc;
  wc.hInstance = instance;
  wc.hCursor = LoadCursor(nullptr, IDC_CROSS);
  wc.lpszClassName = kOverlayClass;
  RegisterClassExW(&wc);  // Already registered on later captures.
  overlay_ = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, kOverlayClass,
                             L"Handy Media", WS_POPUP, frozen_->left,
                             frozen_->top, frozen_->width, frozen_->height,
                             nullptr, nullptr, instance, this);
  if (!overlay_) {
    frozen_.reset();
    Fail("E_CAPTURE", "Could not show the capture overlay");
    return;
  }
  // A 1 x 1 black pixel, stretched at partial opacity to dim the desktop.
  BITMAPINFO bi{};
  bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth = 1;
  bi.bmiHeader.biHeight = 1;
  bi.bmiHeader.biPlanes = 1;
  bi.bmiHeader.biBitCount = 32;
  void* pixel = nullptr;
  shade_dc_ = CreateCompatibleDC(nullptr);
  shade_bitmap_ =
      CreateDIBSection(nullptr, &bi, DIB_RGB_COLORS, &pixel, nullptr, 0);
  if (pixel) std::memset(pixel, 0, 4);
  shade_old_ = SelectObject(shade_dc_, shade_bitmap_);
  // The hint sits at the top of the screen the pointer is on.
  const UINT dpi = GetDpiForWindow(overlay_);
  font_ = CreateFontW(-MulDiv(15, dpi, 96), 0, 0, 0, FW_MEDIUM, FALSE, FALSE,
                      FALSE, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                      CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                      DEFAULT_PITCH, L"Segoe UI");
  hint_rect_ = RECT{};
  if (!hint_.empty()) {
    HDC dc = GetDC(overlay_);
    HGDIOBJ old = SelectObject(dc, font_);
    RECT text{0, 0, MulDiv(560, dpi, 96), 0};
    DrawTextW(dc, hint_.c_str(), -1, &text,
              DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX);
    SelectObject(dc, old);
    ReleaseDC(overlay_, dc);
    const int pad = MulDiv(14, dpi, 96), gap = MulDiv(24, dpi, 96);
    const int w = text.right + pad * 2, h = text.bottom + pad * 2;
    const int centre =
        (hint_monitor_.left + hint_monitor_.right) / 2 - frozen_->left;
    // Two pixels of slack so rounding never wraps the last word.
    const int left = centre - w / 2, top = hint_monitor_.top - frozen_->top + gap;
    hint_rect_ = RECT{left, top, left + w + 2, top + h};
  }
  dragging_ = false;
  anchor_ = point_ = POINT{};
  ShowWindow(overlay_, SW_SHOW);
  SetForegroundWindow(overlay_);
  SetFocus(overlay_);
}

LRESULT CALLBACK HandyCapturePlugin::OverlayProc(HWND hwnd, UINT message,
                                                 WPARAM w, LPARAM l) {
  if (message == WM_NCCREATE) {
    auto create = reinterpret_cast<CREATESTRUCTW*>(l);
    SetWindowLongPtr(hwnd, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto self = reinterpret_cast<HandyCapturePlugin*>(
      GetWindowLongPtr(hwnd, GWLP_USERDATA));
  if (self && self->overlay_ == hwnd) return self->OnOverlay(hwnd, message, w, l);
  return DefWindowProcW(hwnd, message, w, l);
}

RECT HandyCapturePlugin::Selection() const {
  if (!frozen_) return RECT{};
  RECT r{std::min(anchor_.x, point_.x), std::min(anchor_.y, point_.y),
         std::max(anchor_.x, point_.x) + 1, std::max(anchor_.y, point_.y) + 1};
  r.left = std::clamp<LONG>(r.left, 0, frozen_->width);
  r.right = std::clamp<LONG>(r.right, 0, frozen_->width);
  r.top = std::clamp<LONG>(r.top, 0, frozen_->height);
  r.bottom = std::clamp<LONG>(r.bottom, 0, frozen_->height);
  return r;
}

LRESULT HandyCapturePlugin::OnOverlay(HWND hwnd, UINT message, WPARAM w,
                                      LPARAM l) {
  switch (message) {
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT:
      PaintOverlay(hwnd);
      return 0;
    case WM_LBUTTONDOWN:
      anchor_ = point_ = POINT{GET_X_LPARAM(l), GET_Y_LPARAM(l)};
      dragging_ = true;
      SetCapture(hwnd);
      InvalidateRect(hwnd, nullptr, FALSE);
      return 0;
    case WM_MOUSEMOVE:
      if (dragging_) {
        RECT before = Selection();
        point_ = POINT{GET_X_LPARAM(l), GET_Y_LPARAM(l)};
        RECT after = Selection(), dirty{};
        UnionRect(&dirty, &before, &after);
        InflateRect(&dirty, 4, 4);
        InvalidateRect(hwnd, &dirty, FALSE);
      }
      return 0;
    case WM_LBUTTONUP: {
      if (!dragging_) return 0;
      dragging_ = false;
      ReleaseCapture();
      point_ = POINT{GET_X_LPARAM(l), GET_Y_LPARAM(l)};
      RECT area = Selection();
      if (area.right - area.left < 5 || area.bottom - area.top < 5) {
        // A click without a drag takes the whole screen under it.
        POINT at{point_.x + frozen_->left, point_.y + frozen_->top};
        MONITORINFO info{sizeof(info)};
        GetMonitorInfo(MonitorFromPoint(at, MONITOR_DEFAULTTONEAREST), &info);
        area = RECT{info.rcMonitor.left - frozen_->left,
                    info.rcMonitor.top - frozen_->top,
                    info.rcMonitor.right - frozen_->left,
                    info.rcMonitor.bottom - frozen_->top};
      }
      Finish(&area);
      return 0;
    }
    case WM_RBUTTONUP:
      Finish(nullptr);
      return 0;
    case WM_KEYDOWN:
      if (w == VK_ESCAPE) Finish(nullptr);
      return 0;
    case WM_CLOSE:
      Finish(nullptr);
      return 0;
    case WM_DPICHANGED:
      // The overlay is drawn 1:1 in physical pixels; keep its place.
      return 0;
  }
  return DefWindowProcW(hwnd, message, w, l);
}

void HandyCapturePlugin::PaintOverlay(HWND hwnd) {
  PAINTSTRUCT ps;
  HDC dc = BeginPaint(hwnd, &ps);
  const RECT p = ps.rcPaint;
  const int pw = p.right - p.left, ph = p.bottom - p.top;
  if (frozen_ && pw > 0 && ph > 0) {
    HDC mem = CreateCompatibleDC(dc);
    HBITMAP buffer = CreateCompatibleBitmap(dc, pw, ph);
    HGDIOBJ old = SelectObject(mem, buffer);
    BitBlt(mem, 0, 0, pw, ph, frozen_->dc, p.left, p.top, SRCCOPY);
    BLENDFUNCTION dim{AC_SRC_OVER, 0, 115, 0};
    AlphaBlend(mem, 0, 0, pw, ph, shade_dc_, 0, 0, 1, 1, dim);
    RECT sel = Selection(), shown{};
    const bool any = dragging_ && sel.right - sel.left > 0;
    if (any && IntersectRect(&shown, &sel, &p)) {
      BitBlt(mem, shown.left - p.left, shown.top - p.top,
             shown.right - shown.left, shown.bottom - shown.top, frozen_->dc,
             shown.left, shown.top, SRCCOPY);
    }
    if (any) {
      HBRUSH edge = CreateSolidBrush(kHue);
      for (int i = 1; i <= 2; i++) {
        RECT frame{sel.left - i - p.left, sel.top - i - p.top,
                   sel.right + i - p.left, sel.bottom + i - p.top};
        FrameRect(mem, &frame, edge);
      }
      DeleteObject(edge);
    }
    RECT hint{};
    if (!hint_.empty() && IntersectRect(&hint, &hint_rect_, &p)) {
      RECT box{hint_rect_.left - p.left, hint_rect_.top - p.top,
               hint_rect_.right - p.left, hint_rect_.bottom - p.top};
      HBRUSH ink = CreateSolidBrush(kInk);
      FillRect(mem, &box, ink);
      DeleteObject(ink);
      const int pad = MulDiv(14, GetDpiForWindow(hwnd), 96);
      InflateRect(&box, -pad, -pad);
      HGDIOBJ font = SelectObject(mem, font_);
      SetBkMode(mem, TRANSPARENT);
      SetTextColor(mem, RGB(255, 255, 255));
      DrawTextW(mem, hint_.c_str(), -1, &box,
                DT_CENTER | DT_WORDBREAK | DT_NOPREFIX);
      SelectObject(mem, font);
    }
    BitBlt(dc, p.left, p.top, pw, ph, mem, 0, 0, SRCCOPY);
    SelectObject(mem, old);
    DeleteObject(buffer);
    DeleteDC(mem);
  }
  EndPaint(hwnd, &ps);
}

void HandyCapturePlugin::CloseOverlay() {
  if (overlay_) {
    HWND overlay = overlay_;
    overlay_ = nullptr;
    if (GetCapture() == overlay) ReleaseCapture();
    DestroyWindow(overlay);
  }
  if (shade_dc_) {
    SelectObject(shade_dc_, shade_old_);
    DeleteDC(shade_dc_);
    shade_dc_ = nullptr;
  }
  if (shade_bitmap_) {
    DeleteObject(shade_bitmap_);
    shade_bitmap_ = nullptr;
  }
  if (font_) {
    DeleteObject(font_);
    font_ = nullptr;
  }
}

void HandyCapturePlugin::Finish(const RECT* chosen) {
  CloseOverlay();
  if (!pending_) {
    frozen_.reset();
    Restore();
    return;
  }
  if (!chosen || !frozen_) {
    frozen_.reset();
    Fail("E_CANCELED", "Capture canceled");
    return;
  }
  RECT area{std::clamp<LONG>(chosen->left, 0, frozen_->width),
            std::clamp<LONG>(chosen->top, 0, frozen_->height),
            std::clamp<LONG>(chosen->right, 0, frozen_->width),
            std::clamp<LONG>(chosen->bottom, 0, frozen_->height)};
  const int width = area.right - area.left, height = area.bottom - area.top;
  if (width < 1 || height < 1 || width > kMaxEdge || height > kMaxEdge ||
      static_cast<long long>(width) * height > kMaxPixels) {
    frozen_.reset();
    Fail("E_TOO_LARGE", "Choose an area of up to 16 million pixels");
    return;
  }
  std::vector<uint8_t> bgr(static_cast<size_t>(width) * height * 3);
  for (int y = 0; y < height; y++) {
    const uint8_t* row =
        frozen_->bits +
        (static_cast<size_t>(area.top + y) * frozen_->width + area.left) * 4;
    uint8_t* out = bgr.data() + static_cast<size_t>(y) * width * 3;
    for (int x = 0; x < width; x++) {
      out[x * 3] = row[x * 4];
      out[x * 3 + 1] = row[x * 4 + 1];
      out[x * 3 + 2] = row[x * 4 + 2];
    }
  }
  frozen_.reset();
  Shot shot;
  if (!EncodePng(bgr, width, height, &shot.png)) {
    Fail("E_CAPTURE", "The screenshot could not be encoded");
    return;
  }
  if (shot.png.size() > kMaxPng) {
    Fail("E_TOO_LARGE", "The screenshot is over 8 MB; choose a smaller area");
    return;
  }
  shot.width = width;
  shot.height = height;
  shot.uri = "file:///handy-capture/windows/shot-" +
             std::to_string(GetTickCount64()) + "-" +
             std::to_string(++counter_) + ".png";
  shots_.push_back(std::move(shot));
  while (shots_.size() > kKeptShots) shots_.pop_front();
  Restore();
  auto reply = std::move(pending_);
  reply->Success(Describe(shots_.back()));
}

void HandyCapturePlugin::Fail(const std::string& code,
                              const std::string& message) {
  CloseOverlay();
  frozen_.reset();
  Restore();
  error_ = code == "E_CANCELED" ? "" : message;
  if (pending_) {
    auto reply = std::move(pending_);
    reply->Error(code, message);
  }
}

void HandyCapturePlugin::Restore() {
  if (!hidden_) return;
  HWND window = hidden_;
  hidden_ = nullptr;
  ShowWindow(window, SW_SHOW);
  SetForegroundWindow(window);
  BOOL animate = FALSE;
  DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED, &animate,
                        sizeof(animate));
}

}  // namespace handy_capture
