import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:image/image.dart' as img;

Uint8List png(int w, int h, {int alpha = 255}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  for (final p in image) {
    p.setRgba(10, 20, 30, alpha);
  }
  return img.encodePng(image);
}

Map<String, Object> box(double x, double y, double w, double h) => {
  'x': x,
  'y': y,
  'w': w,
  'h': h,
};

OcrLine line(
  String text,
  double x,
  double y, {
  double w = 100,
  double h = 20,
}) => OcrLine(text, OcrBox(x, y, w, h));

class FakeEngine implements OcrEngine {
  OcrSupport value = const OcrSupport(
    available: true,
    engine: 'fake',
    languages: ['en-US', 'vi-VN'],
    maxEdge: 1000,
  );
  OcrInput? seen;
  String? language;
  Map<Object?, Object?> answer = {};
  @override
  OcrPixelFormat format = OcrPixelFormat.bgra;
  @override
  Future<OcrSupport> support() async => value;
  @override
  Future<Map<Object?, Object?>> read(OcrInput input, String? language) async {
    seen = input;
    this.language = language;
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ocrEngineOverride = null);

  test('lines read top to bottom, a row of columns left to right', () {
    final ordered = readingOrder([
      line('Thành tiền', 40, 300),
      line('512.340 đ', 300, 302),
      line('HÓA ĐƠN TIỀN ĐIỆN', 40, 40, w: 400, h: 34),
      line('Kỳ: tháng 10/2026', 40, 110),
      line('Khách hàng: Nguyễn Thị Lan', 40, 136),
    ]);
    expect(ordered.map((l) => l.text), [
      'HÓA ĐƠN TIỀN ĐIỆN',
      'Kỳ: tháng 10/2026',
      'Khách hàng: Nguyễn Thị Lan',
      'Thành tiền',
      '512.340 đ',
    ]);
    // Paragraph gaps become blank lines; a row's columns share one line.
    expect(
      layoutText(ordered),
      'HÓA ĐƠN TIỀN ĐIỆN\n\nKỳ: tháng 10/2026\nKhách hàng: Nguyễn Thị Lan'
      '\n\nThành tiền    512.340 đ',
    );
    expect(layoutText(const []), '');
  });

  test('engine answers are parsed defensively and scaled to the image', () {
    final result = OcrResult.fromMap(
      {
        'language': 'vi-VN',
        'lines': [
          {
            'text': '  Xin\u0000 chào  ',
            'words': [
              {'text': 'Xin', 'box': box(10, 10, 30, 10)},
              {'text': 'chào', 'box': box(50, 12, 40, 10)},
              {'text': '', 'box': box(0, 0, 1, 1)},
              'junk',
            ],
          },
          {'text': 'no box'},
          {'text': '', 'box': box(1, 1, 1, 1)},
          {'text': 'bad', 'box': box(1, 1, -4, 1)},
          42,
        ],
      },
      width: 400,
      height: 300,
      engine: 'test',
      scale: 2,
    );
    expect(result.language, 'vi-VN');
    expect(result.lines.single.text, 'Xin chào');
    expect(result.lines.single.words.map((w) => w.text), ['Xin', 'chào']);
    // The line box surrounds its words, in the caller's pixels.
    expect(result.lines.single.box, const OcrBox(20, 20, 160, 24));
    expect(result.where('chào').length, 1);
    expect(
      result.lines.single.box.fractionOf(400, 300).left,
      closeTo(.05, 1e-9),
    );
    expect(
      OcrResult.fromMap(const {}, width: 1, height: 1, engine: 'x').isEmpty,
      isTrue,
    );
  });

  test(
    'a requested language must be installed where the engine lists them',
    () {
      const windows = OcrSupport(
        available: true,
        engine: 'windows-ocr',
        languages: ['en-US'],
      );
      expect(chooseOcrLanguage(windows, null), isNull);
      expect(chooseOcrLanguage(windows, 'en'), 'en-US');
      expect(chooseOcrLanguage(windows, 'EN-us'), 'en-US');
      expect(
        () => chooseOcrLanguage(windows, 'vi'),
        throwsA(
          isA<OcrUnavailable>()
              .having((e) => e.problem, 'problem', OcrProblem.languageMissing)
              .having((e) => e.installed, 'installed', ['en-US']),
        ),
      );
      // ML Kit reads the whole Latin script: no list, no refusal.
      const mlkit = OcrSupport(available: true, engine: 'mlkit-latin');
      expect(chooseOcrLanguage(mlkit, 'vi'), isNull);
    },
  );

