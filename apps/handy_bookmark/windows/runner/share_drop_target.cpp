#include "share_drop_target.h"

#include <shellapi.h>
#include <algorithm>
#include <cwctype>
#include <optional>
#include <utility>
#include <vector>

namespace {
constexpr size_t kMaximumCharacters = 262144;
constexpr DWORD kMaximumShortcutBytes = 65536;
constexpr UINT kMaximumFiles = 100;
FORMATETC Format(CLIPFORMAT type) {
  return FORMATETC{type, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
}
CLIPFORMAT UrlFormat() {
  return static_cast<CLIPFORMAT>(RegisterClipboardFormatW(L"UniformResourceLocatorW"));
}
bool Has(IDataObject* object, CLIPFORMAT type) {
  auto format = Format(type);
  return object && type && SUCCEEDED(object->QueryGetData(&format));
}
struct Medium {
  STGMEDIUM value{};
  ~Medium() { if (value.tymed != TYMED_NULL) ReleaseStgMedium(&value); }
};
struct Handle {
  HANDLE value = INVALID_HANDLE_VALUE;
  ~Handle() { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
};
std::wstring Trim(const std::wstring& text) {
  size_t first = 0, last = text.size();
  while (first < last && std::iswspace(text[first])) ++first;
  while (last > first && std::iswspace(text[last - 1])) --last;
  return text.substr(first, last - first);
}
std::wstring Lower(std::wstring text) {
  std::transform(text.begin(), text.end(), text.begin(),
      [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return text;
}
bool HttpUrl(const std::wstring& text) {
  const auto lower = Lower(text);
  return (lower.rfind(L"http://", 0) == 0 || lower.rfind(L"https://", 0) == 0) &&
      std::none_of(text.begin(), text.end(), [](wchar_t c) { return c <= 32; });
}
std::optional<std::string> Utf8(const std::wstring& text) {
  if (text.empty() || text.size() > kMaximumCharacters) return std::nullopt;
  const auto length = static_cast<int>(text.size());
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      text.data(), length, nullptr, 0, nullptr, nullptr);
  if (!size) return std::nullopt;
  std::string result(static_cast<size_t>(size), '\0');
  if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(), length,
                          result.data(), size, nullptr, nullptr)) return std::nullopt;
  return result;
}
std::optional<std::wstring> WideText(IDataObject* object, CLIPFORMAT type) {
  auto format = Format(type);
  Medium medium;
  if (FAILED(object->GetData(&format, &medium.value)) ||
      medium.value.tymed != TYMED_HGLOBAL) return std::nullopt;
  const SIZE_T size = GlobalSize(medium.value.hGlobal);
  if (size < sizeof(wchar_t) || size > (kMaximumCharacters + 1) * sizeof(wchar_t)) return std::nullopt;
  const auto* text = static_cast<const wchar_t*>(GlobalLock(medium.value.hGlobal));
  if (!text) return std::nullopt;
  size_t length = 0;
  while (length < size / sizeof(wchar_t) && text[length] != L'\0') ++length;
  std::optional<std::wstring> result;
  if (length > 0 && length <= kMaximumCharacters && length < size / sizeof(wchar_t)) result.emplace(text, length);
  GlobalUnlock(medium.value.hGlobal);
  return result;
}
std::optional<std::wstring> DecodeShortcut(const std::vector<char>& data) {
  if (data.size() >= 2 && static_cast<unsigned char>(data[0]) == 0xff &&
      static_cast<unsigned char>(data[1]) == 0xfe) {
    if (data.size() % 2 != 0) return std::nullopt;
    std::wstring text;
    text.reserve((data.size() - 2) / 2);
    for (size_t i = 2; i < data.size(); i += 2) {
      text.push_back(static_cast<wchar_t>(static_cast<unsigned char>(data[i]) |
          (static_cast<unsigned int>(static_cast<unsigned char>(data[i + 1])) << 8)));
    }
    if (text.find(L'\0') != std::wstring::npos) return std::nullopt;
    return text;
  }
  size_t start = 0;
  if (data.size() >= 3 && static_cast<unsigned char>(data[0]) == 0xef &&
      static_cast<unsigned char>(data[1]) == 0xbb && static_cast<unsigned char>(data[2]) == 0xbf) start = 3;
  const auto length = static_cast<int>(data.size() - start);
  if (!length || std::find(data.begin() + start, data.end(), '\0') != data.end()) return std::nullopt;
  UINT code_page = CP_UTF8;
  DWORD flags = MB_ERR_INVALID_CHARS;
  int size = MultiByteToWideChar(code_page, flags, data.data() + start, length, nullptr, 0);
  if (!size && start == 0) { code_page = CP_ACP; flags = 0; size = MultiByteToWideChar(code_page, flags, data.data(), length, nullptr, 0); }
  if (!size) return std::nullopt;
  std::wstring text(static_cast<size_t>(size), L'\0');
  if (!MultiByteToWideChar(code_page, flags, data.data() + start, length, text.data(), size)) return std::nullopt;
  return text;
}
std::optional<std::wstring> ShortcutUrl(const std::wstring& path) {
  // Only read explicitly dropped local regular .url files. Never execute a
  // shortcut, follow its URL, walk a directory, or resolve a content provider.
  if (path.size() < 7 || path.size() > 32767 || path[1] != L':' || path[2] != L'\\' ||
      !std::iswalpha(path[0]) || Lower(path.substr(path.size() - 4)) != L".url") return std::nullopt;
  if (path.find(L"\\..\\") != std::wstring::npos || path.find(L"\\.\\") != std::wstring::npos) return std::nullopt;
  const wchar_t drive[] = {path[0], L':', L'\\', L'\0'};
  const UINT drive_type = GetDriveTypeW(drive);
  if (drive_type != DRIVE_FIXED && drive_type != DRIVE_REMOVABLE) return std::nullopt;
  Handle file;
  file.value = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN, nullptr);
  if (file.value == INVALID_HANDLE_VALUE) return std::nullopt;
  BY_HANDLE_FILE_INFORMATION info{};
  LARGE_INTEGER size{};
  if (!GetFileInformationByHandle(file.value, &info) ||
      (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) ||
      !GetFileSizeEx(file.value, &size) || size.QuadPart <= 0 || size.QuadPart > kMaximumShortcutBytes) return std::nullopt;
  std::vector<char> data(static_cast<size_t>(size.QuadPart));
  DWORD read = 0;
  if (!ReadFile(file.value, data.data(), static_cast<DWORD>(data.size()), &read, nullptr) ||
      read != data.size()) return std::nullopt;
  const auto text = DecodeShortcut(data);
  if (!text) return std::nullopt;
  bool internet_shortcut = false;
  std::optional<std::wstring> url;
  size_t start = 0;
  while (start <= text->size()) {
    const size_t end = text->find(L'\n', start);
    const auto line = Trim(text->substr(start, end == std::wstring::npos ? end : end - start));
    if (!line.empty() && line.front() == L'[') {
      internet_shortcut = Lower(line) == L"[internetshortcut]";
    } else if (internet_shortcut) {
      const size_t equals = line.find(L'=');
      if (equals != std::wstring::npos && Lower(Trim(line.substr(0, equals))) == L"url") {
        if (url) return std::nullopt;
        const auto candidate = Trim(line.substr(equals + 1));
        if (!HttpUrl(candidate)) return std::nullopt;
        url = candidate;
      }
    }
    if (end == std::wstring::npos) break;
    start = end + 1;
  }
  return url;
}
std::optional<std::wstring> FileUrls(IDataObject* object) {
  auto format = Format(CF_HDROP);
  Medium medium;
  if (FAILED(object->GetData(&format, &medium.value)) || medium.value.tymed != TYMED_HGLOBAL) return std::nullopt;
  const auto files = reinterpret_cast<HDROP>(medium.value.hGlobal);
  const UINT count = DragQueryFileW(files, 0xffffffff, nullptr, 0);
  if (!count || count > kMaximumFiles) return std::nullopt;
  std::wstring combined;
  for (UINT i = 0; i < count; ++i) {
    const UINT length = DragQueryFileW(files, i, nullptr, 0);
    if (!length || length > 32767) return std::nullopt;
    std::vector<wchar_t> path(static_cast<size_t>(length) + 1);
    if (DragQueryFileW(files, i, path.data(), length + 1) != length) return std::nullopt;
    const auto url = ShortcutUrl(std::wstring(path.data(), length));
    if (!url || combined.size() + url->size() + (combined.empty() ? 0 : 1) > kMaximumCharacters) return std::nullopt;
    if (!combined.empty()) combined += L'\n';
    combined += *url;
  }
  return combined;
}
std::optional<std::string> Extract(IDataObject* object) {
  if (!object) return std::nullopt;
  if (Has(object, UrlFormat())) {
    const auto url = WideText(object, UrlFormat());
    if (url && HttpUrl(Trim(*url))) return Utf8(Trim(*url));
  }
  if (Has(object, CF_HDROP)) {
    const auto urls = FileUrls(object);
    return urls ? Utf8(*urls) : std::nullopt;
  }
  if (Has(object, CF_UNICODETEXT)) {
    const auto text = WideText(object, CF_UNICODETEXT);
    return text ? Utf8(*text) : std::nullopt;
  }
  return std::nullopt;
}
}  // namespace

