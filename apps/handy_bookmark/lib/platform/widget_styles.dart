import 'package:handy_ui/kit.dart';

/// A home-screen widget style: ground, text, quieter text and the accent
/// (the dot). Ink reads at 7:1 or more on its ground, the quieter text at
/// 4.5:1 or more. "From the phone" keeps the widget's own light or dark
/// colours. Ids are stored: never rename one.
@immutable
class BookmarkWidgetStyle {
  final String id, en, vi;
  final bool pro;
  final Color? bg, ink, muted, accent;
  const BookmarkWidgetStyle(
    this.id,
    this.en,
    this.vi, {
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

const bookmarkWidgetStyles = <BookmarkWidgetStyle>[
  BookmarkWidgetStyle('system', 'From the phone', 'Theo máy', pro: false),
  BookmarkWidgetStyle(
    'light',
    'Light',
    'Sáng',
    pro: false,
    bg: Color(0xFFFFFFFF),
    ink: Color(0xFF1C2024),
    muted: Color(0xFF545B63),
    accent: Color(0xFF0E7490),
  ),
  BookmarkWidgetStyle(
    'dark',
    'Dark',
    'Tối',
    pro: false,
    bg: Color(0xFF1A1C1E),
    ink: Color(0xFFF1F3F4),
    muted: Color(0xFFB2B8BE),
    accent: Color(0xFF7CC8D8),
  ),
  BookmarkWidgetStyle(
    'paper',
    'Library paper',
    'Giấy thư viện',
    bg: Color(0xFFF4EFE6),
    ink: Color(0xFF2B2620),
    muted: Color(0xFF675D50),
    accent: Color(0xFF8A5A2B),
  ),
  BookmarkWidgetStyle(
    'reading-room',
    'Reading room',
    'Phòng đọc',
    bg: Color(0xFF1F2A24),
    ink: Color(0xFFEFF3EE),
    muted: Color(0xFFB0C0B4),
    accent: Color(0xFF8FCB9B),
  ),
  BookmarkWidgetStyle(
    'ink-blue',
    'Ink blue',
    'Mực xanh',
    bg: Color(0xFF13202E),
    ink: Color(0xFFE9EEF5),
    muted: Color(0xFFA9B6C6),
    accent: Color(0xFF7DB8E8),
  ),
  BookmarkWidgetStyle(
    'linen',
    'Linen',
    'Vải lanh',
    bg: Color(0xFFF2EEE8),
    ink: Color(0xFF26231F),
    muted: Color(0xFF615A52),
    accent: Color(0xFF9C4F3C),
  ),
  BookmarkWidgetStyle(
    'sage',
    'Sage',
    'Lá xô thơm',
    bg: Color(0xFFEAF0E8),
    ink: Color(0xFF1D2A1F),
    muted: Color(0xFF4F5F52),
    accent: Color(0xFF3E7A4E),
  ),
  BookmarkWidgetStyle(
    'night',
    'Night',
    'Đêm',
    bg: Color(0xFF000000),
    ink: Color(0xFFFFFFFF),
    muted: Color(0xFFB4B4B4),
    accent: Color(0xFFE0B26A),
  ),
];

BookmarkWidgetStyle bookmarkWidgetStyleById(String? id) =>
    bookmarkWidgetStyles.where((w) => w.id == id).firstOrNull ??
    bookmarkWidgetStyles.first;

/// The style in use: a Pro style shows only while Pro is verified; without
/// it the widgets fall back to the phone's colours and the choice is kept.
BookmarkWidgetStyle bookmarkWidgetStyleOf(
  Map<String, dynamic> prefs, {
  required bool pro,
}) {
  final chosen = bookmarkWidgetStyleById(prefs['widgetStyle'] as String?);
  return chosen.pro && !pro ? bookmarkWidgetStyles.first : chosen;
}
