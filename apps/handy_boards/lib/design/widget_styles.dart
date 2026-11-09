import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';

/// A home-screen widget style: the ground, the text, the quieter text and
/// the accent (dot and bar). Ink reads at 7:1 or more on its ground, the
/// quieter text at 4.5:1 or more. "From the phone" keeps the widget's own
/// light/dark colours. Ids are stored: never rename one.
@immutable
class WidgetStyle {
  final String id, nameEn, nameVi;
  final bool pro;
  final Color? bg, ink, muted, accent;
  const WidgetStyle(
    this.id,
    this.nameEn,
    this.nameVi, {
    this.pro = true,
    this.bg,
    this.ink,
    this.muted,
    this.accent,
  });

  String _hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0');

  /// What the native widget gets, or null for the phone's own colours.
  Map<String, String>? get native => bg == null
      ? null
      : {
          'bg': _hex(bg!),
          'ink': _hex(ink!),
          'muted': _hex(muted!),
          'accent': _hex(accent!),
        };
}

const widgetStyles = <WidgetStyle>[
  WidgetStyle('system', 'From the phone', 'Theo máy', pro: false),
  WidgetStyle(
    'light',
    'Light',
    'Sáng',
    pro: false,
    bg: Color(0xFFFFFFFF),
    ink: Color(0xFF1F2329),
    muted: Color(0xFF555B66),
    accent: Color(0xFFB53C0A),
  ),
  WidgetStyle(
    'dark',
    'Dark',
    'Tối',
    pro: false,
    bg: Color(0xFF1C1B1F),
    ink: Color(0xFFF2F0F4),
    muted: Color(0xFFB4B0BA),
    accent: Color(0xFFE58BD3),
  ),
  WidgetStyle(
    'linen',
    'Linen',
    'Vải lanh',
    bg: Color(0xFFF1ECE3),
    ink: Color(0xFF2A251E),
    muted: Color(0xFF665B4C),
    accent: Color(0xFF9A5B2A),
  ),
  WidgetStyle(
    'meadow',
    'Meadow',
    'Đồng cỏ',
    bg: Color(0xFFEDF2E9),
    ink: Color(0xFF1E2A1C),
    muted: Color(0xFF52604C),
    accent: Color(0xFF3F7A35),
  ),
  WidgetStyle(
    'terracotta',
    'Terracotta',
    'Gạch nung',
    bg: Color(0xFFF6E9E1),
    ink: Color(0xFF2E1E17),
    muted: Color(0xFF6B4F43),
    accent: Color(0xFFB4532A),
  ),
  WidgetStyle(
    'harbor',
    'Harbor',
    'Bến cảng',
    bg: Color(0xFF0F2A2E),
    ink: Color(0xFFEAF4F4),
    muted: Color(0xFFA9C4C5),
    accent: Color(0xFF5FC8C2),
  ),
  WidgetStyle(
    'dusk',
    'Dusk',
    'Hoàng hôn tím',
    bg: Color(0xFF241D2C),
    ink: Color(0xFFF1EAF6),
    muted: Color(0xFFBDAFC8),
    accent: Color(0xFFE29BD6),
  ),
  WidgetStyle(
    'night',
    'Night sky',
    'Trời đêm',
    bg: Color(0xFF0F1420),
    ink: Color(0xFFE8ECF5),
    muted: Color(0xFFA6B0C6),
    accent: Color(0xFF6FB3E0),
  ),
];

WidgetStyle widgetStyleById(String? id) =>
    widgetStyles.where((w) => w.id == id).firstOrNull ?? widgetStyles.first;

/// The style in use: a Pro style shows only while Pro is verified; without
/// it the widgets fall back to the phone's colours and the choice is kept.
WidgetStyle widgetStyleOf(BoardsState s, {required bool pro}) {
  final chosen = widgetStyleById(s.preferences['widgetStyle'] as String?);
  return chosen.pro && !pro ? widgetStyles.first : chosen;
}
