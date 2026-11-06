# Visual QA

Shots are host renders made with the real fonts. The before set is
`docs/bookmark-redesign/shots/after/` (commit 9c4ea6c); the after set is `shots/after/` here,
136 PNGs, git-ignored. Regenerate with:

```
SHOTS_DIR=... flutter test --no-pub tool/screens_test.dart
SHOTS_DIR=... flutter test --no-pub tool/screens_library_test.dart
```

The contact sheets `shots/core-1.jpg` and `shots/core-2.jpg` were reviewed.

**Coverage**
- Home: 390 light and dark, 320, 200 % text, empty.
- Library page and its Advanced section.
- Collection, gallery and cover chooser.
- Detail, item menu and the two folds.
- Rename: 390, and 320 in dark.
- Picture share choice.
- Reader: online, loading, failed, and find (dark, 320, 200 % text).
- Focus, including the poster in light, dark and large text.
- Trash: active, dark and empty.
- Settings: 4 groups in light and dark, 200 % text, the advanced views, existing reminders.
- Onboarding: 3 stages at 320, 390 and 1280.
- Desktop and tablet.

**Fixes made from the shots**
- Selected rows were drawn as pills overlapping the group dividers and edges. They are now flat
  bands clipped by the group card (the `listTileTheme` shape in `lib/design/theme.dart`).
- The section "+" sat higher than the section title; `SectionHead` now centres the action.
- "1 items", "1 links", "1 pictures": singular forms added.
- The empty-library button opened the several-links dialog. It now opens the same Save sheet as
  the Save button.
- Each pass also fixed:
  - the find bar wrapping too early;
  - faint secondary matches in Find;
  - a grey shadow stand-in in the menu shots;
  - the "…" leaving a gap beside one-line titles;
  - the cover grid overflowing;
  - duplicate "Websites" filter chips;
  - big gaps around the kit's settings sections;
  - switch alignment.

**Known**
- A pink source's dark Focus poster reads mauve. Contrast still passes.
- With 320 px and 200 % text, the icon beside "+ New smart collection" stays small.
