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

| Area                                                    | Status                                                  | Proof / note                                                                                                                                                 |
| ------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Ads removed from Bookmark (UI, init, IDs, SDK in build) | Done (`docs/bookmark-redesign/evidence/ads-removal.md`) | Was: AdMob banner via `handy_ui` → `handy_monetization` → `google_mobile_ads`; `adsVisible` in controller; AdMob meta-data in AndroidManifest and Info.plist |
| Image / screenshot items without a URL                  | Missing                                                 | `Bookmark` requires `originalUrl` (engine `models.dart`); no content kind                                                                                    |
| User-owned images as durable data                       | Missing                                                 | Custom pictures live in the thumbnail LRU cache (~20 MB) and are not backed up (dossier §16)                                                                 |
| Full backup with images                                 | Partial                                                 | JSON/ZIP carry reading copies within 30 MB; no images (dossier §18)                                                                                          |
| Recently Deleted (Trash) for items                      | Missing                                                 | Only 7-day `reading_trash` for offline copies, hidden, Undo one step (dossier §13)                                                                           |
| Tombstones / revisions for sync                         | Missing                                                 | No deletion records or revisions in the model                                                                                                                |
| Visual Library Home                                     | Partial                                                 | Home is capture field + triage + places list in a newspaper style (screenshots in dossier §21)                                                               |
| Interactive first-run guide, replayable                 | Missing                                                 | Only empty-state hint (dossier §20)                                                                                                                          |
| Image share (Android/iOS)                               | Missing                                                 | Android queue accepts text only; iOS extension text/URL only (dossier §24)                                                                                   |
| Search links and images together                        | Partial                                                 | Search covers link fields only                                                                                                                               |
| Collections with covers, per-collection view and sort   | Partial                                                 | Cards/rows toggle is global; no covers                                                                                                                       |
| Focus swipe deck                                        | Partial                                                 | Focus exists with buttons; no swipe deck                                                                                                                     |
| Raindrop import                                         | Missing                                                 | Pocket only                                                                                                                                                  |
| Gentle revisit reminder                                 | Missing                                                 | Per-link reminders only                                                                                                                                      |
| Share a collection (HTML / package)                     | Partial                                                 | Select all here → export selected exists; no designed collection page                                                                                        |
| Cloud sync                                              | Missing                                                 | Blocked natively on Google OAuth client, iCloud container, Mac/Xcode and two devices                                                                         |
| Tuckii real-app observation                             | Pending                                                 | Owner is setting up BlueStacks with Play; no AVD here has Play Store                                                                                         |

Each row is updated as slices land; the full per-feature status is in
`FEATURE_QA_MATRIX.md`.
