# Handy Bookmark: Warm Modern Library redesign (report, 2026-11-06)

This report covers the "Warm Modern Library" supplement:
- the visual and UX redesign of everything after the first-run guide;
- the data fixes that the supplement listed.

The base was `60e251f`. The design contract is `VISUAL_DESIGN.md`. All evidence below comes from
host widget tests and host-rendered screenshots, plus a BlueStacks (Android 11) install. Nothing
here was checked on a physical phone or on iOS.

## What changed, and why

**Foundation**

| Path | Change |
| ---- | ------ |
| `packages/handy_ui/lib/kit/app.dart` | `HandyApp(themeOverride:)`: an optional hook so one app can finish the kit theme. Other apps pass nothing and are unchanged. |
| `apps/handy_bookmark/lib/design/theme.dart` (new) | `BookmarkPalette` (separate light and dark), `BookmarkRadii`, `bookmarkSerif`, `bookmarkTheme`. Buttons, fields, chips, sheets, dialogs, menus, snack bars, switches and the dark theme are all app-owned. |
| `lib/design/identity.dart` | Brand: soft corners, edgeless surfaces, ivory or charcoal ground, sans-serif section heads, rows grouped on cards. |
| `lib/app.dart` | Applies the theme. Ads are always off (`adsVisible` is false). Turning every reminder off now cancels pending notifications. |
| `lib/ui/visual.dart` (new) | `ItemPicture` (preview only, with a source face as fallback), `SourceFace`, `SectionHead`. |

**Library screens (P0)**
- `lib/home/home_page.dart`: serif library name, pill search, order shelf → collections → places.
- `lib/home/triage_strip.dart`: the "Recently saved" shelf. Unsorted saves come first, each with one "Put in…" sheet.
- `lib/home/empty_library.dart` (new): empty library with the guide's photos and the guide link.
- `lib/home/collection_covers.dart`: 20 px covers; an empty collection shows its colour and a folder.
- `lib/library/link_card.dart`: gallery card with a 1.28 photo, two-line title, source and a "…" button.
- `lib/library/bookmark_tile.dart`: 60 px thumbnails, sans-serif titles.
- `lib/library/results_view.dart`: collection hero; two columns at 390 px and one at 320 px or large text; "n found" for searches; tools wrap on phones.
- `place_title.dart`: "Everything / Tất cả mục" (it holds pictures too).
- `lib/shell/save_shell.dart`, `search_box.dart`: wide layout with no vertical rules and the open item on a raised sheet; pill search, "Search your library".

**Detail, viewer and Focus (P0/P1)**
- `lib/bookmark/detail_view.dart`, `detail_facts.dart`, `detail_links.dart`:
  - picture as the hero;
  - one primary action: Open original, or View picture;
  - round actions: Favourite, Move, Remind me, Copy link;
  - pin, read, archive, offline copy, link check, address, file facts and Recall folded under "Details and tools".
- `lib/bookmark/picture_view.dart`:
  - fixes the dark title on black (light title, file line and icons in both themes, light status bar);
  - says when only a preview is on the device; separate missing and broken states; Esc closes.
- `lib/focus/focus_card.dart`, `focus_page.dart`:
  - 22 px card with a picture;
  - tilt and lift with a live Read or Later label, 220 ms throw, 180 ms settle;
  - round labelled buttons; reduced motion keeps travel small with no tilt; done state.

**Save, dialogs, Trash, Settings (P0/P1)**
- `lib/home/save_sheet.dart`, `link_capture.dart`, `lib/bookmark/add_link.dart`:
  - save sheet with a roomy field, a visible Paste and a 50 px Save;
  - "Several links" and "A picture" tiles;
  - input kept on errors.
- `lib/library/trash_page.dart`:
  - cards with days left and a prominent Restore;
  - "Delete forever" set apart; "Empty Recently Deleted" confirmed.
- `lib/settings/save_settings.dart`, `data_section.dart`, `storage_summary.dart`, `duplicates_page.dart`:
  - groups Personalise / Reminders / Your data / Help and advanced; reset last;
  - truthful privacy copy;
  - the last automatic backup's completeness;
  - storage split into pictures, previews, offline copies and Recently Deleted.
- `lib/sync/sync_section.dart`: "Sync through a folder": manual, computers only, never shown as connected.
- `lib/collections/share_collection.dart`, `collection_actions.dart`, `lib/library/filter_sheet.dart`, `batch_bar.dart`, `lib/editors.dart`: sheets instead of cramped dialogs, notes off by default, "mục" wording.

**Data correctness (section 5 of the supplement)**
- `packages/handy_bookmark_engine/lib/src/portable.dart`:
  - backups carry `collectionViews`, with old backups still restoring;
  - an omission report (`BackupOmission`, `BackupReport`; `complete` only with nothing left out);
  - same-named collections on a repeated import (`sameNamedCollections`, `reuseCollections`).
- `lib/controller.dart`: `readingCopiesForBackup`, `lastBackup`, `recordBackup`.
- `lib/data/import_export.dart`:
  - the automatic backup records its report;
  - views are exported and restored;
  - the import preview offers "Add to my collections with the same name", off by default.

