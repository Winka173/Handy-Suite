#include "../runner/share_drop_target.h"
#include <shellapi.h>
#include <shlobj.h>
#include <cstring>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

namespace {
// Synthetic IDataObject feeds real OLE drop callbacks without a Flutter engine.
class Payload final : public IDataObject {
 public:
  Payload(CLIPFORMAT format, std::vector<char> bytes)
      : format_(format), bytes_(std::move(bytes)) {}
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override {
    if (!object) return E_POINTER;
    *object = nullptr;
    if (iid == IID_IUnknown || iid == IID_IDataObject) {
      *object = static_cast<IDataObject*>(this); AddRef(); return S_OK;
    }
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return ++references_; }
  ULONG STDMETHODCALLTYPE Release() override {
    const ULONG remaining = --references_;
    if (!remaining) delete this;
    return remaining;
  }
  HRESULT STDMETHODCALLTYPE QueryGetData(FORMATETC* format) override {
    return format && format->cfFormat == format_ && (format->tymed & TYMED_HGLOBAL) ? S_OK : DV_E_FORMATETC;
  }
  HRESULT STDMETHODCALLTYPE GetData(FORMATETC* format, STGMEDIUM* medium) override {
    if (!medium) return E_POINTER;
    if (FAILED(QueryGetData(format))) return DV_E_FORMATETC;
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE, bytes_.size());
    if (!memory) return E_OUTOFMEMORY;
    void* target = GlobalLock(memory);
    if (!target) { GlobalFree(memory); return E_OUTOFMEMORY; }
    std::memcpy(target, bytes_.data(), bytes_.size()); GlobalUnlock(memory);
    *medium = STGMEDIUM{}; medium->tymed = TYMED_HGLOBAL; medium->hGlobal = memory;
    return S_OK;
  }
  HRESULT STDMETHODCALLTYPE GetDataHere(FORMATETC*, STGMEDIUM*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetCanonicalFormatEtc(FORMATETC*, FORMATETC*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE SetData(FORMATETC*, STGMEDIUM*, BOOL) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE EnumFormatEtc(DWORD, IEnumFORMATETC**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE DAdvise(FORMATETC*, DWORD, IAdviseSink*, DWORD*) override { return OLE_E_ADVISENOTSUPPORTED; }
  HRESULT STDMETHODCALLTYPE DUnadvise(DWORD) override { return OLE_E_ADVISENOTSUPPORTED; }
  HRESULT STDMETHODCALLTYPE EnumDAdvise(IEnumSTATDATA**) override { return OLE_E_ADVISENOTSUPPORTED; }
 private:
  ~Payload() = default;
  ULONG references_ = 1;
  CLIPFORMAT format_;
  std::vector<char> bytes_;
};
std::vector<char> TextBytes(const std::wstring& text, bool terminate = true) {
  const size_t size = (text.size() + (terminate ? 1 : 0)) * sizeof(wchar_t);
  std::vector<char> bytes(size);
  std::memcpy(bytes.data(), text.c_str(), size);
  return bytes;
}
std::vector<char> FileBytes(const std::wstring& path) {
  auto names = TextBytes(path);
  std::vector<char> bytes(sizeof(DROPFILES) + names.size() + sizeof(wchar_t), 0);
  DROPFILES header{}; header.pFiles = sizeof(DROPFILES); header.fWide = TRUE;
  std::memcpy(bytes.data(), &header, sizeof(header));
  std::memcpy(bytes.data() + sizeof(header), names.data(), names.size());
  return bytes;
}
bool Delivered(CLIPFORMAT format, const std::vector<char>& bytes,
               const std::string& expected, bool expect_success) {
  std::string received;
  int failures = 0;
  auto* target = new ShareDropTarget([&](const auto& text) { received = text; }, [&] { ++failures; });
  auto* data = new Payload(format, bytes);
  DWORD effect = DROPEFFECT_COPY;
  target->DragEnter(data, 0, POINTL{}, &effect);
  effect = DROPEFFECT_COPY;
  target->Drop(data, 0, POINTL{}, &effect);
  const bool passed = expect_success
      ? received == expected && failures == 0 && effect == DROPEFFECT_COPY
      : received.empty() && failures == 1 && effect == DROPEFFECT_NONE;
  data->Release(); target->Release();
  return passed;
}
struct TemporaryShortcut {
  std::wstring path;
  TemporaryShortcut() {
    wchar_t folder[MAX_PATH]{}, temporary[MAX_PATH]{};
    if (!GetTempPathW(MAX_PATH, folder) || !GetTempFileNameW(folder, L"hsv", 0, temporary)) return;
    path = std::wstring(temporary) + L".url";
    if (!MoveFileW(temporary, path.c_str())) { DeleteFileW(temporary); path.clear(); }
  }
  ~TemporaryShortcut() { if (!path.empty()) DeleteFileW(path.c_str()); }
  bool Write(const std::string& text) {
    if (path.empty()) return false;
    const HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr, TRUNCATE_EXISTING, 0, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    const bool success = WriteFile(file, text.data(), static_cast<DWORD>(text.size()), &written, nullptr) && written == text.size();
    CloseHandle(file); return success;
  }
};
}  // namespace

int main() {
  int failed = 0;
  auto check = [&](bool condition, const char* name) {
    std::cout << (condition ? "PASS " : "FAIL ") << name << '\n';
    if (!condition) ++failed;
  };
  check(Delivered(CF_UNICODETEXT, TextBytes(L"Read https://example.com/a and https://example.com/b"),
      "Read https://example.com/a and https://example.com/b", true), "surrounding text and multiple links");
  const auto url_format = static_cast<CLIPFORMAT>(RegisterClipboardFormatW(L"UniformResourceLocatorW"));
  check(Delivered(url_format, TextBytes(L"https://example.com/url"), "https://example.com/url", true), "shell Unicode URL format");
  check(Delivered(CF_UNICODETEXT, TextBytes(L"https://example.com", false), "", false), "unterminated text rejected");
  check(Delivered(CF_UNICODETEXT, TextBytes(std::wstring(262145, L'x')), "", false), "oversized text rejected");
  TemporaryShortcut file;
  check(file.Write("[InternetShortcut]\r\nURL=https://example.com/private?x=1\r\n") &&
      Delivered(CF_HDROP, FileBytes(file.path), "https://example.com/private?x=1", true), "explicit local shortcut parsed");
  check(file.Write("[InternetShortcut]\nURL=javascript:alert(1)\n") &&
      Delivered(CF_HDROP, FileBytes(file.path), "", false), "dangerous shortcut scheme rejected");
  check(file.Write("[Other]\nURL=https://example.com\n") &&
      Delivered(CF_HDROP, FileBytes(file.path), "", false), "wrong shortcut section rejected");
  check(file.Write("[InternetShortcut]\nURL=https://example.com/a\nURL=https://example.com/b\n") &&
      Delivered(CF_HDROP, FileBytes(file.path), "", false), "ambiguous shortcut rejected");
  check(file.Write(std::string(65537, 'x')) &&
      Delivered(CF_HDROP, FileBytes(file.path), "", false), "shortcut size bound");
  return failed ? 1 : 0;
}
