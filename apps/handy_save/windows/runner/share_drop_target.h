#ifndef HANDY_SAVE_SHARE_DROP_TARGET_H_
#define HANDY_SAVE_SHARE_DROP_TARGET_H_

#include <windows.h>
#include <oleidl.h>
#include <functional>
#include <string>

// OLE registration owns a reference until RevokeDragDrop during teardown.
class ShareDropTarget final : public IDropTarget {
 public:
  using Receive = std::function<void(const std::string&)>;
  using Failure = std::function<void()>;
  ShareDropTarget(Receive receive, Failure failure);
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void** object) override;
  ULONG STDMETHODCALLTYPE AddRef() override;
  ULONG STDMETHODCALLTYPE Release() override;
  HRESULT STDMETHODCALLTYPE DragEnter(IDataObject* data, DWORD keys,
                                      POINTL point, DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragOver(DWORD keys, POINTL point,
                                     DWORD* effect) override;
  HRESULT STDMETHODCALLTYPE DragLeave() override;
  HRESULT STDMETHODCALLTYPE Drop(IDataObject* data, DWORD keys,
                                 POINTL point, DWORD* effect) override;
 private:
  ~ShareDropTarget() = default;
  LONG references_ = 1;
  bool supported_ = false;
  Receive receive_;
  Failure failure_;
};
#endif
