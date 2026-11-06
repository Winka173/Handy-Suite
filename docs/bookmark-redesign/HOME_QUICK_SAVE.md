# Handy Bookmark — Home & Quick Save (2026-11-06)

Implements the "Final Home & User-Flow Implementation Supplement". Evidence labels:
**host golden** = Flutter widget render on Windows (`tool/screens_test.dart`);
**emulator** = BlueStacks 127.0.0.1:5555, Android, debug APK. Nothing here was run on a
physical device or on iOS.

## Conflict resolution

The final simplification prompt said "remove the inline URL editor from Home; one Save →
sheet". This supplement is newer and owner-approved, so it wins on that one point:

- Home now has a single-line Quick Save field with one adjacent Save control.
- The + sheet no longer repeats the link form.

Everything else from the simplification prompt stays: no duplicate Save CTAs, no extra Home
chips, sparse settings, Saved Searches not offered for creation.

## Design contract (frontend-ui-engineering)

|                   |                                                                                                                                                                                                                                                                                                                   |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Job               | Save a link in one step; see at a glance what waits, where things are, what just came in.                                                                                                                                                                                                                         |
| One question      | "Where do I put this / where is it?" Finding: the collections.                                                                                                                                                                                                                                                    |
| Primary action    | Quick Save row: field + one adjacent control.                                                                                                                                                                                                                                                                     |
| Order (phone)     | Header (name, Search, Settings) → count line → Quick Save → Focus card → Collections (2 columns, ≤ 6 top-level, See all, New) → Recently saved (≤ 4, See all).                                                                                                                                                    |
| States            | Empty (one friendly card, quiet "Save a picture" / "See how saving works"; no second Save button), saving ("Saving…", input read-only), problem (inline red line, text kept), saved (field cleared, snackbar with View + Undo), duplicate (existing Already-saved sheet), Focus zero (one calm line, no badge).   |
| Responsive        | 320–430 px: the same order, and Home scrolls. ≥ 700 px: the multi-pane shell is kept, with the same Quick Save row in its header. Below 360 px the Focus card shows one face instead of three. The 26–28 pt name stays in the app bar, and the count line sits in the body so large text never overflows the bar. |
| Rejected patterns | A second giant link form in the sheet; a + for "new collection" next to the Save + (it is now a folder icon); a full feed on Home; four new tabs; a Pro tile on Home; red unread badges.                                                                                                                          |

**Signature element:** the + that becomes "Save" the moment the field has text. One control, and its label always says what it will do.

## Behaviour

- **Field.** Single line, URL keyboard, maxLength 4096, Done submits.
  - Empty, the suffix button is Paste (it reads the clipboard once and never re-offers the same text). With text, the suffix is Clear.
  - Input is checked before anything is written:
    - no URL: "No link in this text. Links start with http:// or https://";
    - another scheme (`javascript:`, `ftp:`…): "Only web links (http or https) can be saved."
  - The text is kept on every problem and on a failed write.
- **Adjacent control.** Empty, it is `+` (key `save-new`) and opens the sheet: Save a picture, Several links at once, Save from other apps with Share. With text, it is a filled **Save** button (key `bookmark-inline-save`). It is never ambiguous.
- **Saving.**
  - It goes through `saveCapturedLinks`, so normalisation, canonical duplicate checks and the Already-saved sheet are unchanged. Duplicates are never added silently.
  - It saves locally first and never waits for metadata or network; fetching stays asynchronous.
  - Rapid taps and Enter presses are ignored while busy. A widget test presses Done twice and checks that one row is written.
- **After save.**
  - The field is cleared and a snackbar says "Saved to Not sorted." with **View** and **Undo**.
  - Undo moves only the newly created items to Trash, so it is restorable. Undo is not offered when nothing new was created ("Already saved.").
  - `collectionId` is supported for a future in-collection entry point.
  - Pro Auto organize still runs afterwards through the app hook, and it never moves a filed save.
- **Search.** The Home search bar became a Search icon that opens `/find`:
  - all items, with the search field focused;
  - Links/Pictures chips, filters, sort and layouts as before;
  - leaving clears the words and filters.
  - Ctrl/⌘ F opens it on phones; wide screens keep the inline search.
