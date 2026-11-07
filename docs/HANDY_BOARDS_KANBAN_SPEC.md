# Handy Boards — Kanban-first master brief (owner, 2026-11-07)

Owner's direction on top of the brief below: the style, onboarding and Settings follow
Handy Bookmark (`apps/handy_bookmark`), while Boards keeps its own identity (hue
`#A61C8E`, Plus Jakarta Sans, indigo banned). The brief is kept as the owner wrote it.

---

HANDY BOARDS — FINAL MASTER IMPLEMENTATION PROMPT
Kanban-first · Categories · Subtasks · Template Gallery · Modern Visual System · Pro Lifetime

Mode: IMPLEMENT IN SOURCE. Priority: correct data and simple daily workflows first; then
polished visuals, templates, card covers, Pro previews and verification.

## 0. Product decision — definitive scope

Build Handy Boards as a focused, local-first Kanban board app, not a general workspace,
database builder, school-management platform, shopping app or giant task manager. The core is:

Board → Columns → Cards, with Categories independent from columns/status, one-level Subtasks
inside a Card, and ready-made Templates.

A Card can represent a single task or a compact cluster of subtasks. E.g., Board Học kỳ 1 has
To Do / Doing / Done columns and independent categories Toán / Văn / Anh / Lý; a Card Ôn tập
chương 3 belongs to category Toán, current column Doing, with a 2/5 checklist progress badge.
Marking a subtask done must NOT change its category. Categories must remain visible in a
simple Category Overview even if their cards are spread across columns.

Strict exclusions: specialized Study/Shopping Board engines, 10-view systems, advanced
calendar/timeline/Gantt, database formulas, multi-level subtask trees, team collaboration,
real-time multiplayer, chat, AI cloud calls, paid APIs, mandatory login and backend servers.

Visual direction: more modern, premium, polished and coherent than typical utilitarian
Trello/ClickUp/Notion mobile screens while simpler to use. Do not copy their trade dress, icons
or artwork. Real Flutter mobile UI.

REFERENCE HANDY BOOKMARK: inspect Handy Bookmark (Warm Modern Library redesign, Home
hierarchy, onboarding, iconography, spacing, typography, card and collection imagery, quick
actions, preview-before-purchase, clean Free/Pro presentation). It is the internal quality bar.
Reuse sound principles/components where feasible, not an identical UI: Boards has its own
recognizable modern Kanban identity.

## 1. Start with a real source audit; never rebuild from scratch

1. Inspect the current repository: screens, routing, models, persistence, migrations,
   drag-and-drop, card/category/checklist logic, theme/assets, backup/restore, monetization,
   tests. Establish what exists and what is absent.
2. Inspect Handy Bookmark and shared Handy Suite patterns; identify reusable choices without
   unwanted coupling.
3. Record the starting state (commit, screenshots, analyze, tests). Work incrementally,
   preserving package IDs, saved boards and entitlements. Never delete existing data.
4. If a persisted List is overloaded as category or status, design an explicit
   backward-compatible migration to distinct Column and Category concepts. Keep unknown/legacy
   fields intact when reasonable.
5. Never silently reset or seed real users' libraries. Template/demo data is opt-in and
   identifiable.

## 2. Information architecture — only essential screens

Home / My Boards
- Spacious top bar: app identity, My Boards, compact search/settings; obvious Create Board.
- Board cards with distinct preview/cover artwork, name, colour/theme, last update and a small
  meaningful summary (e.g. 4 categories · 12 cards).
- Recent/pinned boards only if clearly useful.
- Empty state: welcoming visual plus Create your first board, with Blank or Explore templates.
- No bottom navigation with dozens of modules; no permanently visible Pro tab.

Create Board
- Two paths: Blank Board and Choose Template. Blank gets To Do / Doing / Done, all editable.
- Template gallery: categories, strong thumbnails, Free/Pro labels, real preview before creation.
- Fast: title → template/blank → create. Never force tags, deadline, account or colour wizard.

