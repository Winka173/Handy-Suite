# Release checklist

- [x] Independent Flutter target and exact-money domain; existing apps retained.
- [x] Real SQLite/IndexedDB adapters, ledger, planning and portable codecs implemented.
- [x] Initial unit/native-store/widget tests and audit documentation.
- [ ] Latest full regression, analyze/format, financial invariant review.
- [ ] Android/Windows/Web builds and artifact hashes; unsigned AAB/MSIX as applicable.
- [ ] Android emulator smoke/screenshots, permissions, lock cancellation and restore.
- [ ] Browser installed-PWA/IndexedDB/drop/offline/update tests.
- [ ] Windows Explorer drop, Windows Hello, signed MSIX install/association.
- [ ] iOS compilation, Face ID/notifications and physical devices.
- [ ] All critical UI/import/sandbox flows, accessibility and storage pressure QA.
- [ ] Real publisher IDs, consent and purchase/restore/pending/cancel/refund tests.
- [ ] Owned identities/release signing and store disclosure review.

The app is not launch-ready while these requirements remain open. Core financial
data stays accessible for free. Never submit to stores without explicit approval.
P1 receipt/OCR, investment/debt issuer models and encrypted backup are deferred.
