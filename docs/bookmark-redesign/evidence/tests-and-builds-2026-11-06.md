# Tests and builds, 2026-11-06

Run on the development PC (Windows 11, Flutter 3.44.9) after commit `4744541`. These are host
runs and builds. Nothing here is evidence of an emulator or device run.

| What                    | Command (from the package folder)                                                                    | Result                                                |
| ----------------------- | ---------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Handy Bookmark tests    | `flutter test --no-pub`                                                                              | 136 passed, 0 failed                                  |
| Bookmark engine tests   | `flutter test --no-pub`                                                                              | 77 passed, 0 failed                                   |
| Browser IndexedDB tests | `dart test -p chrome -j 1 test/store_v4_browser_test.dart` and `test/reading_undo_browser_test.dart` | 2 + 2 passed (Chrome)                                 |
| Analyze                 | `dart analyze lib test tool integration_test`                                                        | No issues                                             |
| Format                  | `dart format --output=none --set-exit-if-changed lib test`                                           | 0 changed                                             |
| Android                 | `flutter build apk --debug --no-pub`                                                                 | Built `app-debug.apk` (Kotlin share queue compiles)   |
| Web                     | `flutter build web --no-pub --no-web-resources-cdn`                                                  | Built `build/web` (sync and share-file stubs compile) |
| Windows                 | `flutter build windows --debug --no-pub`                                                             | Built `handy_bookmark.exe`                            |
| iOS                     | —                                                                                                    | Not built: no Mac                                     |

Screens rendered with `SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart` were
reviewed:

- guide: phone, phone dark, 320 px, 1280 px;
- home: phone, tablet, desktop;
- the Save sheet;
- Focus.

The shot files are not committed. Re-render them with the command above.
