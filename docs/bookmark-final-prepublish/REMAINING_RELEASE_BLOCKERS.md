# Remaining release blockers

## Decision

**Not ready: external verification blockers.**

The code for the approved simplification is in place and passes on the host:
- app: 200 tests;
- engine: 125 tests;
- handy_files: 15 tests;
- analyze clean;
- release APK, AAB, web and Windows builds succeed.

What is missing is evidence that only devices, stores and accounts can give.

## Environment unavailable

| # | Blocker | Severity | Needs |
| - | ------- | -------- | ----- |
| 1 | iOS: nothing compiled (share extension, App Group, notifications, StoreKit) | High | Mac + Xcode + Apple Developer account, a device |
| 2 | Pro Lifetime purchase, restore, pending and refund never run against a store | High | Play Console + App Store Connect products (SKU), licence testers, a real package name, signing keys |
| 3 | Android picture share-in, multiple pictures, mixed payloads, killed-process receive: only host tests | Medium | A real phone (or more emulator runs with a gallery app), real photos |
| 4 | Reader online fetch against real sites (timeouts, cancel, JS-only pages) | Medium | Network run on a device |
| 5 | Mobile sync (iCloud, Google Drive) not built; the UI says manual desktop folder sync only | Medium (scope) | See `NATIVE_RELEASE_MATRIX.md` |
| 6 | Release signing: the package is still `com.example.handysuite.bookmark`, builds are unsigned | High for store | Final package id, upload key |

## Code not finished

| # | Item | Where |
| - | ---- | ----- |
| 7 | Refuse a plain sync merge for a device whose last sync is older than the 365-day tombstone horizon | `lib/sync/sync_service.dart` |
| 8 | Real screen-reader passes (TalkBack, VoiceOver); only the semantics tests and guideline checks ran | — |
| 9 | Tuckii was not installed and studied directly (it needs a Google account sign-in on the emulator); the reference remains the owner's recording (`docs/bookmark-redesign/TUCKII_OBSERVATION.md`) | — |
