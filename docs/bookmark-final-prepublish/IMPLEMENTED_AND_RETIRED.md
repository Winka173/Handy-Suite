# Implemented and retired (final simplification pass, 2026-11-06)

This pass builds on commit 9c4ea6c. No stored data was deleted: every retired path below still
reads, keeps and backs up its old records.

## Removed or retired from the everyday UI

| What | Now | Legacy data |
| ---- | --- | ----------- |
| Places list on the phone home (Not sorted, All, Favourites, Unread, Archive, Broken, Recently Deleted, Tags) | Moved to a new Library page (`/library`, `lib/library/library_page.dart`). The home keeps two doors: Library and Focus. | Unchanged |
| Dateline on the home | Removed (`HomeDateline`). `libraryName()` stays. | — |
| Saved-search creation (`save-search-here`, "+") | Removed | Existing saved searches open, rename and delete under Library › Advanced and under Settings › Advanced library tools |
| Smart collections on home and in onboarding | Removed. Create and edit only under Advanced; the Pro gate is kept. | Rules kept |
| Pin | No control creates a pin. Items already pinned show one "Unpin" in Details and tools and in the editor. | Flags, ordering and serialisation unchanged |
| Per-item reminder creation ("Remind me") | Removed. Settings › Reminders › Existing reminders lists those still set, with Cancel each and Cancel all (asks first; Undo). | `reminderAt` kept; cancelling withdraws the OS notification |
| Remind and Copy link in the detail's quick actions | Removed. The quick actions are Favourite, Move, Rename, Share; Copy link and Open in browser moved to the "…" menu. | — |
| Notification step in onboarding | Removed. The guide is three stages; the weekly nudge is only in Settings, off by default. | — |
| "Open links with" (app, browser, system) | One setting in Settings › Help & about › Advanced library tools, default Device | Preference kept |
| Export formats (JSON, CSV, HTML, MD, TXT), Pocket and Raindrop | Settings › Data & sync › Advanced export and import. Plain Back up / Restore / Import sit above. | — |
| Colour and icon pickers in the collection editor (the app never displayed them) | Removed. The editor is Name, optional "Inside" parent, and note. | Stored values kept |
| Order group in the filter sheet | Moved to one sort menu (default "Newest first", per collection) | — |

## New

- **Rename** (`lib/bookmark/rename.dart`):
  - for links and pictures, from the detail or any item's "…" menu;
  - sets `metadataSource: 'user'`, so later page-detail refreshes keep the name; the URL, media SHA and ids are untouched;
  - Undo after saving; a failed save keeps the sheet open with the error.
- **Share** (`lib/bookmark/share_item.dart`, plus the additive `LocalShare.text` in `packages/handy_files/lib/share.dart`):
  - links share title plus a clean address (tracking parameters and credentials removed), never notes;
  - pictures with EXIF/XMP/IPTC default to "Share without location" (re-encoded, upright, no camera data), with "Share original file" as the alternative;
  - a preview-only picture or a missing one says so;
  - the copy fallback is never reported as a share.
- **Item menu** (`lib/bookmark/item_menu.dart`): "…" on cards and rows with Open details, Rename, Share, Move, Delete.
- **Reader** (`lib/reader/*`):
  - reads online on explicit open when there is no offline copy (same safe fetch: public IPs, 3 MB, 20 s, no cookies), with Cancel, failure reasons, and Open original;
  - a strip says "Reading online" or "Offline copy", and Save offline stores the text already read;
  - Find in article: count, next and previous, keyboard shortcuts, accent-insensitive;
  - reading position per item and text version, on this device only.
- **Library page and Advanced disclosure**; **cover choice** from a collection's own pictures (`lib/collections/cover_chooser.dart`, stored as `collectionViews[id].cover`, falls back to automatic); **sort menu**.
- **Settings in four groups** (`lib/settings/save_settings.dart`, `settings_parts.dart`, `reminders_section.dart`, `library_tools.dart`): Appearance / Reminders / Data & sync / Help & about. One-tap Back up records a manual backup report.
- **Focus poster** for items without a picture (`lib/focus/focus_card.dart`): the source colour, a serif title at the largest size that fits, and the meta line.
- **Onboarding in three stages**: the story (two beats: scattered, then gathered), the practice save, finding it.
- **Data (engine and stores):**
  - backups carry offline copies of items in Recently Deleted;
  - `cover` is kept and remapped in backups;
  - housekeeping (`SaveController.tidy`) runs at open and before automatic backups, covering Trash expiry, tombstones older than 365 days and unused pictures;
  - `removeCollection` handles unfile, move or trash, with subcollections moving up;
  - a damaged collection tree is repaired on load.
- **Android release build fixed**: a release-only no-op `IntegrationTestPlugin` stand-in (`android/app/src/release/java/...`).

## Deliberately not done in this pass

- Reader extras: TTS, highlights and annotations, and article image download.
- OCR, AI features, a social downloader, a browser extension.
- Manual drag ordering.
- iCloud and Google Drive sync (see `NATIVE_RELEASE_MATRIX.md`).
