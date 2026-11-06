# Flow acceptance

"Taps" count from the starting screen.

**Evidence types**
- Test: a host widget or unit test in `apps/handy_bookmark/test/`.
- Shot: a host render in `shots/after/` (git-ignored; regenerate with `tool/screens_test.dart` and `tool/screens_library_test.dart`).
- BlueStacks: an Android 11 emulator, driven by adb.

| Journey | Taps | Evidence |
| ------- | ---- | -------- |
| Fresh launch → skip guide → home | 1 (Skip) | Test `welcome_test.dart`; BlueStacks |
| Save a URL in the app | Save → paste/type → Save: 3 | Tests `save_sheet_test.dart`, `widget_test.dart`; shot `small-31-save.png`. No metadata fetch blocks the save (page details are off by default). |
| Share a URL in from another app | the OS share sheet → Handy Bookmark: 1 after Share; or a collection in the top row | BlueStacks: `am start SEND` saved it to Not sorted. A real Chrome share into a collection was checked in the previous pass. |
| Share a picture in | as above | Code and unit tests only (`share_pictures_test.dart`); not run on a device |
| Find by search | type in the home search | Tests `widget_test.dart`; shots `lib-phone-search*.png` |
| Find by collection | home cover → collection: 1 | Tests `home_test.dart`; shots `lib-*-collection.png` |
| Open a link / view a picture | tap the item: 1 | Tests `widget_test.dart`, `detail_focus_ui_test.dart` |
| Rename | "…" → Rename → type → Save: 3 | Tests `rename_share_test.dart`: survives a metadata refresh, a ZIP round trip and a Trash restore; shots `phone-item-1-rename.png`, `small-item-3-rename-dark.png` |
| Share a link out | detail → Share: 2 | Test `rename_share_test.dart`; BlueStacks: the Android share sheet opened with "title + https://vnexpress.net/du-lich", no note |
| Share a picture out | detail → Share → choice → Share: 3 | Tests (a clean re-encode by default; the original on request); shot `phone-item-9-share-picture-*.png`; not on a device |
| Organize | shelf "Put in…" → collection: 2 | Tests `widget_test.dart`; shots `phone-1-home.png` |
| Focus | home door → swipe or buttons | Tests `detail_focus_ui_test.dart`, `focus_test.dart`; shots `phone-6-focus.png`, `phone-45-focus-poster-*.png` |
| Reader online → find → leave and reopen at the same spot → Save offline | detail → Read: 2 | Tests `reader_test.dart` (15, with a fake network); shots `phone-50..53`, `small-54`. A live fetch from a real site was not run. |
| Trash → restore | detail Delete; Library › Recently deleted → Restore | Tests `trash_test.dart`, `lifecycle_store_test.dart` (an offline copy survives Trash → ZIP → fresh restore) |
| Back up / Restore | Settings › Data & sync › Back up: 2 taps | Tests `backup_restore_test.dart`, `data_safety_test.dart`, `settings_reminders_test.dart` |
| Sync | Settings › Data & sync › Sync (desktop folder only) | Engine and folder tests from earlier passes; no mobile sync exists |

**Counts:** app tests 200 passed, engine 125, handy_files 15; `flutter analyze` clean; format clean.
