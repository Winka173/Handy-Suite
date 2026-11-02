part of '../handy_card_engine.dart';

/// A guide drawn while snapping: a vertical line at x (or horizontal at y)
/// across [from]..[to].
class SnapGuide {
  final bool vertical;
  final double at, from, to;
  const SnapGuide(this.vertical, this.at, this.from, this.to);
}

class SnapOptions {
  final bool toCard, toObjects, toGrid, toSafe;
  final double grid;
  const SnapOptions({
    this.toCard = true,
    this.toObjects = true,
    this.toGrid = false,
    this.toSafe = true,
    this.grid = 8,
  });
}

/// Where a box being moved by [delta] lands once snapped: its left,
/// centre or right (top, middle, bottom) meets a card edge, the card
/// centre, the safe margin, another element's edge or centre, or the grid,
/// when within [threshold] (page units: screen pixels divided by zoom).
({Vec delta, List<SnapGuide> guides}) snapMove(
  CardDocument doc,
  List<CardElement> elements,
  Set<String> moving,
  Box start,
  Vec delta, {
  required double threshold,
  SnapOptions options = const SnapOptions(),
}) {
  final moved = Box(
    start.x + delta.x,
    start.y + delta.y,
    start.width,
    start.height,
  );
  final xs = <double>[], ys = <double>[];
  final others = <Box>[];
  if (options.toCard) {
    xs.addAll([0, doc.width / 2, doc.width]);
    ys.addAll([0, doc.height / 2, doc.height]);
  }
  if (options.toSafe && doc.safe > 0) {
    xs.addAll([doc.safe, doc.width - doc.safe]);
    ys.addAll([doc.safe, doc.height - doc.safe]);
  }
  if (options.toObjects) {
    for (final e in elements) {
      if (moving.contains(e.id) || !e.visible) continue;
      final b = e.frame.bounds();
      others.add(b);
      xs.addAll([b.x, b.center.x, b.right]);
      ys.addAll([b.y, b.center.y, b.bottom]);
    }
  }
  (double, double?) best(List<double> own, List<double> targets, double grid) {
    double? hit;
    var shift = 0.0, distance = threshold;
    for (final o in own) {
      for (final t in targets) {
        if ((t - o).abs() <= distance) {
          distance = (t - o).abs();
          shift = t - o;
          hit = t;
        }
      }
      if (grid > 0) {
        final g = (o / grid).roundToDouble() * grid;
        if ((g - o).abs() < distance) {
          distance = (g - o).abs();
          shift = g - o;
          hit = null;
        }
      }
    }
    return (shift, hit);
  }

  final grid = options.toGrid ? options.grid : 0.0;
  final (dx, hx) = best([moved.x, moved.center.x, moved.right], xs, grid);
  final (dy, hy) = best([moved.y, moved.center.y, moved.bottom], ys, grid);
  final snapped = Box(moved.x + dx, moved.y + dy, moved.width, moved.height);
  final guides = <SnapGuide>[];
  if (hx != null) {
    final span = [snapped, ...others.where((b) => _near(b, hx, true))];
    guides.add(
      SnapGuide(
        true,
        hx,
        math.min(0, span.map((b) => b.y).reduce(math.min)),
        math.max(doc.height, span.map((b) => b.bottom).reduce(math.max)),
      ),
    );
  }
  if (hy != null) {
    final span = [snapped, ...others.where((b) => _near(b, hy, false))];
    guides.add(
      SnapGuide(
        false,
        hy,
        math.min(0, span.map((b) => b.x).reduce(math.min)),
        math.max(doc.width, span.map((b) => b.right).reduce(math.max)),
      ),
    );
  }
  return (delta: Vec(delta.x + dx, delta.y + dy), guides: guides);
}

bool _near(Box b, double at, bool vertical) {
  final values = vertical
      ? [b.x, b.center.x, b.right]
      : [b.y, b.center.y, b.bottom];
  return values.any((v) => (v - at).abs() < 0.01);
}

/// An angle snapped to 15° steps when within [within] degrees of one.
double snapAngle(double degrees, {double within = 4}) {
  final step = (degrees / 15).roundToDouble() * 15;
  return (degrees - step).abs() <= within ? step : degrees;
}
