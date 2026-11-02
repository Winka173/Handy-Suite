import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:image/image.dart' as img;

Uint8List solid(int w, int h, int r, int g, int b) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  // A dark line across the top, as screenshots have text.
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: w - 1,
    y2: (h / 10).floor(),
    color: img.ColorRgb8(20, 20, 20),
  );
  return mediaPng(image);
}

Uint8List bar(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(29, 31, 32));
  return mediaPng(image);
}

void near(img.Pixel p, int r, int g, int b) {
  expect((p.r - r).abs(), lessThan(12), reason: 'red ${p.r} vs $r');
  expect((p.g - g).abs(), lessThan(12), reason: 'green ${p.g} vs $g');
  expect((p.b - b).abs(), lessThan(12), reason: 'blue ${p.b} vs $b');
}

void main() {
  final pictures = [
    GuideRaster('step-1', solid(1200, 800, 194, 37, 92)),
    GuideRaster('step-2', solid(600, 900, 40, 120, 200)),
    GuideRaster('step-3', solid(300, 200, 30, 160, 70)),
  ];
  List<({int width, int height})> sizes() => [
    for (final p in pictures) (width: p.width, height: p.height),
  ];

  test('layout: one width, never enlarged, caption bar under each', () {
    final layout = GuideGifLayout.of(sizes(), maxWidth: 640);
    expect(layout.width, 640);
    expect(layout.captionHeight, 64);
    // The tall step sets the picture box: 900 high, 600 wide, fits as is.
    expect(layout.pictureHeight, 900);
    expect(layout.height, 964);
    final small = GuideGifLayout.of(
      [(width: 300, height: 200)],
      maxWidth: 960,
      captions: false,
    );
    expect(small.width, 300);
    expect(small.height, 200);
    expect(small.captionHeight, 0);
  });

  test('layout refuses odd widths, no steps and too many pixels', () {
    expect(
      () => GuideGifLayout.of(sizes(), maxWidth: 1000),
      throwsFormatException,
    );
    expect(() => GuideGifLayout.of([], maxWidth: 640), throwsFormatException);
    expect(
      () => GuideGifLayout.of(
        List.filled(100, (width: 2000, height: 4000)),
        maxWidth: 960,
      ),
      throwsFormatException,
    );
  });

  test('decoded GIF has a frame per step, its timing, picture and caption '
      'bar', () async {
    final layout = GuideGifLayout.of(sizes(), maxWidth: 640);
    final heard = <(int, int)>[];
    final gif = await buildGuideGif(
      [
        for (final p in pictures)
          GuideGifFrame(p, caption: bar(layout.width, layout.captionHeight)),
      ],
      layout,
      frameMs: 1500,
      progress: (done, of) => heard.add((done, of)),
    );
    expect(heard.first, (0, 3));
    expect(heard.last, (3, 3));
    expect(String.fromCharCodes(gif.sublist(0, 6)), 'GIF89a');
    final decoded = img.decodeGif(gif)!;
    expect(decoded.numFrames, 3);
    expect(decoded.width, 640);
    expect(decoded.height, 964);
    expect(decoded.loopCount, 0);
    for (final frame in decoded.frames) {
      expect(frame.frameDuration, 1500);
      // The caption bar runs along the foot of every frame.
      near(frame.getPixel(320, 964 - 20), 29, 31, 32);
    }
    // Step 1, 1200 wide, is shrunk to 640 × 427 and centred in the box.
    final first = decoded.frames[0];
    near(first.getPixel(320, 450), 194, 37, 92);
    near(first.getPixel(320, 100), 255, 255, 255);
    // Step 3 keeps its own size: 300 × 200, centred.
    final third = decoded.frames[2];
    near(third.getPixel(320, 450), 30, 160, 70);
    near(third.getPixel(100, 450), 255, 255, 255);
  });

  test('without captions the frames are the pictures alone', () async {
    final layout = GuideGifLayout.of(sizes(), maxWidth: 480, captions: false);
    final gif = await buildGuideGif(
      [for (final p in pictures) GuideGifFrame(p)],
      layout,
      frameMs: 500,
    );
    final decoded = img.decodeGif(gif)!;
    expect(decoded.height, layout.pictureHeight);
    expect(decoded.frames.first.frameDuration, 500);
  });

  test('checks timing, caption bars and stops when cancelled', () async {
    final layout = GuideGifLayout.of(sizes(), maxWidth: 480);
    final frames = [
      for (final p in pictures)
        GuideGifFrame(p, caption: bar(layout.width, layout.captionHeight)),
    ];
    for (final ms in [400, 10010, 1505]) {
      await expectLater(
        buildGuideGif(frames, layout, frameMs: ms),
        throwsFormatException,
      );
    }
    await expectLater(
      buildGuideGif(
        [GuideGifFrame(pictures[0], caption: bar(100, 20))],
        layout,
        frameMs: 1000,
      ),
      throwsFormatException,
    );
    await expectLater(
      buildGuideGif([GuideGifFrame(pictures[0])], layout, frameMs: 1000),
      throwsFormatException,
    );
    final token = CancellationToken();
    await expectLater(
      buildGuideGif(
        frames,
        layout,
        frameMs: 1000,
        cancellation: token,
        progress: (done, _) {
          if (done == 1) token.cancel();
        },
      ),
      throwsA(isA<Cancelled>()),
    );
  });
}
