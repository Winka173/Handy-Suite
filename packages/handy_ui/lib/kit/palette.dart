import 'package:flutter/material.dart';
import 'theme.dart';

/// One identity colour: [mark] for a dot or an edge, [tint] for a small
/// pale area behind neutral text.
@immutable
class HandyHue {
  final Color mark, tint;
  const HandyHue(this.mark, this.tint);
}

/// The suite's eight identity colours for the person's own things: a
/// collection, a place, a deck, a folder, a guide. The app's own colour
/// stays on its primary action and selection; text stays in neutral ink.
///
/// Neighbouring indices sit about 60° or more apart on the colour wheel, so
/// things listed together never share a look. No violet or indigo.
abstract final class HandyPalette {
  static const count = 8;

  // Blue first and tomato late: a red first group would read as overdue.
  static const _marks = [
    Color(0xFF3A6FD8), // blue 220°
    Color(0xFFD9930B), // amber 42°
    Color(0xFF3E9A4B), // leaf 128°
    Color(0xFFD6457A), // rose 338°
    Color(0xFF1F9E8F), // teal 173°
    Color(0xFFDC4A33), // tomato 8°
    Color(0xFF2B8CC4), // sky 202°
    Color(0xFF889A24), // olive 68°
  ];

  /// The colour at [index], for this theme's brightness. Colours within
  /// 25° of the app's own are left out (always at least the nearest one),
  /// so a thing's colour never reads as the app's action colour; the six
  /// or seven left are used in order.
  static HandyHue of(BuildContext context, int index) {
    final theme = Theme.of(context);
    final own = HSVColor.fromColor(
      theme.extension<HandyColors>()?.accent ?? theme.colorScheme.primary,
    ).hue;
    double gap(Color c) {
      final d = (HSVColor.fromColor(c).hue - own).abs() % 360;
      return d > 180 ? 360 - d : d;
    }

    var nearest = _marks.first;
    for (final c in _marks) {
      if (gap(c) < gap(nearest)) nearest = c;
    }
    final usable = [
      for (final c in _marks)
        if (c != nearest && gap(c) >= 25) c,
    ];
    final mark = usable[index % usable.length];
    final dark = theme.brightness == Brightness.dark;
    final ground =
        theme.extension<HandyColors>()?.raised ?? theme.colorScheme.surface;
    return dark
        ? HandyHue(
            Color.lerp(mark, Colors.white, .18)!,
            Color.lerp(ground, mark, .22)!,
          )
        : HandyHue(_legible(mark), Color.lerp(Colors.white, mark, .14)!);
  }

  /// A light theme's mark, taken just deep enough to stand 3:1 against a
  /// white or tinted pale ground (WCAG non-text contrast): amber and olive
  /// darken a little, the others are already there.
  static Color _legible(Color mark) {
    double ratio(Color c) => 1.05 / (c.computeLuminance() + .05);
    var c = mark;
    for (var t = .05; ratio(c) < 3.45 && t < .6; t += .05) {
      c = Color.lerp(mark, Colors.black, t)!;
    }
    return c;
  }

  /// A stable index for something with no order of its own.
  static int forKey(String key) {
    var h = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return h % count;
  }
}

/// A small filled circle in an identity colour. Purely a cue: the name
/// beside it says what it is.
class HandyDot extends StatelessWidget {
  final int index;
  final double size;
  const HandyDot(this.index, {super.key, this.size = 10});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HandyPalette.of(context, index).mark,
        shape: BoxShape.circle,
      ),
    ),
  );
}
