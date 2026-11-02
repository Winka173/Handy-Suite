import 'dart:math' as math;
import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as img;
import 'guide.dart';
import 'images.dart';

/// The widths a guide GIF may have, in pixels.
const guideGifWidths = [480, 640, 800, 960];

/// How long each step stays on screen, in milliseconds.
const guideGifFrameMs = (min: 500, max: 10000);

/// The tallest frame, caption included, in pixels.
const guideGifMaxHeight = 1600;

/// All frames together may hold at most this many pixels.
const guideGifMaxPixels = 48000000;

/// The finished file may be at most this big.
const guideGifMaxBytes = 20000000;

/// One GIF frame per step, at most.
const guideGifMaxFrames = 100;

/// How every frame of a guide GIF is laid out: one width for all, the
/// pictures centred in a box of [pictureHeight], and an optional caption
/// bar of [captionHeight] under each.
class GuideGifLayout {
  final int width, pictureHeight, captionHeight;
  const GuideGifLayout._(this.width, this.pictureHeight, this.captionHeight);
  int get height => pictureHeight + captionHeight;

  /// The layout for pictures of [sizes], no wider than [maxWidth]. Small
  /// pictures are never enlarged; a very tall one is shrunk to fit.
  factory GuideGifLayout.of(
    List<({int width, int height})> sizes, {
    required int maxWidth,
    bool captions = true,
  }) {
    if (sizes.isEmpty || sizes.length > guideGifMaxFrames) {
      throw const FormatException('A GIF needs 1 to 100 steps');
    }
    if (!guideGifWidths.contains(maxWidth)) {
      throw const FormatException('GIF width: 480, 640, 800 or 960 px');
    }
    if (sizes.any((s) => s.width < 1 || s.height < 1)) {
      throw const FormatException('Every step needs a picture');
    }
    final width = math.min(
      maxWidth,
      sizes.map((s) => s.width).reduce(math.max),
    );
    final caption = captions ? (width * .1).round().clamp(44, 96) : 0;
    final tallest = sizes
        .map((s) => (s.height * math.min(1, width / s.width)).ceil())
        .reduce(math.max);
    final picture = math.max(1, math.min(tallest, guideGifMaxHeight - caption));
    final layout = GuideGifLayout._(width, picture, caption);
    if (layout.width * layout.height * sizes.length > guideGifMaxPixels) {
      throw const FormatException(
        'This GIF would be over 48M pixels; choose a smaller width or split the guide',
      );
    }
    return layout;
  }
}

/// One step of the GIF: its flattened picture and, when the layout has a
/// caption bar, that bar already drawn as a PNG of exactly
/// `layout.width` × `layout.captionHeight`.
class GuideGifFrame {
  final GuideRaster picture;
  final Uint8List? caption;
  const GuideGifFrame(this.picture, {this.caption});
}

/// An animated GIF, one frame per step, looping. Each frame gets its own
/// 256-colour palette (octree quantization, no dithering, so text in
/// screenshots stays crisp). Pictures are only the flattened rasters the
/// caller passes in, so masks are already painted over.
Future<Uint8List> buildGuideGif(
  List<GuideGifFrame> frames,
  GuideGifLayout layout, {
  required int frameMs,
  CancellationToken? cancellation,
  void Function(int done, int of)? progress,
}) async {
  if (frames.isEmpty || frames.length > guideGifMaxFrames) {
    throw const FormatException('A GIF needs 1 to 100 steps');
  }
  if (frameMs < guideGifFrameMs.min ||
      frameMs > guideGifFrameMs.max ||
      frameMs % 10 != 0) {
    throw const FormatException('Time per step: 0.5 to 10 seconds');
  }
  if (layout.width * layout.height * frames.length > guideGifMaxPixels) {
    throw const FormatException(
      'This GIF would be over 48M pixels; choose a smaller width or split the guide',
    );
  }
  final encoder = img.GifEncoder(
    repeat: 0,
    quantizerType: img.QuantizerType.octree,
    dither: img.DitherKernel.none,
  );
  for (final (i, frame) in frames.indexed) {
    progress?.call(i, frames.length);
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    encoder.addFrame(_frame(frame, layout), duration: frameMs ~/ 10);
  }
  progress?.call(frames.length, frames.length);
  await Future<void>.delayed(Duration.zero);
  cancellation?.check();
  final bytes = encoder.finish();
  cancellation?.check();
  if (bytes == null) throw const FormatException('The GIF could not be made');
  if (bytes.length > guideGifMaxBytes) {
    throw const FormatException(
      'The GIF is over 20 MB; choose a smaller width or split the guide',
    );
  }
  return bytes;
}

img.Image _frame(GuideGifFrame frame, GuideGifLayout layout) {
  final canvas = img.Image(width: layout.width, height: layout.height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final source = mediaBitmap(frame.picture.png);
  final scale = math.min(
    1.0,
    math.min(layout.width / source.width, layout.pictureHeight / source.height),
  );
  final w = math.max(1, (source.width * scale).round()),
      h = math.max(1, (source.height * scale).round());
  final picture = scale == 1
      ? source
      : img.copyResize(
          source,
          width: w,
          height: h,
          interpolation: img.Interpolation.average,
        );
  img.compositeImage(
    canvas,
    picture,
    dstX: (layout.width - w) ~/ 2,
    dstY: (layout.pictureHeight - h) ~/ 2,
  );
  if (layout.captionHeight > 0) {
    final png = frame.caption;
    if (png == null) {
      throw const FormatException('Every frame needs its caption');
    }
    final caption = mediaBitmap(png);
    if (caption.width != layout.width ||
        caption.height != layout.captionHeight) {
      throw const FormatException('Caption bar does not fit the GIF');
    }
    img.compositeImage(canvas, caption, dstY: layout.pictureHeight);
  }
  return canvas;
}
