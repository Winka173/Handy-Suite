# Handy Boards feature matrix

Updated 2026-11-07 for the Kanban-first rebuild (owner brief:
`docs/HANDY_BOARDS_KANBAN_SPEC.md`, contract: `docs/UX_REDESIGN.md` › "Hợp đồng: Handy
Boards · Kanban"). IMPLEMENTED is code; AUTOMATED_TESTED names host tests; nothing here is
device- or store-verified unless it says so.

| Area | State | Evidence and scope |
| --- | --- | --- |
| Model: Board → Columns (statuses) → Cards (top-level tasks) → one-level Subtasks (checklist); Categories independent of columns | AUTOMATED_TESTED | `packages/handy_boards_engine/lib/src/kanban.dart`, `test/kanban_test.dart` (moving to Done keeps category and subtasks; ticking never moves a card) |
| Migration of older data | AUTOMATED_TESTED | `kanbanize`: nested tasks become subtasks of their card and the old task is archived with `mergedInto` (nothing lost); runs once per start. Backup/store schema 3, reads 1–3 |
| Home (my boards): covers, real figures, pinned first, due-today/overdue line | AUTOMATED_TESTED host UI | `lib/home/`, `test/kanban_app_test.dart` |
| Create board: blank (To Do / Doing / Done) or template with full Kanban preview | AUTOMATED_TESTED | `lib/create/templates.dart`; preview renders the real `KanbanView` from a throwaway state |
| Templates | AUTOMATED_TESTED | 10 presets (5 free: blank, study, personal, shopping, project; 5 Pro: content, goals, event, moodboard, renovation), EN/VI, fresh ids, no cross-board references (`presets.dart`, `presets_test.dart`) |
| Board canvas (Kanban) | AUTOMATED_TESTED host UI; drag PLATFORM_VERIFIED on BlueStacks (Android emulator, 1920×1080, 2026-11-07: long-press drag To Do → Doing → Done, category kept) | One near-full-width column per page on phones (snap, next edge visible), 300 px columns on wide screens; drag within/between columns (long-press on touch, immediate with a mouse), edge auto-scroll, drop slots, Undo snackbar; Move to… sheet and Alt+arrows as drag-free alternatives; quick add at the column foot |
| Category strip (overview + filter) | AUTOMATED_TESTED host UI | Every category with done/total across all columns and a thin bar; 2×2 on phones (≤4), scrolls otherwise; tap filters; edit sheet adds/renames/recolours/reorders; deleting moves cards to Uncategorised or a chosen category |
| Card detail | AUTOMATED_TESTED host UI | Title, column, category, due, reminder (permission asked on first use), subtasks (add, edit, tick, reorder, remove, progress), notes with link chips, duplicate/archive/trash; every change saved with Undo |
| Covers | AUTOMATED_TESTED | 60 original procedural covers in 10 families (30 free, 30 Pro), 0 raster bytes (`docs/HANDY_BOARDS_ASSETS.md`); picker with Suggested/All/family/Colour/Your photo, live preview, Apply/Cancel; photo covers are attachments in app storage |
| Columns and boards | AUTOMATED_TESTED engine | Add/rename/reorder/mark finished/delete column (cards must go somewhere); duplicate, pin, archive, delete board (confirmed, Undo) |
| Time view | AUTOMATED_TESTED host UI | "Board | Time" per board: cards by due day (≤ 14 days) or by week (longer); spans Today, 3 days, Week, 2 weeks, Month, 3 months or custom 1–12 days/weeks/months, remembered per board; Overdue first, No due date tray; drop on a day sets the due day (Undo); opens on today. Not a Gantt (no bars, no times) |
| Search and filters | IMPLEMENTED | Board search, category filter, "due in 3 days"; search across boards |
| Onboarding | AUTOMATED_TESTED host UI | Tour on a temporary board (never saved): add a card, move it, category stays when finished; makes a study or blank board, or skip; replay from Settings |
| Settings | IMPLEMENTED | Bookmark-style groups: look, reminders, Pro + automations, data (backup/restore, archived boards, trash), help, more apps |
| Pro Lifetime | IMPLEMENTED, store UNVERIFIED | Gate only on Use/Apply/turn on; previews free. Pro: 5 templates, 30 covers, 5 board looks, automations (finish a card when all subtasks are done; archive finished after 14 days, restorable; repeating cards), designed exports, board insights. No Boards product id is configured yet, so the purchase panel says purchases are not set up |
| Repeating cards (Pro) | AUTOMATED_TESTED | Daily/weekly/monthly; entering a finished column makes the next card once (top of the first column, subtasks unticked, due one period later, month ends clamped); moving back and forth never multiplies it |
| Board looks (Pro) | AUTOMATED_TESTED host UI | Pinboard (free) + Linen, Blueprint, Meadow, Blush, Sand, light and dark; tried live on the board, Apply/Cancel; only page and column grounds change |
| Export | AUTOMATED_TESTED host UI | Preview page draws the board as it will be saved: Plain (free), Poster and Printable (Pro, previewable); PNG at 2× or PDF of the same picture. Data formats (backup ZIP/JSON, CSV, Markdown, ICS) stay free one tap away |
| Ads | Removed | Boards no longer depends on `handy_ads` |
| App icon | IMPLEMENTED | New original Kanban mark on `#A61C8E` (Android adaptive + monochrome, iOS, web, Windows) |
| Removed | — | Table, calendar, timeline, planner, study module, focus timer, saved views, rule builder, custom-field editors (data still round-trips in backups) |

Review shots: `SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart` (welcome,
home, board, filter, card, cover picker, templates, Pro, settings; 390 px, 320 px at 200 %
text, 1280 px light and dark). Cover sheets: `tool/covers_test.dart`.