ShareDropTarget::ShareDropTarget(Receive receive, Failure failure)
    : receive_(std::move(receive)), failure_(std::move(failure)) {}
HRESULT STDMETHODCALLTYPE ShareDropTarget::QueryInterface(REFIID iid, void** object) {
  if (!object) return E_POINTER;
  *object = nullptr;
  if (iid == IID_IUnknown || iid == IID_IDropTarget) { *object = static_cast<IDropTarget*>(this); AddRef(); return S_OK; }
  return E_NOINTERFACE;
}
ULONG STDMETHODCALLTYPE ShareDropTarget::AddRef() { return static_cast<ULONG>(InterlockedIncrement(&references_)); }
ULONG STDMETHODCALLTYPE ShareDropTarget::Release() {
  const LONG count = InterlockedDecrement(&references_);
  if (!count) delete this;
  return static_cast<ULONG>(count);
}
HRESULT STDMETHODCALLTYPE ShareDropTarget::DragEnter(IDataObject* data, DWORD, POINTL, DWORD* effect) {
  if (!effect) return E_POINTER;
  supported_ = Has(data, UrlFormat()) || Has(data, CF_UNICODETEXT) || Has(data, CF_HDROP);
  *effect = supported_ && (*effect & DROPEFFECT_COPY) ? DROPEFFECT_COPY : DROPEFFECT_NONE;
  return S_OK;
}
HRESULT STDMETHODCALLTYPE ShareDropTarget::DragOver(DWORD, POINTL, DWORD* effect) {
  if (!effect) return E_POINTER;
  *effect = supported_ && (*effect & DROPEFFECT_COPY) ? DROPEFFECT_COPY : DROPEFFECT_NONE;
  return S_OK;
}
HRESULT STDMETHODCALLTYPE ShareDropTarget::DragLeave() { supported_ = false; return S_OK; }
HRESULT STDMETHODCALLTYPE ShareDropTarget::Drop(IDataObject* data, DWORD, POINTL, DWORD* effect) {
  if (!effect) return E_POINTER;
  const bool allowed = (*effect & DROPEFFECT_COPY) != 0;
  *effect = DROPEFFECT_NONE;
  supported_ = false;
  if (!allowed) return S_OK;
  const auto text = Extract(data);
  if (text) { receive_(*text); *effect = DROPEFFECT_COPY; }
  else { failure_(); }
  return S_OK;
}
