import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

Uint8List shot(int w, int h, [img.Color? c]) {
  final i = img.Image(width: w, height: h)
    ..clear(c ?? img.ColorRgb8(30, 120, 200));
  return Uint8List.fromList(img.encodePng(i));
}

void main() {
  test('padding grows the picture and the ground fills it', () {
    final out = img.decodePng(
      frameScreenshot(
        shot(1080, 600),
        const ShotFrame(padding: .1, radius: 0, shadow: false),
      ),
    )!;
    expect(out.width, 1080 + 2 * 60);
    expect(out.height, 600 + 2 * 60);
    final corner = out.getPixel(1, 1);
    expect([corner.r, corner.g, corner.b], [0xF2, 0xF2, 0xF2]);
    final middle = out.getPixel(out.width ~/ 2, out.height ~/ 2);
    expect([middle.r, middle.g, middle.b], [30, 120, 200]);
  });

  test('rounded corners clear the shot\'s own corner on a clear ground', () {
    final out = img.decodePng(
      frameScreenshot(
        shot(1080, 600),
        const ShotFrame(
          background: ShotFrame.transparent,
          padding: 0,
          radius: 40,
          shadow: false,
        ),
      ),
    )!;
    expect(out.getPixel(0, 0).a, 0);
    expect(out.getPixel(540, 300).a, 255);
  });

  test('the phone body and browser bar add their own size', () {
    final phone = img.decodePng(
      frameScreenshot(
        shot(540, 1000),
        const ShotFrame(padding: 0, device: 'phone'),
      ),
    )!;
    expect(phone.width, 540 + 2 * 14);
    final browser = img.decodePng(
      frameScreenshot(
        shot(1080, 600),
        const ShotFrame(padding: 0, device: 'browser'),
      ),
    )!;
    expect(browser.width, 1080);
    expect(browser.height, 600 + 72);
  });

  test('the photo colour ground is the shot\'s average', () {
    final out = img.decodePng(
      frameScreenshot(
        shot(200, 100, img.ColorRgb8(200, 10, 10)),
        const ShotFrame(background: null, shadow: false),
      ),
    )!;
    final p = out.getPixel(0, 0);
    expect([p.r, p.g, p.b], [200, 10, 10]);
  });

  test('bad settings and oversize results are refused', () {
    expect(
      () => frameScreenshot(shot(10, 10), const ShotFrame(padding: .5)),
      throwsFormatException,
    );
    expect(
      () => frameScreenshot(shot(10, 10), const ShotFrame(device: 'tablet')),
      throwsFormatException,
    );
    expect(
      () => frameScreenshot(Uint8List.fromList([1, 2, 3]), const ShotFrame()),
      throwsFormatException,
    );
    expect(
      () => frameScreenshot(shot(4000, 4000), const ShotFrame(padding: .1)),
      throwsFormatException,
    );
  });
}
