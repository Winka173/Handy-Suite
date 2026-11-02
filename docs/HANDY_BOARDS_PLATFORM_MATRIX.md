# Handy Boards platform matrix

| Capability           | Android                                                                                                  | iOS                                                                       | Windows                                   | Web                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------ |
| Core/storage/UI      | Supported SQLite; emulator journey tested                                                                | Supported source; Not tested                                              | Supported SQLite; host persistence tested | Supported IndexedDB; real-browser storage tests passed (not complete Web UI certification) |
| Files                | Supported adapter; provider QA Not tested                                                                | Supported source; Not tested                                              | Supported source; installed UI Not tested | Partial picker/download; browser Not tested                                                |
| Notifications        | Supported adapter; delivery/permissions Not tested                                                       | Supported adapter; Not tested                                             | Partial: in-app center                    | Partial: in-app center; closed-browser Not supported                                       |
| Incoming shared text | Supported durable queue; external delivery Not tested                                                    | Supported App Group/BoardsShare source; Not tested                        | Not supported; clipboard/file fallback    | Not supported; clipboard/file fallback                                                     |
| Store                | Supported adapter; config missing                                                                        | Supported adapter; config missing                                         | Partial: association missing              | Not supported; stays Free                                                                  |
| Ads                  | Supported consent-gated source; default off                                                              | Supported consent-gated source; default off                               | Not supported                             | Not supported                                                                              |
| Build                | APK/AAB; unsigned AAB                                                                                    | Not tested: no Mac/Xcode                                                  | EXE/MSIX; unsigned, not installed         | Release + worker VM test; browser Not tested                                               |
| Widgets/shortcuts    | Supported source/provider and dynamic launcher actions; APK built, launcher runtime verification pending | WidgetKit target/App Group + quick actions source; Not tested without Mac | Not supported                             | Not supported                                                                              |

Supported describes implemented capability, not physical/store verification.
No physical devices, Mac/Xcode or publisher accounts available. No cross-store
entitlements. See [checkpoint](qa/evidence/boards-checkpoint.json) for current
source hashes/artifacts. Native notifications/extensions remain runtime release gates.

Native streaming files: ZIP/PDF preparation runs outside the UI isolate. Android
uses ACTION_CREATE_DOCUMENT with bounded copying and cancellation cleanup; iOS
uses UIDocumentPicker export-as-copy; desktop creates a unique destination file
through a partial staging file. Source implementation and automated round trips
are distinct from provider permissions/device runtime certification.