- **Navigation.**
  - Collections' See all (key `home-library`) opens the Library hub of places, collections, tags and Trash. It is shown even when there are no collections, so the Library is always one tap away.
  - Recently saved's See all opens `/place/all`.
  - The Focus card opens Focus; the header icons open Search and Settings.
- **Default library name.** It is now "My library" / "Thư viện của tôi". A name the person set is kept.
- **Bug found and fixed.** The empty-collection cover's "Nothing here yet" overflowed by 22 px at 360 px and 1.6× text. Covers now render above the fold, which exposed it.

## Files

- New:
  - `lib/home/quick_save.dart`
  - `lib/home/home_sections.dart` (FocusNudge, RecentlySaved)
  - `lib/library/find_page.dart`
  - `test/home_launchpad_test.dart`
- Changed:
  - Home: `lib/home/home_page.dart`, `collection_covers.dart`, `empty_library.dart`, `save_sheet.dart`, `dateline.dart`, `triage_strip.dart` (`PutIn` is public with a compact form)
  - Shell and saving: `lib/shell/save_shell.dart`, `lib/bookmark/add_link.dart` (`collectionId`, `onSavedItems`), `lib/app.dart` (`/find`)
- Deleted: `lib/home/link_capture.dart`. The sheet's link form is replaced by the Home field.
- Tests updated for the new flow:
  - `a11y_test`, `home_test`, `library_name_test`, `save_sheet_test`, `inline_capture_test`, `widget_test`
  - shot scripts: `tool/screens_test.dart`, `tool/screens_library_test.dart`
  - device tours: `integration_test/tour_test.dart`, `native_test.dart`

## Results

| Command                                                          | Result                                                                                      |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `flutter analyze` (app)                                          | No issues                                                                                   |
| `flutter test --no-pub` (app)                                    | 218 passed (215 existing, 3 new)                                                            |
| `flutter test --no-pub` (engine)                                 | 129 passed                                                                                  |
| `flutter build apk --debug`                                      | Built                                                                                       |
| BlueStacks: launch, Quick Save by keyboard Enter, same URL again | Saved instantly with View/Undo. The duplicate opened "Already saved", text kept. (emulator) |

Shots: `home-shots/home-before-after.jpg` and `home-shots/quick-save-flow.jpg`. Each panel is labelled host golden or emulator.

## Acceptance checklist

| Scenario                                                                                            | Status                                                                                                          |
| --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Empty Home has one clear Save; no fake data                                                         | Widget test + host golden                                                                                       |
| URL paste + keyboard save; + opens the picture flow; failure keeps input; duplicate not silent      | Widget tests; emulator for keyboard and duplicate                                                               |
| Local save without network or metadata                                                              | By design and covered by the existing controller tests. Airplane mode was not re-run on the emulator this round |
| Recently saved shows ≤ 4, newest first, no archived/trashed                                         | Widget test                                                                                                     |
| Focus count real; zero state is one calm line                                                       | Widget tests                                                                                                    |
| Search opens focused; Links/Pictures in Search                                                      | Widget tests                                                                                                    |
| Collection covers: image, typeset fallback, empty folder, long Vietnamese name, 320 px / 200 % text | a11y and overflow tests + host goldens                                                                          |
| 320/360/390 px, light/dark, EN/VI, 1.6–2× text                                                      | Tests + host goldens; 430 px and tablet were rendered but not reviewed in detail                                |
| Share-in cold/warm, images                                                                          | Unchanged by this work. Previously exercised on the emulator (2026-11-06); not re-run                           |
| iOS share extension, TalkBack/VoiceOver by hand, physical devices                                   | **Not verified**                                                                                                |

## Remaining blockers

- **P0 (release):**
  - Store IAP is not configured. Pro purchase and restore cannot be tested.
  - There is no physical-device or iOS run.
- **P1:**
  - Cloud sync is the folder backup, not provider two-way sync. It must not be labelled "Cloud Sync".
  - Android share lifecycle cases (content-URI revocation, large payloads) have not been re-run since the share-shortcut change.
- **P2:**
  - Tablet Home reuses the multi-pane library shell rather than a launchpad.
  - Pro scope still open: Reader highlights and notes, Deep Search, offline OCR (tracked in the Pro report).