**Tests added**
- `test/data_safety_test.dart` (3);
- `test/save_sheet_test.dart` (8);
- `test/detail_focus_ui_test.dart` (7);
- engine `test/backup_report_test.dart` (22).

Tests updated for the "Put in…" button, the folded detail tools and the new empty-state headline.

**Shots**
- `tool/screens_library_test.dart` (new): library shots at 320, 390, 900 and 1440 px, light and dark, and at 200 % text.
- `tool/screens_test.dart`: new blocks for settings, save, trash, share, filters, detail, viewer and Focus.
- `tool/contact_sheet.py` (new): joins shots into one sheet.

## Status by section

| Section | Status | Notes |
| ------- | ------ | ----- |
| A. Home | Done | Recently-saved shelf, covers, empty state, one Save. The shelf mixes links and pictures. |
| B. Results, collection, gallery and list | Done | Each collection's view and sort is remembered, and backups now carry it too. Sort is unchanged. |
| C. Detail, picture viewer | Done, one part open | **Share is not built**: `handy_files` only shares files, and sharing an original picture would carry its location data, which needs your decision. Copy link stands in for now. |
| D. Focus | Done | The deck behind the top card is very faint in dark. |
| E. Save, import, share, dialogs | Mostly done | The Pocket/Raindrop preview and the bounded batch review are still centred dialogs (`data/import_export.dart`, `links/batch_size.dart`). They are readable at 320 px but not restyled. |
| F. Trash, reader, duplicates, tools | Trash and duplicates done | The reader picks up the new theme (shots `phone-11/12-reader`) but its layout was not reworked. |
| G. Settings | Done | Previews and offline copies have no byte size: the store has no size API. |
| H. Dark theme | Done for the screens shot | Warm charcoal, never pure black (black is kept only in the picture viewer). |
| I. Tablet and desktop | Done | 900 and 1440 px home, light and dark. A collection at 900 px was not shot. |
| J. Onboarding | Preserved | Unchanged; welcome tests and shots pass. |

## Verification

| Check | Result |
| ----- | ------ |
| `flutter analyze` (app, `lib` + `test` + `tool`) | no issues |
| `flutter test --no-pub` (app) | 158 passed, 0 failed (140 before) |
| `flutter test --no-pub` (engine) | 99 passed (77 before) |
| `flutter test --no-pub` (`handy_ui`) | 10 passed; `flutter analyze lib` clean |
| `flutter build apk --debug` | built; installed on BlueStacks (Android 11) |
| Screenshots | 89 after (`shots/after/`), 47 before (`shots/before/`); contact sheets `shots/ba-*.jpg`, `shots/after-*.jpg` |

**Shot matrix.** Rendered and opened:
- Home: 320, 390, 900 and 1440 px, light and dark; 200 % text; empty (light).
- Collection, list and gallery: 320 px light and dark; 390 px light; 200 % text.
- Search with matches and with none (light).
- Detail: light and dark. Picture detail and viewer: light and dark.
- Focus: light and dark.
- Save sheet: 390 px light and dark; 320 px with an error.
- Trash: active, dark and empty.
- Settings: phone light and dark; desktop.
- Share collection, filters, duplicates, Pocket preview, batch review.
- Guide: 320, 390 and 1280 px.

**Not shot** (left unverified rather than claimed):
- empty home in dark;
- a collection at 900 px;
- search in dark, with the Links or Pictures filter, or over 100 results;
- detail with a broken thumbnail (covered by a widget test);
- a Focus drag mid-gesture;
- guide in dark (the guide always draws on paper).

The fixture library has 11 saves, not 20. Its pictures are the guide's licensed photos (see
`apps/handy_bookmark/assets/welcome/CREDITS.txt`), used as fixtures, not the person's content. The
saves without a picture show the source face.

## Remaining risks

- **Native, not verified on devices:**
  - Android sharing shortcuts beyond BlueStacks;
  - Android image share;
  - iOS share extension and HEIC (iOS is not compiled);
  - notification lifecycle on a real phone;
  - memory with large libraries.
- **Sync:** manual folder sync only, on computers. No native iCloud or Google Drive sync exists,
  and the UI says so.
- **Backups:**
  - the automatic backup now reports what it left out, but offline copies of items in Recently
    Deleted are neither backed up nor counted;
  - fetched page thumbnails are a cache and are not backed up (documented).
- **Release:** the release APK build still fails (the integration_test plugin registrant), as before
  this work.

## Release copy (only what is built and checked on the host)

> Handy Bookmark now looks like a library of your own: your pictures large, warm colours, soft
> corners, and a calm dark mode. What you saved lately sits at the top, and anything without a
> collection has one "Put in…" button. Every item opens with one clear action (Open original or
> View picture), and everything else is one tap away under Details and tools. Backups now keep
> how each collection is shown, and tell you if anything was left out. Turning reminders off now
> clears ones already scheduled.
