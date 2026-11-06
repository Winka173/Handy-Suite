# Handy Bookmark redesign: feature QA matrix

As of 2026-11-06, branch `ui-rebuild`. The labels mean exactly this:

- **DONE**: built, and covered by automated host tests (widget or unit) that pass. It has not
  been run on a phone unless the row says so.
- **CODE ONLY**: written and compiled where possible, but no automated test exercises the
  platform part.
- **TESTED EMULATOR** / **TESTED DEVICE**: run on an emulator or a real device, with evidence.
  **No row reaches these yet.**
- **BLOCKED**: needs something this machine does not have (named in the row).
- **NOT STARTED**.

| #   | Feature                                                                                              | Status                                  | Proof                                                                                                                              | Gap                                                                    |
| --- | ---------------------------------------------------------------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| 1   | No ads in Handy Bookmark                                                                             | DONE                                    | `evidence/ads-removal.md`: plugin list, merged manifest and the APK have no ads SDK; `handy_monetization` test `ad_slot_test.dart` | —                                                                      |
| 2   | Screenshots and photos as items (no URL)                                                             | DONE                                    | `pictures_test.dart`, engine `items_trash_test.dart`                                                                               | Device picker not tried                                                |
| 3   | The person's pictures as durable data (SHA-256, originals kept byte for byte, previews without EXIF) | DONE                                    | `pictures_test.dart`, `share_collection_test.dart` (preview metadata), `store_v4_test.dart`, `store_v4_browser_test.dart`          | —                                                                      |
| 4   | Backups carry pictures; restore checks them                                                          | DONE                                    | `backup_restore_test.dart`, engine `backup_pictures_test.dart`                                                                     | —                                                                      |
| 5   | Recently Deleted for 30 days, tombstones                                                             | DONE                                    | `trash_test.dart`, engine `items_trash_test.dart`                                                                                  | —                                                                      |
| 6   | Android: share images into the app                                                                   | CODE ONLY                               | Kotlin queue plus `share_pictures_test.dart` (Dart side, 4 tests); debug APK builds                                                | Not shared from a real gallery app                                     |
| 7   | iOS: share images into the app                                                                       | CODE ONLY / BLOCKED                     | Swift written to the same contract                                                                                                 | No Mac: not compiled, not run                                          |
| 8   | Visual home: collection covers, one Save button and sheet, All / Links / Pictures                    | DONE                                    | `home_test.dart` (4); screens reviewed (`VISUAL_DESIGN.md`)                                                                        | —                                                                      |
| 9   | Interactive first-run guide ending in a real save; replay in Settings                                | DONE                                    | `welcome_test.dart` (8); screens at 320, 390 (light and dark) and 1280 px reviewed (`ONBOARDING_FLOW.md`)                          | —                                                                      |
| 10  | Focus as a swipe deck with Undo, keys and buttons                                                    | DONE                                    | `focus_test.dart` (4); screen reviewed                                                                                             | —                                                                      |
| 11  | Each collection remembers cards or rows and its order                                                | DONE                                    | `collection_view_test.dart` (3)                                                                                                    | —                                                                      |
| 12  | Import from Raindrop.io (CSV and HTML)                                                               | DONE                                    | engine `raindrop_test.dart` (4), `raindrop_ui_test.dart`                                                                           | Tried on a written sample, not on a real account's export              |
| 13  | Weekly nudge when new saves wait unread                                                              | CODE ONLY (planning DONE)               | `revisit_test.dart` (4) covers the plan and the words                                                                              | The notification itself not fired on a device                          |
| 14  | Share a collection as one page; pictures without metadata                                            | DONE                                    | engine `collection_page_test.dart` (4), `share_collection_test.dart` (4)                                                           | System share sheet not tried on a device                               |
| 15  | Named library, home dateline with the day's finding                                                  | DONE                                    | `library_name_test.dart`                                                                                                           | —                                                                      |
| 16  | Storage use in Settings                                                                              | DONE                                    | `library_name_test.dart` (storage test)                                                                                            | —                                                                      |
| 17  | Sync protocol (merge, tombstones, pictures, conflicts, retries)                                      | DONE (simulated devices)                | engine `sync_test.dart` (11)                                                                                                       | —                                                                      |
| 18  | Sync through a cloud-kept folder on computers                                                        | CODE ONLY (+ host tests)                | `sync_folder_test.dart` (2, real files)                                                                                            | Not tried between two real computers                                   |
| 19  | Native iCloud Drive / Google Drive sync on phones                                                    | BLOCKED                                 | `SYNC_ARCHITECTURE_AND_TESTS.md`                                                                                                   | iCloud container, Mac/Xcode, Google OAuth client, two devices          |
| 20  | Optional Lifetime Pro, no subscriptions                                                              | Existing, unchanged                     | Copy says there are no ads                                                                                                         | Store purchase needs store setup (`docs/STORE_SETUP.md`): BLOCKED here |
| 21  | Tuckii first run studied                                                                             | Observed from the owner's iOS recording | `TUCKII_OBSERVATION.md` (hashes only)                                                                                              | Not driven by me; Android not seen                                     |

Bugs found and fixed while building these:

- After the first picture item, saving any link failed (`quickSave` normalised the picture's
  empty address).
- Link jobs and "Copy addresses" now skip pictures.
- The Filters sheet dropped Links / Pictures and "saved before".
- Previews kept the camera's EXIF, place included.
- Skip on the guide looped forever.
- Focus's animation controller was first created in `dispose`.
- "Clear saved pictures" was misleading now that the person owns pictures.
