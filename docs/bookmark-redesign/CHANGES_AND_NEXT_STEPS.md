# Handy Bookmark redesign: changes and next steps

Branch `ui-rebuild`. The redesign starts at baseline `eb25235` and runs through `4744541` and
the docs commit after it.

## What a person can do now

- **Keep anything, not only links.**
  - Screenshots and photos are items of their own: Save → A picture, or share them from
    Android's gallery (code only).
  - Pictures are the person's data. Originals are kept byte for byte and backed up; previews
    carry no camera, place or time data.
  - A picture chosen for a link is theirs too, with a way back to the page's own picture.
- **Find it again.**
  - One search box for links and pictures, accents ignored, with All / Links / Pictures.
  - Collections show as covers made from what is inside them.
  - The home names the library and opens with a dateline of what waits to be sorted.
- **Learn it in a minute.** A four-step first run ends with a real first save that stays.
  It can be replayed from Settings.
- **Get through the backlog.**
  - Focus is a deck to swipe: right when done, left for later. Undo, keys and buttons all work.
  - An opt-in weekly nudge counts new unread saves and never shows titles.
- **Undo a delete for 30 days.** Recently Deleted holds deleted items and their pictures.
  Deleting for good leaves a tombstone, so sync cannot bring the item back.
- **Move in and share out.**
  - Import from Pocket (existing) and now Raindrop.io: folders, tags, notes, favourites.
  - Share a collection as one page anyone can open.
  - Backups as JSON or ZIP, the ZIP with pictures.
- **Keep devices in step.** On computers, sync works through a folder a cloud client keeps in
  step. The protocol handles edits, deletions, pictures and concurrent writes.
- **No ads, no account, no subscription.** Pro stays an optional one-time purchase.
- **Each collection remembers** cards or rows and its order. Settings shows what the library
  takes on the device.

## Before and after

| Area         | Before (baseline)                                                                            | After                                                                                                    |
| ------------ | -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| Home (phone) | Inline link field, search, Not sorted strip, place list; three add buttons in the bottom bar | Dateline, search with kind chips, Not sorted strip, collection covers, places; one Save button and sheet |
| First run    | An empty-state hint                                                                          | Four-step guide with a real first save; replay in Settings                                               |
| Pictures     | Only fetched page thumbnails (cache)                                                         | Picture items and owned pictures; backups carry them                                                     |
| Delete       | Confirm, then gone (one-step Undo)                                                           | Recently Deleted for 30 days; tombstones                                                                 |
| Focus        | One link with buttons                                                                        | Swipe deck with Undo, keys and buttons                                                                   |
| Ads          | AdMob banner via the shared kit                                                              | None; the SDK lives in `handy_ads`, which only ad-supported apps install                                 |
| Sync         | None                                                                                         | Engine protocol plus folder sync on computers                                                            |

Screens: `VISUAL_DESIGN.md`, `ONBOARDING_FLOW.md`, and the shots listed in
`evidence/tests-and-builds-2026-11-06.md`.

## Data and migration risks

- **Stores moved to schema 4** (SQLite) and IndexedDB 4, with a 1→4 ladder tested from v1 and
  v2 fixtures.
  - Old data names are unchanged on purpose: `handy-save.sqlite`, `handy-save-*`.
  - An app downgrade cannot read v4. Restore from a backup in that case.
- **Portable format 3** is written only when a library uses its additions. Otherwise it is
  written as 2, which older versions still read.
- **Sync uses device clocks.** A device with a badly wrong clock can win or lose edits.
  Tombstones older than 365 days are pruned; a device silent that long should restore from a
  backup.
- **Pictures stored before 2026-11-06** may keep EXIF in their previews. Shared pages re-encode
  every picture, so nothing leaves with metadata, but old previews stay on the device until
  regenerated.
- **Repeated imports duplicate folders.** A second Raindrop or Pocket import adds new
  collections even when ones with the same name exist; links are deduplicated.

Details: `DATA_MIGRATION_AND_BACKUP.md`, `SYNC_ARCHITECTURE_AND_TESTS.md`.

## Next tasks

1. **Run on real devices:**
   - Android share of one and several gallery pictures;
   - the first run end to end;
   - Focus swipes;
   - the weekly nudge firing;
   - sharing a collection page through the system sheet.
     Record evidence only from those runs.
2. **iOS:** build the share extension changes in Xcode on a Mac and try them on an iPhone.
3. **Phone sync:**
   - an iCloud Drive container adapter (Apple developer account, Mac);
   - a Google Drive `appDataFolder` adapter (Google Cloud OAuth client);
   - then two-device proof.
4. Automatic sync on start, on resume and after changes, with the last error in Settings.
5. When importing again, match imported folders to existing collections by name and parent.
6. Regenerate previews made before the EXIF fix on next launch.
7. Store setup for the Lifetime purchase (`docs/STORE_SETUP.md`). Package ids are still
   `com.example.*`.

## External prerequisites

- An Android phone (or an emulator with Google Play) for share-sheet and notification runs.
- A Mac with Xcode, an Apple developer account and an iCloud container for iOS builds and
  iCloud sync.
- A Google Cloud project with an OAuth client for Drive sync.
- Store listings and signing (never committed).
