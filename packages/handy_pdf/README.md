# handy_pdf

Local PDF work through PDFium (`pdfrx` 2.4.8, `pdfium_dart` 0.2.5). Nothing
opens URLs or document actions, and the caller's bytes are never written:
every operation returns a new, re-opened and page-count-checked copy.

- [Functions](../../docs/FUNCTIONS.md)
- [Development](../../docs/DEVELOPMENT.md)
- [Implementation status](../../FEATURE_MATRIX.md)

## API (`package:handy_pdf/handy_pdf.dart`)

- `LocalPdf.open`, `pages`, `pageText`, `renderPng`, `merge`.
- `transform(indices, rotation:, watermark:, font:)`: pick, reorder, turn,
  stamp. Stamps embed a TrueType font once per document (default: the
  bundled Geist via `loadPdfFont()`), so Vietnamese works; text the font
  cannot draw is refused (`validatePdfWatermark(text, font:)`).
- `flatten(List<PdfStamp>)`: pictures (`PdfImageStamp`, straight RGBA, alpha
  kept as a soft mask) and lines of text (`PdfTextStamp`; `fit` stretches the
  line to its box; `invisible` makes a searchable hidden layer). Boxes are
  `PdfBox` fractions of the page as shown, from its top-left; turned pages
  are handled (`shownToPdf`).
- `compress(quality:, dpi:)`: re-encodes pictures as JPEG at most `dpi` at
  their size on the page. Skipped and left byte-identical: pictures shared
  between pages, transparent or masked, turned or skewed, 1-bit, under
  64 px, or that would not shrink by a tenth. The pages are then copied into a
  fresh document so replaced streams are dropped. Throws when nothing shrank.
- `rasterize(dpi:, quality:)`: "strong" compression; every page becomes one
  JPEG. Text is no longer selectable or searchable.

Editing (stamps, `flatten`, `compress`) needs native PDFium (Android, iOS,
Windows); `supportsPdfEditing` is false on the web.

## Tests

Host tests that need PDFium are skipped unless a library is given:

```powershell
flutter test --no-pub --dart-define=HANDY_PDFIUM_MODULE_PATH=<app>/build/native_assets/windows/pdfium.dll
```

In tests, read fonts outside `tester.runAsync` (asset channels only answer
in fake time) and pass them as `font:`.
