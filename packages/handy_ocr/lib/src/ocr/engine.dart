import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as img;
import 'model.dart';

/// Why text could not be read.
enum OcrProblem {
  /// The web, macOS and Linux have no on-device engine here.
  unsupportedPlatform,

  /// Windows has no OCR language pack for what was asked.
  languageMissing,

  /// The engine ran and failed.
  failed,
}

class OcrUnavailable implements Exception {
  final OcrProblem problem;

  /// What is installed, when the engine lists its languages.
  final List<String> installed;
  final String message;
  const OcrUnavailable(this.problem, this.message, {this.installed = const []});
  @override
  String toString() => message;
}

/// What this device can read.
class OcrSupport {
  final bool available;

  /// 'mlkit-latin', 'windows-ocr' or 'none'.
  final String engine;

  /// BCP-47 tags of installed recognition languages (Windows). Empty when
  /// the engine reads a whole script instead (ML Kit reads Latin script:
  /// English, Vietnamese, French… with one model).
  final List<String> languages;

  /// Largest image edge the engine accepts; bigger images are scaled down.
  final int maxEdge;
  const OcrSupport({
    required this.available,
    required this.engine,
    this.languages = const [],
    this.maxEdge = 4000,
  });

  static const none = OcrSupport(available: false, engine: 'none');

  bool get listsLanguages => languages.isNotEmpty;

  /// The installed tag that serves [wanted] ('vi' matches 'vi-VN'), or null.
  String? match(String wanted) {
    final w = wanted.toLowerCase();
    for (final tag in languages) {
      final t = tag.toLowerCase();
      if (t == w || t.split('-').first == w.split('-').first) return tag;
    }
    return null;
  }
}

/// Pixels in the layout an engine reads.
enum OcrPixelFormat { bgra, nv21 }

class OcrInput {
  final Uint8List bytes;
  final int width, height;
  final OcrPixelFormat format;
  const OcrInput(this.bytes, this.width, this.height, this.format);
}

/// An on-device text recognition engine. Implementations return the map
/// shape [OcrResult.fromMap] reads, with boxes in [OcrInput] pixels.
abstract interface class OcrEngine {
  OcrPixelFormat get format;
  Future<OcrSupport> support();
  Future<Map<Object?, Object?>> read(OcrInput input, String? language);
}

/// Decoded, upright and scaled to fit [maxEdge]: the pixels for an engine,
/// the original size, and how much the engine's boxes must be scaled up.
({OcrInput input, int width, int height, double scale}) prepareOcrImage(
  Uint8List encoded,
  int maxEdge,
  OcrPixelFormat format,
) {
  final decoded = img.decodeImage(encoded);
  if (decoded == null) {
    throw const FormatException('The picture could not be read');
  }
  if (decoded.width * decoded.height > 40000000) {
    throw const FormatException('Pictures for text recognition: 40 Mpx');
  }
  // Eight bits and four channels whatever the file held (16-bit, palette).
  var image = img
      .bakeOrientation(decoded)
      .convert(format: img.Format.uint8, numChannels: 4);
  final width = image.width, height = image.height;
  final longest = width > height ? width : height;
  var scale = 1.0;
  if (longest > maxEdge) {
    scale = longest / maxEdge;
    image = img.copyResize(
      image,
      width: width >= height ? maxEdge : null,
      height: width >= height ? null : maxEdge,
      interpolation: img.Interpolation.average,
    );
  }
  if (format == OcrPixelFormat.nv21) {
    // NV21 needs even sides; the last row or column is never text.
    final w = image.width & ~1, h = image.height & ~1;
    final out = Uint8List(w * h + w * h ~/ 2)
      ..fillRange(w * h, w * h * 3 ~/ 2, 128);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        out[y * w + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b)
            .round()
            .clamp(0, 255);
      }
    }
    return (
      input: OcrInput(out, w, h, format),
      width: width,
      height: height,
      scale: scale,
    );
  }
  final rgba = image;
  final out = Uint8List(rgba.width * rgba.height * 4);
  var i = 0;
  for (final p in rgba) {
    // Transparent areas are read as white paper.
    final a = p.a / 255;
    out[i++] = (p.b * a + 255 * (1 - a)).round();
    out[i++] = (p.g * a + 255 * (1 - a)).round();
    out[i++] = (p.r * a + 255 * (1 - a)).round();
    out[i++] = 255;
  }
  return (
    input: OcrInput(out, rgba.width, rgba.height, format),
    width: width,
    height: height,
    scale: scale,
  );
}

/// PNG or JPEG, up to 20 MB, checked before any decoding.
void validateOcrImage(Uint8List bytes) {
  final png =
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47;
  final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
  if ((!png && !jpeg) || bytes.length > 20000000) {
    throw const FormatException(
      'Text recognition reads PNG or JPEG up to 20 MB',
    );
  }
}

/// Picks the language to ask for: [wanted] when the engine has it, the
/// engine's own default for null, and [OcrUnavailable] otherwise.
String? chooseOcrLanguage(OcrSupport support, String? wanted) {
  if (wanted == null || !support.listsLanguages) return null;
  final tag = support.match(wanted);
  if (tag == null) {
    throw OcrUnavailable(
      OcrProblem.languageMissing,
      'The $wanted text recognition language is not installed',
      installed: support.languages,
    );
  }
  return tag;
}

/// Runs [engine] on [encoded] with the checks every platform shares.
Future<OcrResult> runOcr(
  OcrEngine engine,
  String engineId,
  Uint8List encoded, {
  String? language,
  CancellationToken? cancellation,
  required Future<T> Function<T>(T Function() work) background,
}) async {
  validateOcrImage(encoded);
  cancellation?.check();
  final support = await engine.support();
  if (!support.available) {
    throw const OcrUnavailable(
      OcrProblem.unsupportedPlatform,
      'Text recognition is not available on this device',
    );
  }
  final tag = chooseOcrLanguage(support, language);
  final copy = Uint8List.fromList(encoded);
  final maxEdge = support.maxEdge.clamp(512, 4000);
  final format = engine.format;
  final prepared = await background(
    () => prepareOcrImage(copy, maxEdge, format),
  );
  cancellation?.check();
  final Map<Object?, Object?> raw;
  try {
    raw = await engine.read(prepared.input, tag);
  } on OcrUnavailable {
    rethrow;
  } catch (e) {
    throw OcrUnavailable(OcrProblem.failed, 'Text recognition failed: $e');
  }
  cancellation?.check();
  return OcrResult.fromMap(
    raw,
    width: prepared.width,
    height: prepared.height,
    engine: engineId,
    scale: prepared.scale,
  );
}
