import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as img;
import 'images.dart';

/// Screenshots joined into one long picture, and how they were joined.
class StitchResult {
  final Uint8List png;
  final int width, height;

  /// Rows shared by each shot and the one before it; 0 where no overlap
  /// was found and the shot was simply added below.
  final List<int> overlaps;

  /// The bars that stay put while the page scrolls (status bar and title
  /// on top, navigation below), kept once.
  final int header, footer;
  const StitchResult(
    this.png,
    this.width,
    this.height,
    this.overlaps,
    this.header,
    this.footer,
  );
}

const _samples = 64;

/// Each row as [_samples] grey values across it.
List<Uint8List> _rows(img.Image image) {
  final out = <Uint8List>[];
  for (var y = 0; y < image.height; y++) {
    final row = Uint8List(_samples);
    for (var i = 0; i < _samples; i++) {
      final p = image.getPixel(((i + .5) * image.width / _samples).floor(), y);
      row[i] = ((p.r * 299 + p.g * 587 + p.b * 114) ~/ 1000).toInt();
    }
    out.add(row);
  }
  return out;
}

int _distance(Uint8List a, Uint8List b) {
  var sum = 0;
  for (var i = 0; i < _samples; i++) {
    sum += (a[i] - b[i]).abs();
  }
  return sum ~/ _samples;
}

/// A row with something on it, not a flat run of one colour.
bool _busy(Uint8List row) {
  var low = 255, high = 0;
  for (final v in row) {
    if (v < low) low = v;
    if (v > high) high = v;
  }
  return high - low > 24;
}

/// Rows equal from the top (or bottom) in every shot: the fixed bars.
int _fixed(List<List<Uint8List>> shots, {required bool top}) {
  final height = shots.map((s) => s.length).reduce((a, b) => a < b ? a : b);
  var n = 0;
  while (n < height * .4) {
    final y = top ? n : null;
    final first = shots.first[y ?? shots.first.length - 1 - n];
    if (shots.any((s) => _distance(s[y ?? s.length - 1 - n], first) > 1)) break;
    n++;
  }
  return n;
}

/// The most rows at the end of [a] that repeat at the start of [b], or 0.
int _overlap(List<Uint8List> a, List<Uint8List> b) {
  final most = (a.length < b.length ? a.length : b.length) - 1;
  for (var k = most; k >= 16; k--) {
    var busy = 0, ok = true;
    for (var i = 0; i < k; i += 3) {
      final ra = a[a.length - k + i], rb = b[i];
      if (_distance(ra, rb) > 3) {
        ok = false;
        break;
      }
      if (_busy(ra)) busy++;
    }
    // A match made only of blank rows says nothing about where it is.
    if (ok && busy >= 4) return k;
  }
  return 0;
}

/// Joins [shots] of one scrolling page, taken top to bottom, into one
/// picture: the fixed bars once, each shot's new rows below the last.
/// Shots must share a width. The result stays under 16 million pixels.
Future<StitchResult> stitchScreenshots(
  List<Uint8List> shots, {
  CancellationToken? cancellation,
}) async {
  if (shots.length < 2 || shots.length > 20)
    throw const FormatException(
      'Choose 2 to 20 screenshots / Chọn từ 2 đến 20 ảnh chụp màn hình',
    );
  final images = <img.Image>[];
  for (final bytes in shots) {
    cancellation?.check();
    images.add(mediaBitmap(bytes));
    await Future<void>.delayed(Duration.zero);
  }
  final width = images.first.width;
  if (images.any((i) => i.width != width))
    throw const FormatException(
      'Screenshots must be the same width / Các ảnh phải cùng chiều rộng',
    );
  final rows = <List<Uint8List>>[];
  for (final i in images) {
    cancellation?.check();
    rows.add(_rows(i));
    await Future<void>.delayed(Duration.zero);
  }
  final header = _fixed(rows, top: true), footer = _fixed(rows, top: false);
  final scroll = [for (final r in rows) r.sublist(header, r.length - footer)];
  final overlaps = <int>[];
  var height = header + footer + scroll.first.length;
  for (var i = 1; i < scroll.length; i++) {
    cancellation?.check();
    final k = _overlap(scroll[i - 1], scroll[i]);
    overlaps.add(k);
    height += scroll[i].length - k;
    await Future<void>.delayed(Duration.zero);
  }
  if (width * height > 16000000)
    throw const FormatException(
      'The joined picture would be over 16 million pixels / Ảnh ghép sẽ vượt 16 triệu điểm ảnh',
    );
  final out = img.Image(width: width, height: height, numChannels: 4);
  var y = 0;
  void copy(img.Image from, int top, int count) {
    if (count <= 0) return;
    img.compositeImage(
      out,
      img.copyCrop(from, x: 0, y: top, width: width, height: count),
      dstY: y,
    );
    y += count;
  }

  copy(images.first, 0, header + scroll.first.length);
  for (var i = 1; i < images.length; i++) {
    copy(
      images[i],
      header + overlaps[i - 1],
      scroll[i].length - overlaps[i - 1],
    );
  }
  copy(images.last, images.last.height - footer, footer);
  cancellation?.check();
  return StitchResult(mediaPng(out), width, height, overlaps, header, footer);
}