  test('pictures are checked, scaled to the engine and laid out for it', () {
    expect(
      () => validateOcrImage(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9])),
      throwsFormatException,
    );
    final big = prepareOcrImage(png(3000, 1001), 1000, OcrPixelFormat.nv21);
    expect((big.width, big.height), (3000, 1001));
    expect(big.scale, 3);
    // NV21 needs even sides: 1000 × 334 (333.67 rounds, then made even).
    expect(big.input.width.isEven && big.input.height.isEven, isTrue);
    expect(big.input.bytes.length, big.input.width * big.input.height * 3 ~/ 2);
    final clear = prepareOcrImage(
      png(4, 4, alpha: 0),
      1000,
      OcrPixelFormat.bgra,
    );
    expect(clear.scale, 1);
    // Transparent pixels are read as white paper.
    expect(clear.input.bytes.sublist(0, 4), [255, 255, 255, 255]);
    final solid = prepareOcrImage(png(2, 2), 1000, OcrPixelFormat.bgra);
    expect(solid.input.bytes.sublist(0, 4), [30, 20, 10, 255]);
  });

  test(
    'recognizeText scales boxes back, honours cancel and the language',
    () async {
      final engine = FakeEngine()
        ..answer = {
          'lines': [
            {'text': 'Biên nhận', 'box': box(10, 10, 100, 20)},
          ],
        };
      ocrEngineOverride = engine;
      final result = await recognizeText(png(2000, 500), language: 'vi');
      expect(engine.language, 'vi-VN');
      expect((engine.seen!.width, engine.seen!.height), (1000, 250));
      expect(result.lines.single.box, const OcrBox(20, 20, 200, 40));
      expect((result.width, result.height), (2000, 500));
      expect(result.text, 'Biên nhận');

      await expectLater(
        recognizeText(png(10, 10), language: 'ja'),
        throwsA(isA<OcrUnavailable>()),
      );
      final canceled = CancellationToken()..cancel();
      await expectLater(
        recognizeText(png(10, 10), cancellation: canceled),
        throwsA(isA<Cancelled>()),
      );
      engine.value = OcrSupport.none;
      await expectLater(
        recognizeText(png(10, 10)),
        throwsA(
          isA<OcrUnavailable>().having(
            (e) => e.problem,
            'problem',
            OcrProblem.unsupportedPlatform,
          ),
        ),
      );
      expect((await ocrSupport()).available, isFalse);
    },
  );

  test(
    'the Windows channel sends pixels and reads word boxes into lines',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final calls = <MethodCall>[];
      const channel = MethodChannel('handy_ocr');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'languages') {
          return {
            'languages': ['en-US'],
            'maxEdge': 10000,
          };
        }
        return {
          'language': 'en-US',
          'lines': [
            {
              'text': 'Total 512',
              'words': [
                {'text': 'Total', 'box': box(4, 6, 40, 12)},
                {'text': '512', 'box': box(50, 4, 30, 14)},
              ],
            },
          ],
        };
      });
      try {
        final support = await ocrSupport();
        expect(support.engine, 'windows-ocr');
        expect(support.languages, ['en-US']);
        final result = await recognizeText(png(100, 40), language: 'en');
        final call = calls.last;
        expect(call.method, 'recognize');
        expect(call.arguments['width'], 100);
        expect(call.arguments['language'], 'en-US');
        expect((call.arguments['bgra'] as Uint8List).length, 100 * 40 * 4);
        expect(result.engine, 'windows-ocr');
        expect(result.lines.single.box, const OcrBox(4, 4, 76, 14));
        await expectLater(
          recognizeText(png(10, 10), language: 'vi'),
          throwsA(
            isA<OcrUnavailable>().having(
              (e) => e.problem,
              'problem',
              OcrProblem.languageMissing,
            ),
          ),
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'languages') {
            return {
              'languages': ['en-US'],
            };
          }
          throw PlatformException(code: 'failed', message: 'engine crashed');
        });
        await expectLater(
          recognizeText(png(10, 10)),
          throwsA(
            isA<OcrUnavailable>().having(
              (e) => e.problem,
              'problem',
              OcrProblem.failed,
            ),
          ),
        );
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
