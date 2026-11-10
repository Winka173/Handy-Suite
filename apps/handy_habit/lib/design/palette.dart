import 'package:handy_ui/kit.dart';

/// Habit owns both themes. Colour belongs to progress and personal identities;
/// the editorial anchor is oxblood, never a sibling app's header band.
@immutable
class HabitPalette extends ThemeExtension<HabitPalette> {
  final Color canvas, surface, raised, ink, muted, line, control;
  final Color anchor, onAnchor, vermilion, onVermilion, tint, ochre, ochreField;
  const HabitPalette({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.line,
    required this.control,
    required this.anchor,
    required this.onAnchor,
    required this.vermilion,
    required this.onVermilion,
    required this.tint,
    required this.ochre,
    required this.ochreField,
  });

  static const light = HabitPalette(
    canvas: Color(0xFFFAF7F2),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFF1E9DF),
    ink: Color(0xFF291C19),
    muted: Color(0xFF66534C),
    line: Color(0xFFE4D8CD),
    control: Color(0xFF927D70),
    anchor: Color(0xFF54261F),
    onAnchor: Color(0xFFFFF5ED),
    vermilion: Color(0xFFB42318),
    onVermilion: Color(0xFFFFFFFF),
    tint: Color(0xFFF9E4DC),
    ochre: Color(0xFF805500),
    ochreField: Color(0xFFF5EBCF),
  );
  static const dark = HabitPalette(
    canvas: Color(0xFF151312),
    surface: Color(0xFF211D1B),
    raised: Color(0xFF302824),
    ink: Color(0xFFFFF5ED),
    muted: Color(0xFFCCB9AC),
    line: Color(0xFF483B34),
    control: Color(0xFF9B877A),
    anchor: Color(0xFFF1C5AF),
    onAnchor: Color(0xFF54261F),
    vermilion: Color(0xFFF07755),
    onVermilion: Color(0xFF32150D),
    tint: Color(0xFF42271F),
    ochre: Color(0xFFE6BE70),
    ochreField: Color(0xFF382D18),
  );
  static HabitPalette of(BuildContext context) =>
      Theme.of(context).extension<HabitPalette>()!;
  @override
  HabitPalette copyWith() => this;
  @override
  HabitPalette lerp(HabitPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}
