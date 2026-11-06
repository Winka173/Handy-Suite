# Handy Bookmark Pro Lifetime: implementation report (2026-11-06)

Scope: the "Pro Lifetime, Premium Studio & Conversion UX" prompt. The checklist in machine-readable form is in [pro-checklist.json](pro-checklist.json).

**Evidence labels:**

- **unit**: engine tests.
- **widget**: Flutter widget tests.
- **host golden**: renders made on Windows by `tool/screens_test.dart`.
- **emulator**: BlueStacks, Android, debug APK.

**Not verified at all:** physical devices, iOS, and real store purchases.

## Policy, as built

- **One gate.** `hasPro(context)` is true only when the store reports a verified purchase (`LifetimeScope.pro`). `requirePro(context, feature)` opens Explore Pro at that feature and reports whether Pro became verified. There is no fake unlock. `debugProOverride` exists for tests only (`@visibleForTesting`).
- **Previews are real.** Every catalogue previews the person's own library with the same renderer as the result. A Pro choice previewed on Free never changes saved settings. If Pro lapses, the choice waits: the app shows the free look but keeps the stored preference.
- **Free stays whole.** Saving, collections, tags, ordinary Search, Gallery/List, Focus, the basic Reader, offline copies, Share, Rename, Trash, import/backup/restore and the basic page share are never gated.
- **No ads.** `HandyApp(adsVisible: ValueNotifier(false))`. There is no ad widget in Bookmark.
- **No invented prices.** The price shows only when the store returns one. Explore Pro lists only the shipped features (`shippedProFeatures`).

## Features

| ID (`ProFeature`)  | What ships                                                                                                                                                                                                                                                           | Where                                                                  | Evidence                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `premiumThemes`    | 10 premium looks: ink-paper, midnight-gallery, forest-archive, sakura-notes, ocean-glass, terracotta-studio, monochrome, retro-film, lavender-haze, solar-citrus. The free look is `library`.                                                                        | Settings › Themes (`/looks`); live phone preview of the real Home      | unit (ids, contrast), widget, host golden                                      |
| `premiumLayouts`   | 8 collection layouts: magazine, masonry, filmstrip, scrapbook, lookbook, board, timeline, moodboard. Gallery and List stay free.                                                                                                                                     | Collection › layout picker; live preview on the collection's own items | widget (320 px at 2× text, 390 px), host golden                                |
| `focusSkins`       | 4 Focus skins: minimal, film, editorial, nocturne                                                                                                                                                                                                                    | Focus › skins                                                          | widget, host golden                                                            |
| `premiumExport`    | Export Studio: 8 designs (catalog, travel, recipes, bibliography, magazine, wishlist, moodboard, print) × PDF and HTML = 16 outputs. The preview is the real PDF's pages. Quick share stays free.                                                                    | Collection menu › Export (`/export/<id>`)                              | widget, real PDFs rasterised with PyMuPDF, HTML in Edge; samples in `samples/` |
| `smartCollections` | Rule-based collections                                                                                                                                                                                                                                               | Library                                                                | widget                                                                         |
| `autoOrganize`     | 4 presets (videos, shopping, development, pictures), each with a chosen collection and an optional tag; a dry run; apply with Undo; opt-in automation for new saves with a log and per-entry Undo. Never moves a save the person already filed.                      | `/organize`, Explore Pro                                               | unit, widget                                                                   |
| `advancedBulk`     | Selection actions: Organize with rules, and Clean up titles (drops site names, never touches names the person gave). Both have a dry run and Undo.                                                                                                                   | Library selection bar                                                  | unit, widget                                                                   |
| `readerHighlights` | Select text, then Highlight. 5 colours and a note. Anchored by block + offsets + quote. List, jump, edit, delete (asks first when there is a note), copy all as Markdown. Carried in backups (extra key; a merge carries them only for the items it adds, remapped). | Reader                                                                 | unit (anchor, validation, JSON/ZIP round-trip), widget, host golden            |
| `deepSearch`       | Search also finds words inside offline articles, highlights and notes, and picture text, with source chips (Inside article / In a highlight / From picture) and the real passage. Free search is unchanged; Free sees "N more … Pro" only.                           | Search (`/find`)                                                       | unit, widget, host golden                                                      |
| `ocrOffline`       | Picture viewer › Copy text. Text is read on the device (ML Kit on Android/iOS, Windows OCR) and kept with the item on this device. New pictures are read in the background after saving, older ones when Search opens. A save never waits.                           | Picture viewer, Search                                                 | widget (fake engine), emulator: the APK builds and launches with ML Kit        |

## Catalogue counts against the prompt

| Asked                | Built                              | Note                                                                                           |
| -------------------- | ---------------------------------- | ---------------------------------------------------------------------------------------------- |
| 10 themes            | 10                                 |                                                                                                |
| 8 layouts            | 8                                  |                                                                                                |
| 4 Focus skins        | 4                                  |                                                                                                |
| 12+ export templates | 8 designs, 16 outputs (PDF + HTML) | **Gap.** Four more designs need their own layouts. Recoloured clones were rejected on purpose. |

## Data safety

- Rules (`organizeRules`), automation (`organizeAuto`), its log (`organizeLog`), the chosen look/layout/skin, and picture text (`ocrText`) are device preferences.
  - Layouts per collection travel in `collectionViews`; highlights travel in backups.
  - Picture text is derived, so it is not backed up and can be read again.
- Highlights and collection views are extra keys that older versions ignore. No schema version change was needed. Malformed entries are dropped on read, never an error.

## Not verified / blockers

| Severity | Item                                                                                                                                                                              |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P0       | IAP is not configured in this build: purchase, restore and the store price have never run. The Pro paths were exercised only with the test override.                              |
| P0       | There is no iOS run. iOS OCR (ML Kit) and the store are untested.                                                                                                                 |
| P1       | Vietnamese OCR accuracy is unmeasured. ML Kit Latin reads diacritics, but quality on real screenshots and receipts has not been checked. Windows needs an installed OCR language. |
| P1       | On a device, Highlight in the selection menu has not been exercised by hand. Widget tests call the same callback.                                                                 |
| P2       | There are 8 export designs where the prompt asks for 12+.                                                                                                                         |
| P2       | Deep Search reads every offline copy when Search opens. That is fine for hundreds of items; a persistent index would be needed for many thousands.                                |

## Commits

`1d9ebf9` registry, Explore Pro, Theme Studio · `465cde4`, `15e1deb` layouts · `d517f02` Focus skins · `415dd09` Export Studio · `c78df35` Auto organize + bulk · `86c0e7c` highlights · `3dac5f0` Deep Search · `f5f8770`, `331e313` OCR.
