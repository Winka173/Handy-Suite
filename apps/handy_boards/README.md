# Handy Boards

Universal, offline category-first task manager in Handy Suite. Canonical task IDs
are shared by Categories, Kanban, List, Table, Today, Calendar and advanced tools.
Study and other domains are opt-in templates. No backend/account/cloud AI.

From the monorepo root on Windows:

```powershell
./tooling/flutter-bootstrap.ps1
Push-Location apps/handy_boards
flutter run -d windows
Pop-Location
./tooling/boards-check.ps1
```

Android/iOS/Windows/Web sources reuse shared Handy UI, files, notifications and
real Ads/Pro Lifetime adapters. iOS requires Mac/Xcode and App Group provisioning;
publisher identifiers/signing are not configured. No release entitlement fixture.

Native SQLite and browser IndexedDB are independent of every other Handy app.
Schema 1 is additive; future schemas refuse without resetting data. Edits validate
before transactional CAS commit. User originals are never overwritten.

Full ZIP/JSON transfers include assets and stable references; merge remaps IDs.
Template JSON/ZIP uses fresh IDs and strips private notes/history/media; recurrence
requires explicit opt-in and imports disabled. See portable bounds before export.

- [Feature matrix](../../docs/HANDY_BOARDS_FEATURE_MATRIX.md)
- [Architecture](../../docs/HANDY_BOARDS_ARCHITECTURE.md)
- [Import/export](../../docs/HANDY_BOARDS_IMPORT_EXPORT.md)
- [Actual QA commands/results](../../docs/HANDY_BOARDS_TEST_PLAN.md)
- [Known limitations](../../docs/HANDY_BOARDS_KNOWN_LIMITATIONS.md)
- [Review screenshots](../../review-shots/boards/README.md)

The complete production master prompt remains IN_PROGRESS. Builds and host tests
do not establish physical-device, iOS, browser or store-release verification.
