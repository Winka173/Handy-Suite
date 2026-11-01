# Handy Save release checklist

- [x] Independent Android/iOS/Windows/Web targets; Handy Save icon/name and version.
- [x] Local database/domain, durable native share queues and portable formats.
- [x] Shared Handy theme/EN-VI, Ads + Pro Lifetime adapters and app key `save`.
- [x] Privacy screen: local data, metadata disclosure, clipboard explicit action,
      no backend/account/URL telemetry; bookmark content excluded from ads.
- [x] Final-source analyze/tests and 21 Android/Windows/Web builds recorded.
- [x] Android emulator cold/warm/multiple share, five native queue tests and UI screenshots.
- [x] Android emulator notification denied/granted, 50 schedule cap, immediate delivery/cancel.
- [x] Seven unsigned MSIX packages validated by MakeAppx (not installed/signed).
- [x] Actual Android card tap dispatches to the OS URL handler (Chrome First Run).
- [x] Android release AAB compiles unsigned; manifest/signature absence and artifact hash checked.
- [ ] Signed Android release AAB with owned package identity (no debug key release).
- [ ] iOS build and Share Extension/App Group entitlement/signing verification.
- [ ] Windows signed MSIX install and official Store product association.
- [ ] Installed PWA share/offline/update and IndexedDB behavior on actual browsers.
- [ ] Physical social-app share/open, accessibility, frame/memory and storage pressure QA.
- [ ] Notification permission, tap routing, delayed/background/reboot behavior.
- [ ] Production store/AdMob IDs and consent; real purchase/restore/pending/refund tests.
- [ ] Store disclosures/descriptions and real screenshots reviewed.

Do not submit a release without explicit authorization. Unconfigured purchases
remain unavailable, never replaced by a local Pro toggle. Default debug identities
are provisional; no published application identity has been changed.

Current local evidence audit: `qa/evidence/save-checkpoint-audit.json`.
Passed local checks do not close the unchecked release requirements above.

Build Android development: `tooling/flutter-builds.ps1 -Apps @('save') -Target apk`.
Compile the unsigned release bundle: `tooling/save-aab.ps1`. It regenerates release
plugin registration; after release builds the screenshot/notification runners
regenerate debug registration. Do not reuse `--no-pub` across these build modes.
Windows/Web: same command with `windows`/`web`. MSIX: `tooling/flutter-msix.ps1 -App save`
after a current-source Windows build. On macOS, compile Runner and SaveShare with
the configured App Group and actual team; this environment cannot certify that.
