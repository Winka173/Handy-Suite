import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'engine.dart';

/// The engine this platform has on the device, or null.
(OcrEngine, String)? platformOcrEngine() => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.iOS => (const MlKitOcrEngine(), 'mlkit-latin'),
  TargetPlatform.windows => (const WindowsOcrEngine(), 'windows-ocr'),
  _ => null,
};

Map<String, Object> _box(Rect r) => {
  'x': r.left,
  'y': r.top,
  'w': r.width,
  'h': r.height,
};

/// Google ML Kit text recognition v2, Latin script, bundled model: runs on
/// the device and sends nothing. One model reads every Latin-script
/// language, so there is no language to choose.
class MlKitOcrEngine implements OcrEngine {
  const MlKitOcrEngine();

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  OcrPixelFormat get format =>
      _android ? OcrPixelFormat.nv21 : OcrPixelFormat.bgra;

  @override
  Future<OcrSupport> support() async =>
      const OcrSupport(available: true, engine: 'mlkit-latin', maxEdge: 3000);

  @override
  Future<Map<Object?, Object?>> read(OcrInput input, String? language) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromBytes(
          bytes: input.bytes,
          metadata: InputImageMetadata(
            size: Size(input.width.toDouble(), input.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: _android
                ? InputImageFormat.nv21
                : InputImageFormat.bgra8888,
            bytesPerRow: _android ? input.width : input.width * 4,
          ),
        ),
      );
      final spoken = result.blocks
          .expand((b) => b.recognizedLanguages)
          .where((l) => l.isNotEmpty && l != 'und')
          .firstOrNull;
      return {
        'lines': [
          for (final block in result.blocks)
            for (final line in block.lines)
              {
                'text': line.text,
                'box': _box(line.boundingBox),
                'words': [
                  for (final e in line.elements)
                    {'text': e.text, 'box': _box(e.boundingBox)},
                ],
              },
        ],
        'language': ?spoken,
      };
    } finally {
      await recognizer.close();
    }
  }
}

/// Windows.Media.Ocr through the handy_ocr plugin: on-device, using the
/// OCR language packs installed in Windows (Settings, Time and language).
class WindowsOcrEngine implements OcrEngine {
  const WindowsOcrEngine();
  static const _channel = MethodChannel('handy_ocr');

  @override
  OcrPixelFormat get format => OcrPixelFormat.bgra;

  @override
  Future<OcrSupport> support() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('languages');
      final tags = [
        for (final t in (raw?['languages'] as List?) ?? const [])
          if (t is String && t.isNotEmpty) t,
      ];
      final edge = raw?['maxEdge'];
      return OcrSupport(
        available: tags.isNotEmpty,
        engine: 'windows-ocr',
        languages: tags,
        maxEdge: edge is int && edge >= 512 ? edge : 2600,
      );
    } on MissingPluginException {
      return OcrSupport.none;
    } on PlatformException {
      return OcrSupport.none;
    }
  }

  @override
  Future<Map<Object?, Object?>> read(OcrInput input, String? language) async {
    try {
      final raw = await _channel
          .invokeMapMethod<Object?, Object?>('recognize', {
            'bgra': input.bytes,
            'width': input.width,
            'height': input.height,
            'language': ?language,
          });
      final lines = raw?['lines'];
      if (lines is List) {
        // Windows gives word boxes only; a line's box surrounds its words.
        for (final line in lines) {
          if (line is Map && line['box'] == null) {
            final words = [
              for (final w in (line['words'] as List?) ?? const [])
                if (w is Map && w['box'] is Map) w['box'] as Map,
            ];
            if (words.isNotEmpty) line['box'] = _around(words);
          }
        }
      }
      return raw ?? const {};
    } on PlatformException catch (e) {
      throw OcrUnavailable(
        e.code == 'language_missing'
            ? OcrProblem.languageMissing
            : OcrProblem.failed,
        e.message ?? 'Text recognition failed',
      );
    }
  }

  static Map<String, double> _around(List<Map> boxes) {
    double v(Map m, String k) => (m[k] as num?)?.toDouble() ?? 0;
    var l = double.infinity, t = double.infinity;
    var r = double.negativeInfinity, b = double.negativeInfinity;
    for (final m in boxes) {
      l = l < v(m, 'x') ? l : v(m, 'x');
      t = t < v(m, 'y') ? t : v(m, 'y');
      r = r > v(m, 'x') + v(m, 'w') ? r : v(m, 'x') + v(m, 'w');
      b = b > v(m, 'y') + v(m, 'h') ? b : v(m, 'y') + v(m, 'h');
    }
    return {'x': l, 'y': t, 'w': r - l, 'h': b - t};
  }
}