Board Canvas (default Kanban)
- Horizontally scrolling full-width readable columns on phones; never 3 tiny columns at 320–400dp.
- Column header: title, card count, More; optional collapse; Add Card at column bottom.
- Cards: title, Category colour/chip, subtle cover when set, subtask progress, deadline only if
  present; compact by default.
- Drag/reorder within a column and across columns, with haptic/visual feedback and accessible
  alternatives (Move to…).
- Undo for accidental moves/deletes; empty states; drag on very long boards.
- Toolbar: Category, Search/Filter and More.

Category Overview (the standout feature)
- One obvious action from the board, not a new module.
- All categories as small distinctive blocks: name, colour/icon, card count, completion. Toán,
  Văn, Anh, Lý visible together on a common phone where practical.
- Tap category → Kanban filtered; All Categories clears.
- Create/rename/recolor/reorder in a light sheet. Deleting a category keeps its cards (move to
  Uncategorized or another category). Never delete cards as a side effect.
- Category is independent of column/status: a card keeps its category from To Do → Done.
- Fallback: Uncategorized; suggested first categories for the study template.

Card Detail / Add Card
- Minimal editor: title, note, one Category, column, subtasks, optional due date/reminder,
  cover/photo, compact More sheet.
- Quick Add saves a title immediately in its column.
- Notes, links, attachments/images if supported (local-first).
- One-level subtasks: add, edit, reorder, tick, remove, total progress. No nested trees. Free.
- Card shows 2/5; optionally a few subtasks in a Detailed presentation.
- Clear Save/Cancel, keyboard/back; accidental dismissal never loses changes.
- Duplicate Card (keep content/checklist, reset completion); duplicate Board with new IDs.
- Archive ≠ Delete. Keep Trash/Undo/Backup semantics.

## 3. Required essential features (Free)

- Boards and columns: create/edit/reorder/archive/delete, with undo/recovery.
- Cards: create/edit/move/duplicate/archive/delete; in-column reorder and cross-column drag.
- Categories with colour/icon, independent of column; Category Overview and filter.
- One-level subtasks with progress and fast check-off.
- Optional description, due date, local reminders (permission only when relevant).
- Search and a small filter set (category, column, due soon); no query builder.
- User-chosen card cover image or colour (basic covers free); local media ownership and cleanup.
- Basic board export image/PDF if reasonably scoped; portable Backup/Restore stays Free.
- Local-first, no login, no Ads, no backend, no paid APIs.
- Accessible non-drag alternatives; English/Vietnamese.

## 4. Visual brief

- Refined, clean, editorial/productivity feel: confident typography, generous whitespace,
  restrained accents, layered surfaces, soft shadows, very legible cards.
- Warm palettes; light/dark/system. No bland grey admin UI, aggressive gradients, neon, cheap
  glass, rainbow cards or excessive borders.
- One icon system (rounded line icons); targets 44–48dp; tooltips/semantics on icon buttons.
- Clear primary/secondary/destructive buttons; pressed, focus, disabled, loading, selected and
  drag-target states.
- Compact Category chips; colour is never the only identifier.
- Restrained micro-interactions; reduced-motion support.
- Readable Vietnamese diacritics, long titles, dynamic type, dark mode.
- Shared tokens/components across Home, Board, Card Detail, Templates, Settings, Pro, Export.
- At least Handy Bookmark's quality; do not clone its ivory/teal Home or call things collections.
- App icon, empty-state art, template covers, card covers and onboarding art are one original
  family; no unlicensed assets.

## 5. Built-in Card Covers and Template art (priority)

- Original offline cover library: at least 60 distinct covers in about 8–10 categories: Study,
  Work/Projects, Personal Goals, Shopping/Wishlist, Home, Creative Ideas, Travel Planning,
  Events, Wellness/Routines, Abstract/Minimal.
- 8–12 excellent board templates, each with coordinated board cover, category colours, sample
  card covers and realistic editable cards/subtasks.
