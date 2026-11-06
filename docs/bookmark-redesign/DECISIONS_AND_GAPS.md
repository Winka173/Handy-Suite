# Handy Bookmark redesign: decisions and gaps

Baseline: commit `eb25235` (the 2026-11-05 working tree, committed as found: reading-copy
undo with SQLite schema 3 / IndexedDB 3 `reading_trash`, inline capture, batch sizes, app
identity). Bookmark 84/84 and engine 41/41 tests passed on that baseline before any change.
Product dossier: `docs/HANDY_BOOKMARK_HO_SO_DAY_DU.html` (06/11/2026).

## Decisions (from the approved master prompt and supplement)

- No ads in Handy Bookmark, no subscriptions, optional one-time Pro Lifetime, no account,
  no own backend.
- Keep every advanced URL tool, the offline reader, Pocket and the six portable formats;
  move rarely used tools out of the beginner path instead of deleting them.
- Not built: browser extension, AI summaries, social-media downloading, scraping private
  or paywalled pages, a social network.
- Cloud sync (iCloud / Google Drive) is approved; it is built only on top of durable media,
  Trash and tombstones, and native adapters stay marked unverified until two real devices
  prove them.

## Gap matrix

Status: Existing · Partial · Missing · Blocked · Done (this redesign, with the commit).

| Area                                                    | Status                                                                                  | Proof / note                                                                                                                                                 |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ads removed from Bookmark (UI, init, IDs, SDK in build) | Done (`docs/bookmark-redesign/evidence/ads-removal.md`)                                 | Was: AdMob banner via `handy_ui` → `handy_monetization` → `google_mobile_ads`; `adsVisible` in controller; AdMob meta-data in AndroidManifest and Info.plist |
| Image / screenshot items without a URL                  | Done (`0d0e330`)                                                                        | `Bookmark` requires `originalUrl` (engine `models.dart`); no content kind                                                                                    |
| User-owned images as durable data                       | Done (`0d0e330`, `b9c0387`; previews without EXIF `79e9870`)                            | Custom pictures live in the thumbnail LRU cache (~20 MB) and are not backed up (dossier §16)                                                                 |
| Full backup with images                                 | Done (`02a0a29`)                                                                        | JSON/ZIP carry reading copies within 30 MB; no images (dossier §18)                                                                                          |
| Recently Deleted (Trash) for items                      | Done (`c6a2343`)                                                                        | Only 7-day `reading_trash` for offline copies, hidden, Undo one step (dossier §13)                                                                           |
| Tombstones / revisions for sync                         | Done (`b614780`, used by sync `e3a1933`)                                                | No deletion records or revisions in the model                                                                                                                |
| Visual Library Home                                     | Done (`8f1e10b`, `e32298f`)                                                             | Home is capture field + triage + places list in a newspaper style (screenshots in dossier §21)                                                               |
| Interactive first-run guide, replayable                 | Done (code + widget tests; not run on a device)                                         | `lib/welcome/`, contract `ONBOARDING_FLOW.md`; real first save kept; replay in Settings → Help                                                               |
| Image share (Android/iOS)                               | Android: code only (APK compiles); iOS: Blocked (no Mac)                                | Commit `6541a15`; iOS extension still text/URL only                                                                                                          |
| Search links and images together                        | Done (`8f1e10b`)                                                                        | Search covers link fields only                                                                                                                               |
| Collections with covers, per-collection view and sort   | Done (`8f1e10b`, `2967121`)                                                             | Cards/rows toggle is global; no covers                                                                                                                       |
| Focus swipe deck                                        | Done (`7b07248`)                                                                        | Focus exists with buttons; no swipe deck                                                                                                                     |
| Raindrop import                                         | Done (`720bac4`)                                                                        | Pocket only                                                                                                                                                  |
| Gentle revisit reminder                                 | Code + planning tests (`42d262e`); not fired on a device                                | Per-link reminders only                                                                                                                                      |
| Share a collection (HTML / package)                     | Done (`79e9870`)                                                                        | Select all here → export selected exists; no designed collection page                                                                                        |
| Cloud sync                                              | Protocol done (simulated); folder sync on computers (`e3a1933`); phone adapters blocked | Blocked natively on Google OAuth client, iCloud container, Mac/Xcode and two devices                                                                         |
| Tuckii real-app observation                             | Observed from owner's iOS recording                                                     | `TUCKII_OBSERVATION.md` (first run only; not driven by me; Android not seen)                                                                                 |

Each row is updated as slices land; the full per-feature status is in
`FEATURE_QA_MATRIX.md`; what changed and what is next in `CHANGES_AND_NEXT_STEPS.md`.
