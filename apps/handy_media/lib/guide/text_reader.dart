import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ocr/handy_ocr.dart' as scan;

/// Reads the words in a picture, on this device, with their boxes in the
/// picture's own pixels. Nothing leaves the device.
abstract interface class TextReader {
  /// Whether this device can read text in pictures. When false the editor
  /// does not offer "Find private details".
  bool get supported;

  Future<List<OcrLine>> read(Uint8List png, {CancellationToken? cancellation});
}

/// No reader: text recognition is not available on this platform (the web,
/// desktops) or not wired yet.
class NoTextReader implements TextReader {
  const NoTextReader();
  @override
  bool get supported => false;
  @override
  Future<List<OcrLine>> read(
    Uint8List png, {
    CancellationToken? cancellation,
  }) => throw UnsupportedError('Text recognition is not available here');
}

/// Why the device could not read a picture: no recogniser here, or (on
/// Windows) no OCR language installed.
class TextReaderUnavailable implements Exception {
  final bool languageMissing;
  const TextReaderUnavailable({this.languageMissing = false});
}

/// The device's own recogniser from `package:handy_ocr`: ML Kit on Android
/// and iOS, Windows.Media.Ocr on Windows. Pictures stay on the device.
class DeviceTextReader implements TextReader {
  const DeviceTextReader();

  @override
  bool get supported =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  @override
  Future<List<OcrLine>> read(
    Uint8List png, {
    CancellationToken? cancellation,
  }) async {
    final scan.OcrResult result;
    try {
      result = await scan.recognizeText(png, cancellation: cancellation);
    } on scan.OcrUnavailable catch (e) {
      throw TextReaderUnavailable(
        languageMissing: e.problem == scan.OcrProblem.languageMissing,
      );
    }
    OcrBox box(scan.OcrBox b) => OcrBox(b.left, b.top, b.width, b.height);
    return [
      for (final l in result.lines)
        OcrLine(
          l.text,
          box(l.box),
          words: [for (final w in l.words) OcrWord(w.text, box(w.box))],
        ),
    ];
  }
}

/// The reader Media uses by default: the device's, where there is one.
TextReader deviceTextReader() => const DeviceTextReader();
