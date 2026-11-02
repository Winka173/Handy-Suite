# Handy Card — export parity

One geometry feeds every renderer: frame matrices, `PathOp` outlines,
`imagePlacement` and `layoutText` with the app's real-face measurer.

| Feature                    | Screen              | PNG / JPEG         | SVG                                         | PDF                                                          |
| -------------------------- | ------------------- | ------------------ | ------------------------------------------- | ------------------------------------------------------------ |
| Position, rotation, groups | Yes                 | Yes (same painter) | Yes (`matrix()` per element)                | Yes (CTM per element)                                        |
| Text line breaks           | Shared layout       | Same               | Same lines as `<tspan>`                     | Same lines, embedded TrueType                                |
| Faces                      | Bundled             | Bundled            | Named only; viewers may substitute (warned) | Embedded (Hanken Grotesk, Literata, Bricolage, Geist Mono)   |
| Vietnamese marks           | Yes                 | Yes                | Yes if the viewer has the face              | Yes; without fonts falls back to Helvetica with "?" (warned) |
| Linear gradient            | Yes                 | Yes                | `linearGradient`                            | 64 vector bands (visible steps when enlarged)                |
| Opacity                    | Layer               | Layer              | `opacity` per group                         | Graphic state alpha, multiplied down groups                  |
| Picture crop / fit / mask  | Yes                 | Yes                | Nested `svg` viewBox + clipPath             | Clip + placed image                                          |
| QR                         | Yes                 | Yes                | Path, `crispEdges`                          | Vector rectangles                                            |
| Bleed                      | Shown, veiled       | Optional           | Optional (viewBox)                          | Optional; crop marks optional                                |
| Physical size              | n/a                 | DPI choice         | `width`/`height` in mm                      | Page = card size (+ bleed, marks)                            |
| Unknown element type       | Hatched placeholder | Placeholder        | Skipped (warned)                            | Skipped (warned)                                             |

Warnings shown after an export: missing pictures, missing faces, text that
does not fit its box, QR content too long, SVG face substitution.

## Tests

`export_test.dart`: vCard escaping and folding, QR matrices and density
checks, SVG text/escaping/size, PDF page count and embedded font, print
sheet, crop placement, project ZIP round trip and tampering. The app's
`card_flow_test.dart` renders through the screen painter. Not yet covered:
pixel-level golden comparison between canvas, PNG and PDF rasterised output,
and camera scans of printed QR codes (no device run).
