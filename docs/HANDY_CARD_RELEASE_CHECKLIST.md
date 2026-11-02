# Handy Card — release checklist

Not release-ready. Open items, in order:

1. Build and run on Android, iOS, Windows and Web; record evidence under
   `docs/qa/evidence` with source hashes (`flutter-builds.ps1`,
   `flutter-source-fingerprint.py --app card`). Generate launcher icons
   (`tooling/app-icons.py`, entry `card`).
2. Device QA of the editor: touch drag/resize/rotate, two-finger zoom,
   long-press multi-select, inline text editing with on-screen keyboards,
   predictive back, desktop shortcuts with real keyboards.
3. Print a test sheet; check trim, bleed and crop marks with a ruler; scan
   printed QR codes at 15, 20 and 25 mm with two phones.
4. Golden tests comparing canvas, PNG and rasterised PDF output.
5. Store setup: product ids, AdMob ids, privacy forms (`docs/STORE_SETUP.md`,
   key `card`). Decide the Pro gates listed in the product spec.
6. Batch generator screen (engine exists), brand kits, NFC (Android first,
   with read-back verification), only after the above.

Never: fake purchases, fake NFC/Wallet buttons, bundled proprietary faces,
uploads of designs or contacts.
