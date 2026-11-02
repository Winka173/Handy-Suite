# Release checklist

- [x] Audit, reuse decisions and architecture before implementation.
- [x] P0 engine/UI, native SQLite, IndexedDB code and platform adapters.
- [x] Host validation, portable round-trips, corrupt input, CAS/rollback/Undo.
- [x] Android emulator journey/restart, denied GPS/notifications, picker cancel,
      OS share, notification delivery and native P1 file generation.
- [x] P1 stamps/book/EXIF/replay/comparison/templates/recipe and host tests.
- [x] Android/Windows/Web build evidence; inspect source hash per artifact.
- [x] UI screenshots and independent PDF/image/ZIP reader validation.
- [ ] Physical Android: camera/gallery recovery, real GPS, low storage,
      background/reboot reminders and OS document import/export providers.
- [ ] Mac/Xcode build/device QA, share extension and App Group provisioning.
- [ ] Real browser IndexedDB quota/multi-tab/eviction and installed PWA update.
- [ ] Windows native GPS/UI, installer installation, signed package/association.
- [ ] Publisher IDs, consent, official purchase/restore sandbox and store signing.

Builds/emulator passes do not substitute for unchecked release gates.
No publishing, paid service purchase or live billing changes performed.
