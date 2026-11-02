/// On-device text recognition (OCR) for Handy Suite apps.
///
/// ```dart
/// import 'package:handy_ocr/handy_ocr.dart';
///
/// final result = await recognizeText(png, language: 'vi');
/// for (final line in result.lines) {
///   print('${line.text} at ${line.box}'); // pixels of `png`, top-left origin
/// }
/// ```
///
/// Android and iOS use Google ML Kit (Latin script, bundled model); Windows
/// uses Windows.Media.Ocr with the language packs installed in Windows. The
/// web has no engine and throws [OcrUnavailable]. Nothing is uploaded, saved
/// or logged: the pixels stay in memory for the length of the call.
library;

import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'src/ocr/engine.dart';
import 'src/ocr/model.dart';
import 'src/ocr/platform_web.dart'
    if (dart.library.io) 'src/ocr/platform_io.dart'
    as platform;

export 'src/ocr/engine.dart'
    show
        OcrEngine,
        OcrInput,
        OcrPixelFormat,
        OcrProblem,
        OcrSupport,
        OcrUnavailable,
        chooseOcrLanguage,
        prepareOcrImage,
        validateOcrImage;
export 'src/ocr/model.dart'
    show OcrBox, OcrLine, OcrResult, OcrWord, layoutText, readingOrder;

/// Replaces the platform engine, for tests and previews. Null restores it.
OcrEngine? ocrEngineOverride;

(OcrEngine, String)? _engine() {
  final o = ocrEngineOverride;
  if (o != null) return (o, 'test');
  return kIsWeb ? null : platform.platformOcrEngine();
}

/// What this device can read, without reading anything.
Future<OcrSupport> ocrSupport() async {
  final e = _engine();
  if (e == null) return OcrSupport.none;
  return e.$1.support();
}

/// Reads the text in [image] (PNG or JPEG, up to 20 MB) on this device.
///
/// [language] is a BCP-47 tag such as 'vi' or 'en-US'. Windows uses it to
/// choose an installed OCR language and throws [OcrUnavailable] with
/// [OcrProblem.languageMissing] (and what is installed) when it is missing;
/// null uses the Windows profile languages. ML Kit reads every Latin-script
/// language with one model and ignores it.
///
/// Lines come back in reading order with boxes in pixels of [image]. Throws
/// [OcrUnavailable] on the web or on failure, [FormatException] for a file
/// that is not a picture, and [Cancelled] when [cancellation] fires (the
/// engine itself finishes in the background; its result is dropped).
Future<OcrResult> recognizeText(
  Uint8List image, {
  String? language,
  CancellationToken? cancellation,
}) async {
  final e = _engine();
  if (e == null) {
    throw const OcrUnavailable(
      OcrProblem.unsupportedPlatform,
      'Text recognition runs in the Android, iOS and Windows apps',
    );
  }
  return runOcr(
    e.$1,
    e.$2,
    image,
    language: language,
    cancellation: cancellation,
    background: <T>(T Function() work) => ocrEngineOverride == null
        ? compute((_) => work(), null)
        : Future.sync(work),
  );
}
