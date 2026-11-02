# Handy Card — editor architecture

Code: `packages/handy_card_engine` (pure Dart, no Flutter) and
`apps/handy_card/lib/editor` (Flutter: canvas, inspector, layers, studio).

## Scene graph

`CardDocument` → `pages` (sides, any number) → `elements` (a recursive layer
tree). Each `CardElement` has a stable `id`, a `type`, a `name`, a `Frame`, an
`opacity`, `visible`/`locked`, type-specific `props`, `children` (groups) and an
optional `binding` to a profile field. Keys a build does not know are kept in
`extra` and written back unchanged, so a document from a newer build survives
being saved by an older one. Documents are immutable; every edit returns a new
document that shares unchanged branches.

## Coordinates

- Document units are **points** (1/72 inch). Millimetres, inches and pixels are
  display units only (`toPoints`/`fromPoints`; pixel designs are 1 px = 1 pt).
- An element's `Frame` is its unrotated box `(x, y, w, h)` in its parent's
  space, turned `r` degrees clockwise about the box centre.
- `Frame.matrix` = `T(x + w/2, y + h/2) · R(r) · T(−w/2, −h/2)` maps local
  `(0..w, 0..h)` to the parent. `worldMatrix` chains the matrices of every
  ancestor group. `Affine` uses SVG's `matrix(a b c d e f)` layout so exporters
  write it unchanged.
- The view maps a document point `p` to the screen as `origin + p · zoom`
  (`StudioController.toScreen/toDoc`). Export resolution is independent: PNG
  renders at `dpi / 72` pixels per point.
- Every frame value is rounded to a thousandth of a point and angles are folded
  into (−180, 180], so repeated edits cannot drift (tested with 1,000 moves).

## Hit testing and selection

`hitTest` walks layers top first, maps the point through the inverse world
matrix of each element and tests the local box (with a tolerance scaled to the
zoom). Hidden and locked layers are skipped. Groups answer as one object unless
the person has entered the group (double-click), when its children answer.
`elementsInside` is the rubber band; `topmostOnly` drops selected children of
selected groups so no edit applies twice.

## Editing operations (`edits.dart`)

`moveBy` (page-space delta converted into each parent's space), `resizeFrame`
(in the element's own rotated axes around the opposite edge or corner, or the
centre; aspect lock), `scaleSelection` (several elements fitted into a new
box), `rotateBy` (about the selection centre), `setProps` (validated by the
element's spec), `duplicate` (deep, fresh ids), `arrange`, `moveInTree` (layers
panel, keeps world placement), `groupElements` and `ungroup` (both keep every
element where it is seen, including turned groups), `alignElements`,
`distribute`.

## Snapping

`snapMove` snaps the moving box's left, centre or right (top, middle, bottom)
to card edges and centre, the safe margin, other elements' edges and centres,
or a grid, within a threshold of 6 screen pixels converted to points. Guides
are returned and drawn in the hue. `snapAngle` softly snaps rotation to 15°
steps (Shift forces it).

## Commands and history (`session.dart`)

`EditorSession` holds the document, the side shown, the selection, the entered
group and the history (bounded, 200 steps by default).

- `apply(label, change, {coalesce})` records one step. Steps with the same
  coalesce key within 1.5 s merge (typing, nudging, typing a number).
- Gestures are transactions: `begin`, any number of `preview`s computed from
  the state at `begin` (so nothing accumulates error), then one `commit` (one
  undo step) or `cancel` (no trace). A drag of 60 pointer moves is one step.
- A new edit after an undo clears the redo stack.
- `dirty` compares the revision with the last saved one; the studio autosaves
  600 ms after the last change and writes one save at a time.
- Document undo is separate from navigation; leaving the studio first waits
  for the save.

## Rendering

All renderers draw from the same geometry: `Frame.matrix`, `PathOp` outlines
(`roundedRectPath`, `ellipsePath`, `polygonPoints`, icons, QR modules),
`imagePlacement` for crop and fit, and `layoutText` for line breaks, which uses a
`TextMeasurer`. The app measures with the real faces (`FlutterMeasurer`), and
passes the same measurer to SVG and PDF, so lines break identically. See
`HANDY_CARD_EXPORT_PARITY.md`.

## Performance (measured)

`packages/handy_card_engine/test/performance_test.dart` measures the core on
the test host and writes `docs/qa/evidence/card-engine-performance.json`. On
2026-11-02 (Windows host): with 500 elements, a hit test took 7 µs, a 60-move
drag of 250 elements 254 ms in total (about 4 ms per move), decode 12 ms, SVG
46 ms. Frame times on phones are not measured yet (no device run).
