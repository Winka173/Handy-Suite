# Release checklist

- [x] Independent Flutter target and exact-money domain; existing apps retained.
- [x] Real SQLite/IndexedDB adapters, ledger, planning and portable codecs implemented.
- [x] Initial unit/native-store/widget tests and audit documentation.
- [x] Full workspace regression (1698 pass / 28 skip), analyze and financial invariant review.
- [x] Dart source formatting and documentation formatting checks.
- [x] Android/Windows/Web builds and artifact hashes; unsigned AAB/MSIX.
- [x] Android emulator ledger/import/Undo/screenshots and notification deny/grant.
- [x] Frozen candidate `8655b2af2608`: 45 scoped tests, three builds, native flows, artifact hashes and eleven review screenshots.
- [ ] Revalidate current live workspace after concurrent UI edits are settled.
- [x] Independent EN/VI CSV/XLSX/JSON/PDF/ZIP decoding; native crash rollback test.
- [ ] Broader restore/provider UI and successful real device authentication.
- [ ] Browser installed-PWA/IndexedDB/drop/offline/update tests.
- [ ] Windows Explorer drop, Windows Hello, signed MSIX install/association.
- [ ] iOS compilation, Face ID/notifications and physical devices.
- [ ] All critical UI/import/sandbox flows, accessibility and storage pressure QA.
- [ ] Real publisher IDs, consent and purchase/restore/pending/cancel/refund tests.
- [ ] Owned identities/release signing and store disclosure review.

The app is not launch-ready while these requirements remain open. Core financial
data stays accessible for free. Never submit to stores without explicit approval.
The recorded full-workspace run is a baseline before concurrent UI edits. Frozen
Spend candidate proof is separate; the current live workspace is not certified.
P1 receipt/OCR, investment/debt issuer models and encrypted backup are deferred.
