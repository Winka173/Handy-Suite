# handy_ocr

On-device text recognition (`package:handy_ocr/handy_ocr.dart`) for Handy
Docs and Handy Media: ML Kit on Android/iOS, `Windows.Media.Ocr` on Windows,
none on the web. Kept apart from `handy_scan` so apps that only read QR
codes do not carry ML Kit.

- [Functions](../../docs/FUNCTIONS.md)

## Text recognition

```dart
import 'package:handy_ocr/handy_ocr.dart';

final support = await ocrSupport(); // what this device can read
final result = await recognizeText(png, language: 'vi');
for (final line in result.lines) {
  line.text;  // 'Thành tiền: 512.340 đ'
  line.box;   // OcrBox(left, top, width, height) in pixels of `png`
  line.words; // OcrWord(text, box) in reading order
}
result.text; // all lines, a blank line between blocks
result.where(RegExp(r'\d{9,12}')); // lines to hide, e.g. ID numbers
```

```dart
Future<OcrResult> recognizeText(
  Uint8List image, {          // PNG or JPEG, up to 20 MB / 40 Mpx
  String? language,           // BCP-47, e.g. 'vi', 'en-US'
  CancellationToken? cancellation,
});
Future<OcrSupport> ocrSupport();
```

- **Boxes** are in pixels of the image passed in, origin top-left, whatever
  size the engine worked at (big images are scaled down for the engine and
  the boxes scaled back). `OcrBox.fractionOf(w, h)` gives page fractions.
- **Lines** come in reading order: top to bottom, and lines that share a row
  (two columns of a form) left to right. `layoutText` / `readingOrder` are
  exported for engines' raw output.
- **Errors:** `OcrUnavailable` with `OcrProblem.unsupportedPlatform` (web,
  macOS, Linux), `.languageMissing` (Windows has no pack for `language`;
  `installed` lists what it has) or `.failed`; `FormatException` for a file
  that is not a picture; `Cancelled` when the token fires (the engine call
  itself finishes in the background and its result is dropped).
- **Privacy:** nothing is uploaded, written or logged. Pixels stay in memory
  for the length of the call.

| Platform      | Engine                                                                                     | Language                                                                                                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Android, iOS  | Google ML Kit text recognition v2, Latin script, bundled model (`google_mlkit_text_recognition` 0.17.1) | One model reads every Latin-script language (Google lists Vietnamese as supported); `language` is ignored. Not yet verified on a device (see below).                                              |
| Windows       | `Windows.Media.Ocr` through this package's C++/WinRT plugin (channel `handy_scan/ocr`)    | Uses the OCR packs installed in Windows. `null` uses the profile languages; `'vi'` needs Vietnamese with its "Optical character recognition" feature (Settings › Time & language). |
| Web and other | none                                                                                       | Always `OcrUnavailable(unsupportedPlatform)`.                                                                                                                                              |

Tests replace the engine with `ocrEngineOverride = MyFakeEngine();` (an
`OcrEngine` returning the map shape `OcrResult.fromMap` reads).

### Known limits

- **Vietnamese on Android/iOS:** Google lists Vietnamese (`vi`, Latin) as a
  supported language of the v2 Latin model, but it has not been checked on a
  device here: tone marks (ạ/ả/ã/ẫ) on small or blurred print are the likely
  weak spot. Only host tests and the Windows engine have run so far.
- **Vietnamese on Windows:** only when the Vietnamese OCR pack is installed.
  With an English pack, accented letters often come out without accents.
- **Build cost:** every app depending on `handy_ocr` (Docs and Media) bundles ML Kit on
  Android (about 4 MB per ABI) and needs iOS 15.5+ with armv7 excluded.
- Handwriting, rotated pages (no deskew) and tables are read as plain lines.
