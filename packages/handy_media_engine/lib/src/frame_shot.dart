import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// How a screenshot is framed for sharing. Sizes are given for a picture
/// 1080 px wide and scale with the real width, so a small preview and the
/// full export look the same.
class ShotFrame {
  /// ARGB fill around the shot; null takes the shot's own average colour.
  final int? background;

  /// Space around the shot, as a share of its shorter side (0-0.25).
  final double padding;

  /// Corner radius in px at 1080 wide (0-48).
  final double radius;
  final bool shadow;

  /// `none`, `phone` (a dark body around the screen) or `browser` (a flat
  /// bar with three dots above it).
  final String device;
  const ShotFrame({
    this.background = 0xFFF2F2F2,
    this.padding = 0.08,
    this.radius = 24,
    this.shadow = true,
    this.device = 'none',
  });

  /// A transparent ground (only the shot and its frame are drawn).
  static const transparent = 0x00000000;
}

/// Most pixels a framed picture may have.
const frameShotMaxPixels = 16000000;

/// The shot's average colour, opaque, as ARGB.
int averageColour(img.Image image) {
  var r = 0, g = 0, b = 0, n = 0;
  final step = math.max(1, (image.width * image.height / 40000).floor());
  var i = 0;
  for (final p in image) {
    if (i++ % step != 0) continue;
    r += p.r.toInt();
    g += p.g.toInt();
    b += p.b.toInt();
    n++;
  }
  if (n == 0) return 0xFFFFFFFF;
  return 0xFF000000 | (r ~/ n) << 16 | (g ~/ n) << 8 | (b ~/ n);
}

img.Color _c(int argb) => img.ColorRgba8(
  argb >> 16 & 0xFF,
  argb >> 8 & 0xFF,
  argb & 0xFF,
  argb >> 24 & 0xFF,
);

/// Clears the pixels of [image] outside rounded corners of [r] px; [top]
/// and [bottom] choose which corners.
void _roundCorners(
  img.Image image,
  int r, {
  bool top = true,
  bool bottom = true,
}) {
  if (r <= 0) return;
  r = math.min(r, math.min(image.width, image.height) ~/ 2);
  void corner(int cx, int cy, int xs, int ys) {
    for (var dy = 0; dy < r; dy++) {
      for (var dx = 0; dx < r; dx++) {
        final x = xs + dx, y = ys + dy;
        final ex = x + .5 - cx, ey = y + .5 - cy;
        final d = math.sqrt(ex * ex + ey * ey) - r;
        if (d <= -1) continue;
        final p = image.getPixel(x, y);
        final keep = d >= 0 ? 0.0 : -d;
        p.a = (p.a * keep).round();
      }
    }
  }

  final w = image.width, h = image.height;
  if (top) {
    corner(r, r, 0, 0);
    corner(w - r, r, w - r, 0);
  }
  if (bottom) {
    corner(r, h - r, 0, h - r);
    corner(w - r, h - r, w - r, h - r);
  }
}

/// [source] (PNG/JPEG/WebP) framed for sharing, as PNG.
Uint8List frameScreenshot(Uint8List source, ShotFrame frame) {
  final shot = img.decodeImage(source);
  if (shot == null) throw const FormatException('Not a picture we can read');
  if (frame.padding < 0 ||
      frame.padding > 0.25 ||
      frame.radius < 0 ||
      frame.radius > 48) {
    throw const FormatException('Frame settings out of range');
  }
  if (!const {'none', 'phone', 'browser'}.contains(frame.device)) {
    throw const FormatException('Unknown frame');
  }
  final unit = shot.width / 1080;
  final radius = (frame.radius * unit).round();
  final pad = (math.min(shot.width, shot.height) * frame.padding).round();
  final bezel = frame.device == 'phone' ? math.max(6, (28 * unit).round()) : 0;
  final bar = frame.device == 'browser' ? math.max(20, (72 * unit).round()) : 0;
  final bodyW = shot.width + 2 * bezel, bodyH = shot.height + 2 * bezel + bar;
  final w = bodyW + 2 * pad, h = bodyH + 2 * pad;
  if (w * h > frameShotMaxPixels) {
    throw const FormatException('The framed picture would exceed 16 Mpx');
  }
  final ground = frame.background ?? averageColour(shot);
  final out = img.Image(width: w, height: h, numChannels: 4)..clear(_c(ground));
  final bodyRadius = frame.device == 'phone' ? radius + bezel : radius;

  if (frame.shadow && pad > 0) {
    // A soft shadow: thin translucent rounded rectangles, each a little
    // larger, so darkness builds towards the shot and fades outwards. The
    // layers add up to at most about 22% black under the edge.
    final spread = math.max(2, (pad * .5).round()),
        drop = (spread * .35).round();
    final layers = math.min(spread, 16), alpha = math.max(1, 56 ~/ layers);
    for (var k = layers; k >= 1; k--) {
      final i = (spread * k / layers).round();
      img.fillRect(
        out,
        x1: pad - i,
        y1: pad - i + drop,
        x2: pad + bodyW + i - 1,
        y2: pad + bodyH + i - 1 + drop,
        color: img.ColorRgba8(0, 0, 0, alpha),
        radius: bodyRadius + i,
      );
    }
  }

  if (frame.device == 'phone') {
    img.fillRect(
      out,
      x1: pad,
      y1: pad,
      x2: pad + bodyW - 1,
      y2: pad + bodyH - 1,
      color: img.ColorRgba8(17, 17, 17, 255),
      radius: bodyRadius,
    );
  } else if (frame.device == 'browser') {
    final barColour = img.ColorRgba8(232, 232, 232, 255);
    img.fillRect(
      out,
      x1: pad,
      y1: pad,
      x2: pad + bodyW - 1,
      y2: pad + bar + radius,
      color: barColour,
      radius: radius,
    );
    img.fillRect(
      out,
      x1: pad,
      y1: pad + bar ~/ 2,
      x2: pad + bodyW - 1,
      y2: pad + bar - 1,
      color: barColour,
    );
    final dot = math.max(3, bar ~/ 7);
    for (final (i, rgb) in const [
      (0, (237, 106, 94)),
      (1, (245, 191, 79)),
      (2, (98, 197, 84)),
    ].indexed) {
      img.fillCircle(
        out,
        x: pad + bar ~/ 2 + i * dot * 3,
        y: pad + bar ~/ 2,
        radius: dot,
        color: img.ColorRgba8(rgb.$2.$1, rgb.$2.$2, rgb.$2.$3, 255),
        antialias: true,
      );
    }
  }

  final screen = shot.convert(numChannels: 4);
  _roundCorners(screen, radius, top: frame.device != 'browser');
  img.compositeImage(out, screen, dstX: pad + bezel, dstY: pad + bezel + bar);
  return Uint8List.fromList(img.encodePng(out));
}

/// [source] shrunk to at most [maxWidth] px wide (as PNG), for a quick
/// preview that frames the same way as the full picture.
Uint8List framePreviewSource(Uint8List source, {int maxWidth = 900}) {
  final shot = img.decodeImage(source);
  if (shot == null) throw const FormatException('Not a picture we can read');
  final small = shot.width <= maxWidth
      ? shot
      : img.copyResize(
          shot,
          width: maxWidth,
          interpolation: img.Interpolation.average,
        );
  return Uint8List.fromList(img.encodePng(small));
}