- Procedural Flutter compositions or compact original images/vectors. Small, deterministic,
  offline. No image-generation APIs at runtime, no stock-image network, no scraped photos.
- Visually diverse motifs, not 60 colour variations.
- Safe crops for card header, board thumbnail, gallery and export; no baked-in localized text.
- Legible text over covers in light and dark.
- Content-aware defaults per template; never presented as user photos.
- Each cover/template: stable ID, accessible name, category, provenance, safe fallback; saved
  cover IDs keep rendering in future versions.
- Lazy previews; watch memory and bundle size.

Picker: one Cover Picker with Suggested, All, categories, Choose Photo, Solid Color; instant
preview on the real card; Apply/Cancel with rollback. Template gallery previews use the same
renderer as the real Kanban. At least 24 covers Free; the rest may be Pro.

## 6. Templates

Free: Blank Kanban (To Do / Doing / Done); Study Planner (Toán, Văn, Anh, Lý); Personal
Tasks; Shopping/Wishlist (ordinary cards, no Product entity); Project Kanban (Backlog / In
Progress / Review / Done).
Pro: Content Production (Ideas / Draft / Edit / Publish); Goal Roadmap; Event Planning;
Creative Moodboard Workflow; Home Renovation.
Fully editable after creation, own IDs, no cross-board references. Flow: Create Board → Blank /
Templates → Preview → Name → Create. Pro templates can be previewed fully; creating one needs
the entitlement. No paywall on first launch.

## 7. Pro Lifetime

Free stays fully functional (unlimited boards/cards/categories/subtasks, drag/drop, due dates,
search, export of user data, backup/restore). No Ads, no subscription, no backend.
Pro: (1) Premium Appearance with live preview on the user's data; (2) Premium Templates;
(3) a few opt-in local automation presets (all subtasks done → move to Done; due soon →
urgency; recurring card; archive Done after a period, with recovery) — no rule builder;
(4) Advanced Export styles (PNG/PDF) with preview; (5) light Board Insights.
Clear Free/Pro badges; Try Preview that is reversible and never persists paid use; the paywall
appears only on an explicit Unlock/Apply/Export action; real store price and purchase/restore
states; keep an existing SKU, never invent one; fail safely; one-time licence.

## 8. Onboarding

Short and interactive: (1) Welcome + choose Blank or a template (skippable); (2) add a card and
move it across columns on a temporary sample board or guided overlay; (3) Categories and
subtasks in context, finish. Replayable from Help. No account, no notification permission, no
trial, no permanent fake cards.

## 9. Data, safety, migration

- Keep the existing local persistence. Distinguish Board, Column, Category, Card, Subtask,
  TemplatePreset, CoverDefinition. Category removal never deletes cards.
- Stable IDs, order ranks, timestamps, migration versioning, safe copies with fresh IDs.
- User photos copied into app storage; media of archived/deleted objects handled safely.
- Board appearance, covers and compact/detailed presentation persist and round-trip in backup.
- Keep data export/backup; stay compatible with any sync model; no backend.
- Confirmation/Undo/recovery for destructive operations; tested.
- Never move a card to Done because its subtasks are checked unless that rule is enabled.

## 10. Validation

- analyze and tests; new tests for category independence, cross-column moves, subtask counts,
  template ID remapping, cover fallback, Pro preview rollback.
- Screenshots: small phone, standard phone, tablet/wide, dark, Vietnamese, empty and full boards.
- Interactive checks: create Blank; create Study template; four categories; filter; drag to Done
  (category unchanged); subtasks; cover change and cancel; duplicate card/board; delete category
  (cards survive); backup/restore; Pro preview and purchase CTA; export preview.
- Touch targets, semantics, keyboard alternatives to drag, reduced motion, contrast.
- Cover catalog memory and APK size delta.
- Honest test environment; no iOS or store-purchase claims without proof.

## 11. Delivery

Source audit; implemented work; design system; template and cover catalog (real counts, Free/Pro
split, IDs, size impact); screenshots with provenance; QA evidence; known issues P0/P1/P2.
