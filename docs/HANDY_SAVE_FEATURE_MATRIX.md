# Handy Save feature matrix

Updated 2026-11-01. Status applies to the scope in each row, not all platforms.
`PLATFORM_VERIFIED` requires execution on that platform. No physical device or
iOS execution is claimed. The application remains **IN_PROGRESS** for release verification; the local implementation and checks
are recorded below. Passing local checks does not certify untested platforms.

| Feature                                                       | Status                    | Evidence / boundary                                                                                                                                                              |
| ------------------------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| URL extraction, conservative normalization, service detection | UNIT_TESTED               | Shared text/multiple URLs, unknown domains, queries, Unicode, valid YouTube/X equivalence; original URL preserved                                                                |
| Bookmark CRUD, collections/subcollections, tags, flags, notes | UNIT_TESTED               | Immutable domain tests and validated forms; parent-cycle refusal; standalone tags and applied tags                                                                               |
| Native SQLite, transactions/indexes/FTS, pagination           | INTEGRATION_TESTED        | Real SQLite worker tests on Windows; rollback, reopen, integrity, future schema refusal, 50k rows; mobile run recorded separately                                                |
| Browser local records                                         | IMPLEMENTED               | IndexedDB per-record transactions; quota/blocked/error handling; browser runtime unverified                                                                                      |
| Android Quick Save                                            | EMULATOR_TESTED           | Five actual native queue tests + real cold/warm SEND, multi-URL, duplicate, exact SQLite persistence and empty ack queue; physical/social app QA remains                         |
| iOS Share Extension                                           | IMPLEMENTED               | Embedded Xcode extension target, App Group durable inbox, no metadata/ads/host launch; macOS/signing verification required                                                       |
| Clipboard                                                     | EMULATOR_TESTED           | Explicit clipboard read and repeated-value suppression in native Flutter integration; OS denial handling remains platform-dependent                                              |
| Windows drop                                                  | IMPLEMENTED               | Real OLE IDropTarget text/URL/.url; MSVC compilation + 9 parser/data-object tests; Explorer/browser UI drop pending                                                              |
| Web Share Target                                              | UNIT_TESTED               | POST worker, durable IndexedDB before redirect; size/format/path/quota checks in Node VM; installed-PWA/browser test pending                                                     |
| Open original                                                 | EMULATOR_TESTED           | Actual card tap dispatches outside Handy Save to Android Chrome First Run; original URL preserved. Website loading and installed-social-app/app-first behavior remain unverified |
| Metadata and thumbnails                                       | UNIT_TESTED               | Native pinned public DNS/socket, redirect/size/MIME/timeout/cancel/rate bounds; verified static raster cache; Web refuses unsafe fetch capability                                |
| Search/filter/sort/manual order                               | UNIT_TESTED               | Title/URL/notes/tag/collection/domain/platform, dates/opened dates, flags; SQLite FTS and browser fallback; paginated list/grid                                                  |
| Smart Collections / saved searches                            | UNIT_TESTED               | Real local AND/OR builder, dynamic withinDays, saved filters; verified store Pro entitlement gates UI                                                                            |
| Focus                                                         | EMULATOR_UI_TESTED        | Unread queue and filters implemented; actual Android Focus screen captured; complete action/accessibility review remains                                                         |
| Local reminders                                               | EMULATOR_TESTED           | Android denied/granted, 50 future schedule cap, generic private content, immediate OS delivery and cancel pass; delayed/reboot/tap/iOS remain unverified                         |
| Batch actions / safe Undo                                     | IMPLEMENTED               | Move/tag/read/favorite/archive/delete/copy/export; filtered select-all progress/cancel; Undo refuses stale library                                                               |
| JSON/CSV/HTML/Markdown/TXT/ZIP                                | UNIT_TESTED               | Six exact full-snapshot roundtrips and interoperable visible links; bounded preview, duplicate counts, merge/replace confirmation; SHA/ZIP-path refusal                          |
| Recovery and cache cleanup                                    | INTEGRATION_TESTED        | Real native corrupted-file preserve/reset test, byte/hash preservation, clean database reopen; thumbnail LRU/cascade tests; browser runtime remains unverified                   |
| EN/VI, theme/responsive UI                                    | UNIT_TESTED + EMULATOR_UI | Bilingual validated forms; 320px/2x editor and 360px/1.6x home/settings tests; six current Android screenshots; full accessibility/platform review remains                       |
| Free + Ads + Pro Lifetime                                     | IMPLEMENTED               | Existing suite native controller/adapters; app key save; no ads in quick-save/extension/open; real store provisioning required                                                   |
| Android/Windows/Web builds                                    | BUILD_TESTED              | Seven apps x three targets, current-source build records; unsigned Windows MSIX validated separately; no iOS/runtime/store certification                                         |
| iOS build, physical social share, store release               | BLOCKED                   | Requires macOS/Xcode/signing/physical devices and publisher accounts; no fabricated verification                                                                                 |

Raw results and screenshots: `docs/qa/evidence/save-*`. Current limits:
[HANDY_SAVE_KNOWN_LIMITATIONS](HANDY_SAVE_KNOWN_LIMITATIONS.md).

Current workspace: **1,567 tests passed across 25 packages/apps**, 28 documented skips.
Save app: 38 unit/widget/native SQLite tests. Engine tests include six-format roundtrips.
All 21 builds, seven unsigned MSIX packages, unsigned Android release AAB, and
Save Android integration/share/open/notification results match the current source.
The current checkpoint audit is `qa/evidence/save-checkpoint-audit.json`; older six-app
native integration evidence is retained historically and is not claimed as rerun here.
