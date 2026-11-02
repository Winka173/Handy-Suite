# Handy Card — extension guide

Extensions are compiled, trusted Dart code registered at start-up. Nothing
downloaded or imported is ever executed: templates and projects are data,
validated by the element specs below.

## Add an element type

The worked example is the **badge** seal
(`packages/handy_card_engine/lib/src/badge_extension.dart`). It touches no
core file.

1. **Spec (core).** Register an `ElementSpec` with the `ElementRegistry`:
   `type`, labels, default size, `defaults()`, `normalize(props)` (validate and
   clamp; throw `FormatException` on anything unsafe), `keepsAspect`, and
   `scaleProps` if the element should grow with its group.
2. **SVG.** `svgWriters['badge'] = (out, element, ctx) { … }` writes the
   element in its own space (the caller has applied its matrix). Reuse
   `_svgElement` for child shapes or text.
3. **PDF.** `pdfWriters['badge'] = (ctx, element, alpha) { … }`, same space.
4. **Screen.** In the app, `canvasPainters['badge'] = (canvas, element, ctx)`
   (`apps/handy_card/lib/editor/paint.dart`).
5. **Inspector.** `inspectorSections['badge'] = (context, studio, element) =>
[widgets…]` (`apps/handy_card/lib/editor/inspector.dart`). Position, size,
   rotation, opacity, name, visibility and lock come for free.
6. **Palette.** Add an entry to `_AddPalette` in `studio_page.dart`.

Selection, handles, hit testing, snapping, grouping, layers, undo, autosave,
serialization and the project ZIP need nothing.

**Compatibility.** A document with an element type the running build does not
register still loads: the element keeps its `props` and unknown keys exactly,
draws as a hatched placeholder, can be moved, hidden or deleted, and is written
back unchanged (`editor_test.dart`: "an element type this build does not know
is kept through a save"; "the badge extension saves, loads and draws like a
built-in").

## Add an export target

Export targets are functions from a `CardDocument` (plus profile, measurer,
asset bytes and fonts) to bytes and a list of warnings: see `exportSvg`,
`exportPdf`, `exportPrintSheet`, `profileHtml`, `emailSignatureHtml`. Add the
function in the engine with tests, then a choice in
`apps/handy_card/lib/export/export_sheet.dart` (`ExportFormat`).

## Add a template

A `CardTemplate(id, en, vi, kind, build)` whose `build(registry, at)` returns a
document. Templates must be original (no copied layouts, logos or paid
faces). User templates are documents saved under the `template` record kind.

## Add a size preset

A `CardSize` in `presets.dart`: name, unit, size, suggested bleed and safe
margin, and whether it is meant for print.

## Add a binding field

A key in `bindableFields` and a case in `profileValue`. Bindings are plain
lookups, never interpolated code.

## Versioning

`cardSchemaVersion` (documents), `cardProjectVersion` (project ZIP). A schema
change adds a step to `migrateCardDocument`, bumps the version and adds a
migration test with an old fixture. Newer schemas are refused with a message,
never guessed at.
