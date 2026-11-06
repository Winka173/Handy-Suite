# Native and release matrix

**Status values**
- **I:** implemented
- **B:** built
- **H:** host-tested
- **E:** emulator-tested (BlueStacks, Android 11)
- **D:** real device
- **X:** blocked

| Area | Android | iOS | Windows | Web |
| ---- | ------- | --- | ------- | --- |
| Release build | APK and AAB release B (exit 0; 73.0 MB / 70.3 MB, unsigned); the integration_test registrant failure is fixed by a release-only stand-in | X: no Mac or Xcode | B (`flutter build windows --release`) | B (`--no-web-resources-cdn`; `main.dart.js` 5.1 MB) |
| Ads audit | No ad SDK, no `AD_ID`: Play Billing pulls `play-services-location` and `datatransport` (its own reporting) | — | — | — |
| Share in, text/link | I, H, E (SEND intent saved) | I (code), X | — | Web Share Target I |
| Share in, pictures | I, H; not E | I (code), X | — | — |
| Collections in the share sheet's top row | I, H, E (Chrome → More → collection, previous pass) | — | — | — |
| Share out, link | I, H, E (Android sheet opened) | I, X | I (share_plus), not run | I (`navigator.share`), not run |
| Share out, picture (EXIF choice) | I, H; not E | I, X | I, not run | — |
| Reader online fetch | I, H (fake network); not run against a real site | X | not run | Honest "not available" message |
| Notifications (weekly nudge, existing reminders) | I, H; cancel on turning off H | X | I, H | none |
| In-app purchase (Pro Lifetime) | Billing library linked; no SKU or real store test | X | — | — |
| Cloud sync | Manual folder sync on desktop only; no mobile sync | X | I, H | none |

**Mobile sync (iCloud, Google Drive): not implemented.**
- Google Drive needs:
  - a Cloud project, the Drive API and an OAuth consent screen;
  - client IDs, including the release SHA-1 (the package is still `com.example.*` and there is no release key);
  - `google_sign_in` and the `drive.appdata` scope;
  - version-check-and-remerge, because Drive has no conditional write.
- iCloud needs an Apple Developer account, a container entitlement, a Swift plugin, and a Mac with a real iPhone.
- Next steps:
  - a `SyncProvider` adapter package with a shared contract test suite;
  - refusing to merge a device whose last sync is older than the 365-day tombstone horizon;
  - tests on two real devices.
