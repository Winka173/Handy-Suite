import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../covers/cover_art.dart';
import '../ui/look.dart';
import 'theme.dart';

/// A board's look: the page ground and the column fill, light and dark.
/// Cards stay on the theme's surface, so text always reads the same.
@immutable
class BoardLook {
  final String id, nameEn, nameVi;
  final bool pro;
  final Color? lightPage, lightColumn, darkPage, darkColumn;
  const BoardLook(
    this.id,
    this.nameEn,
    this.nameVi, {
    this.pro = true,
    this.lightPage,
    this.lightColumn,
    this.darkPage,
    this.darkColumn,
  });

  Color page(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return (dark ? darkPage : lightPage) ?? BoardsPalette.of(context).canvas;
  }

  Color column(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return (dark ? darkColumn : lightColumn) ??
        BoardsPalette.of(context).raised;
  }
}

/// Every look, the free default first. Ids are stored on boards: never
/// rename one; an unknown id falls back to the default.
const boardLooks = <BoardLook>[
  BoardLook('default', 'From the cover', 'Theo ảnh bìa', pro: false),
  BoardLook(
    'linen',
    'Linen',
    'Vải lanh',
    lightPage: Color(0xFFF1ECE3),
    lightColumn: Color(0xFFE5DCCD),
    darkPage: Color(0xFF1D1A16),
    darkColumn: Color(0xFF29251F),
  ),
  BoardLook(
    'blueprint',
    'Blueprint',
    'Bản vẽ',
    lightPage: Color(0xFFE9EFF5),
    lightColumn: Color(0xFFD9E3EE),
    darkPage: Color(0xFF131A21),
    darkColumn: Color(0xFF1D2732),
  ),
  BoardLook(
    'meadow',
    'Meadow',
    'Đồng cỏ',
    lightPage: Color(0xFFEDF2E9),
    lightColumn: Color(0xFFDDE7D7),
    darkPage: Color(0xFF151B15),
    darkColumn: Color(0xFF202A1F),
  ),
  BoardLook(
    'blush',
    'Blush',
    'Phấn hồng',
    lightPage: Color(0xFFF7ECEF),
    lightColumn: Color(0xFFEEDBE1),
    darkPage: Color(0xFF1E1619),
    darkColumn: Color(0xFF2C2025),
  ),
  BoardLook(
    'sand',
    'Sand',
    'Cát',
    lightPage: Color(0xFFF4EEE3),
    lightColumn: Color(0xFFE9DECB),
    darkPage: Color(0xFF1C1813),
    darkColumn: Color(0xFF29231A),
  ),
];

BoardLook lookById(String? id) =>
    boardLooks.where((l) => l.id == id).firstOrNull ?? boardLooks.first;

/// The colours a board is drawn on. By default they come from its cover:
/// a pale wash of the cover's tone in light, a deep one in dark, so every
/// board looks like itself. A chosen look (Pro) replaces them.
class BoardGround {
  final Color page, column, band;
  const BoardGround(this.page, this.column, this.band);
}

BoardGround boardGround(
  BuildContext context,
  BoardRecord board, {
  String? look,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final chosen = lookById(look ?? board.data['appearance'] as String?);
  if (chosen.id != 'default')
    return BoardGround(
      chosen.page(context),
      chosen.column(context),
      chosen.column(context),
    );
  final tone = HSLColor.fromColor(coverTone(boardCoverId(board)));
  // Clamped so ink on it always reads (≥ 4.5:1 for the muted grey).
  final page = tone
      .withSaturation(tone.saturation.clamp(0, dark ? .22 : .32))
      .withLightness(dark ? .11 : .925)
      .toColor();
  final column = Color.alphaBlend(
    (dark ? Colors.white : Colors.white).withValues(alpha: dark ? .06 : .55),
    page,
  );
  final band = tone
      .withLightness(dark ? .2 : tone.lightness.clamp(.45, .85))
      .toColor();
  return BoardGround(page, column, band);
}
