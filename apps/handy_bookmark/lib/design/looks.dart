import 'package:handy_ui/kit.dart';
import '../pro/entitlements.dart';
import 'identity.dart';
import 'theme.dart';

/// A theme the person can choose: a complete set of tokens (ground,
/// surfaces, ink, the action colour, lines, states), its title face and
/// whether surfaces carry edges. Premium looks are designed for one mode
/// (light or dark) and use it whatever the system says; the free library
/// look follows the system.
@immutable
class BookmarkLook {
  /// Stable id kept in preferences; [version] changes when a look is
  /// redesigned, never its id.
  final String id;
  final int version;
  final String en, vi, tagEn, tagVi;
  final bool pro;
  final BookmarkPalette? light, dark;
  const BookmarkLook({
    required this.id,
    required this.en,
    required this.vi,
    required this.tagEn,
    required this.tagVi,
    this.version = 1,
    this.pro = true,
    this.light,
    this.dark,
  });

  /// The palette for [system] brightness (a one-mode look ignores it).
  BookmarkPalette palette(Brightness system) => light == null
      ? dark!
      : (dark == null ? light! : (system == Brightness.dark ? dark! : light!));
}

/// The free look: the library as the guide draws it, light and dark.
const libraryLook = BookmarkLook(
  id: 'library',
  en: 'Library',
  vi: 'Thư viện',
  tagEn: 'Warm ivory and teal, light and dark',
  tagVi: 'Ngà ấm và xanh teal, sáng và tối',
  pro: false,
  light: BookmarkPalette.light,
  dark: BookmarkPalette.dark,
);

BookmarkPalette _p({
  required int canvas,
  required int surface,
  required int raised,
  required int sunk,
  required int primary,
  required int pressed,
  required int tint,
  required int onPrimary,
  required int ink,
  required int muted,
  required int line,
  required int control,
  required int sage,
  required int sageTint,
  required int warm,
  required int danger,
  required int dangerTint,
  required int warning,
  required int warningTint,
  String display = 'Newsreader',
  bool edges = false,
}) => BookmarkPalette(
  canvas: Color(canvas),
  surface: Color(surface),
  raised: Color(raised),
  sunk: Color(sunk),
  primary: Color(primary),
  pressed: Color(pressed),
  tint: Color(tint),
  onPrimary: Color(onPrimary),
  ink: Color(ink),
  muted: Color(muted),
  line: Color(line),
  control: Color(control),
  sage: Color(sage),
  sageTint: Color(sageTint),
  warm: Color(warm),
  danger: Color(danger),
  dangerTint: Color(dangerTint),
  warning: Color(warning),
  warningTint: Color(warningTint),
  display: display,
  edges: edges,
  band: _band(primary),
  bandSub: Color.lerp(_band(primary), const Color(0xFFFFFFFF), .8)!,
);

/// A look's header band: its own hue taken deep enough for white words
/// (a pale hue of a dark look goes further toward black).
Color _band(int primary) {
  final hue = Color(primary);
  return Color.lerp(
    hue,
    const Color(0xFF000000),
    hue.computeLuminance() > .3 ? .62 : .42,
  )!;
}

final premiumLooks = <BookmarkLook>[
  BookmarkLook(
    id: 'ink-paper',
    en: 'Ink & Paper',
    vi: 'Mực & Giấy',
    tagEn: 'Editorial ivory, ink type, fine rules',
    tagVi: 'Ngà kiểu báo, chữ mực, viền mảnh',
    light: _p(
      canvas: 0xFFFBFAF6,
      surface: 0xFFFFFFFF,
      raised: 0xFFF1EFE8,
      sunk: 0xFFECE9E1,
      primary: 0xFF1F1F1F,
      pressed: 0xFF000000,
      tint: 0xFFE9E6DD,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF171717,
      muted: 0xFF5E5B55,
      line: 0xFFDEDAD0,
      control: 0xFFBDB8AC,
      sage: 0xFF5A6B5A,
      sageTint: 0xFFE6EBE3,
      warm: 0xFFA6533C,
      danger: 0xFFA12C2C,
      dangerTint: 0xFFF6E1DE,
      warning: 0xFF7A5410,
      warningTint: 0xFFF3EAD7,
      edges: true,
    ),
  ),
  BookmarkLook(
    id: 'midnight-gallery',
    en: 'Midnight Gallery',
    vi: 'Phòng tranh đêm',
    tagEn: 'Charcoal walls, gold light on your pictures',
    tagVi: 'Tường than, ánh vàng trên ảnh của bạn',
    dark: _p(
      canvas: 0xFF0F1115,
      surface: 0xFF191C22,
      raised: 0xFF22262E,
      sunk: 0xFF0A0C0F,
      primary: 0xFFE8C77A,
      pressed: 0xFFF1D79A,
      tint: 0xFF3A3221,
      onPrimary: 0xFF1E1607,
      ink: 0xFFF2F0EA,
      muted: 0xFFB4B0A6,
      line: 0xFF2C3038,
      control: 0xFF464B55,
      sage: 0xFF9DBBA8,
      sageTint: 0xFF22322A,
      warm: 0xFFE0A07E,
      danger: 0xFFF09B95,
      dangerTint: 0xFF3B2322,
      warning: 0xFFE6C27A,
      warningTint: 0xFF352B17,
      display: 'Bricolage',
    ),
  ),
  BookmarkLook(
    id: 'forest-archive',
    en: 'Forest Archive',
    vi: 'Kho lưu trữ rừng',
    tagEn: 'Deep green, soft natural surfaces',
    tagVi: 'Xanh rừng sâu, mặt giấy tự nhiên',
    light: _p(
      canvas: 0xFFEEF1EA,
      surface: 0xFFFAFBF7,
      raised: 0xFFE2E8DE,
      sunk: 0xFFD9E0D4,
      primary: 0xFF2F5D46,
      pressed: 0xFF234837,
      tint: 0xFFD5E6DA,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF1A2620,
      muted: 0xFF4F5F56,
      line: 0xFFD2DACF,
      control: 0xFFA9B5AA,
      sage: 0xFF557A66,
      sageTint: 0xFFDDE9DF,
      warm: 0xFFA0623E,
      danger: 0xFFA3362F,
      dangerTint: 0xFFF4DEDA,
      warning: 0xFF7C5A12,
      warningTint: 0xFFF1E7CF,
    ),
  ),
  BookmarkLook(
    id: 'sakura-notes',
    en: 'Sakura Notes',
    vi: 'Sổ hoa anh đào',
    tagEn: 'Blush paper, rose accents',
    tagVi: 'Giấy hồng phấn, điểm nhấn hoa',
    light: _p(
      canvas: 0xFFFBF4F2,
      surface: 0xFFFFFFFF,
      raised: 0xFFF5E7E4,
      sunk: 0xFFF0DDD9,
      primary: 0xFFA83E62,
      pressed: 0xFF8E3454,
      tint: 0xFFF7DCE4,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF2A1F22,
      muted: 0xFF6A5559,
      line: 0xFFEEDCD8,
      control: 0xFFD2B9B6,
      sage: 0xFF6F8A75,
      sageTint: 0xFFE5EEE6,
      warm: 0xFFC26A55,
      danger: 0xFFA8332F,
      dangerTint: 0xFFF8E0DD,
      warning: 0xFF85591A,
      warningTint: 0xFFF5E9D5,
    ),
  ),
  BookmarkLook(
    id: 'ocean-glass',
    en: 'Ocean Glass',
    vi: 'Kính biển',
    tagEn: 'Cool sea blues, clear surfaces',
    tagVi: 'Xanh biển mát, mặt trong trẻo',
    light: _p(
      canvas: 0xFFEEF4F7,
      surface: 0xFFFFFFFF,
      raised: 0xFFE1ECF1,
      sunk: 0xFFD6E4EB,
      primary: 0xFF1F5F8B,
      pressed: 0xFF164A6D,
      tint: 0xFFD6E7F2,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF13222C,
      muted: 0xFF4D606B,
      line: 0xFFD5E2E9,
      control: 0xFFA9BCC7,
      sage: 0xFF4F7F79,
      sageTint: 0xFFDDEDEA,
      warm: 0xFFC2774F,
      danger: 0xFFA8352F,
      dangerTint: 0xFFF6E0DC,
      warning: 0xFF7C5813,
      warningTint: 0xFFF2E8D2,
      display: 'Bricolage',
    ),
  ),
  BookmarkLook(
    id: 'terracotta-studio',
    en: 'Terracotta Studio',
    vi: 'Xưởng đất nung',
    tagEn: 'Clay, sand and handmade warmth',
    tagVi: 'Đất nung, cát và vẻ thủ công',
    light: _p(
      canvas: 0xFFF5EEE6,
      surface: 0xFFFFFCF8,
      raised: 0xFFEBDFD2,
      sunk: 0xFFE3D4C4,
      primary: 0xFF9C4A2B,
      pressed: 0xFF843F24,
      tint: 0xFFF1DCCD,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF2B1E17,
      muted: 0xFF6B5649,
      line: 0xFFE5D6C7,
      control: 0xFFC7B19E,
      sage: 0xFF6E7F5E,
      sageTint: 0xFFE3E9DA,
      warm: 0xFFB87A2F,
      danger: 0xFFA12F2B,
      dangerTint: 0xFFF6DFDA,
      warning: 0xFF7A5512,
      warningTint: 0xFFF2E6CF,
      display: 'Bricolage',
    ),
  ),
  BookmarkLook(
    id: 'monochrome',
    en: 'Monochrome',
    vi: 'Đơn sắc',
    tagEn: 'Black on white; only your pictures have colour',
    tagVi: 'Đen trên trắng; chỉ ảnh của bạn có màu',
    light: _p(
      canvas: 0xFFFFFFFF,
      surface: 0xFFFFFFFF,
      raised: 0xFFF2F2F2,
      sunk: 0xFFEBEBEB,
      primary: 0xFF000000,
      pressed: 0xFF262626,
      tint: 0xFFEDEDED,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF000000,
      muted: 0xFF555555,
      line: 0xFFE2E2E2,
      control: 0xFFBDBDBD,
      sage: 0xFF555555,
      sageTint: 0xFFEFEFEF,
      warm: 0xFF333333,
      danger: 0xFFB3261E,
      dangerTint: 0xFFF9E2E0,
      warning: 0xFF6B4E00,
      warningTint: 0xFFF4EDDA,
      display: 'Geist',
      edges: true,
    ),
  ),
  BookmarkLook(
    id: 'retro-film',
    en: 'Retro Film',
    vi: 'Phim cũ',
    tagEn: 'Darkroom browns, amber safelight',
    tagVi: 'Nâu phòng tối, ánh đèn hổ phách',
    dark: _p(
      canvas: 0xFF201A16,
      surface: 0xFF2B241F,
      raised: 0xFF362D27,
      sunk: 0xFF18130F,
      primary: 0xFFE39A55,
      pressed: 0xFFEDB27A,
      tint: 0xFF4A3424,
      onPrimary: 0xFF24150A,
      ink: 0xFFF3E9DC,
      muted: 0xFFC2B2A0,
      line: 0xFF40362E,
      control: 0xFF5E5147,
      sage: 0xFFA9BF9A,
      sageTint: 0xFF2E3527,
      warm: 0xFFD9785F,
      danger: 0xFFF0A196,
      dangerTint: 0xFF42261F,
      warning: 0xFFE9C77D,
      warningTint: 0xFF3B3019,
      display: 'Bricolage',
    ),
  ),
  BookmarkLook(
    id: 'lavender-haze',
    en: 'Lavender Haze',
    vi: 'Sương oải hương',
    tagEn: 'Calm lavender greys, plum accents',
    tagVi: 'Xám oải hương dịu, điểm nhấn mận',
    light: _p(
      canvas: 0xFFF5F3F8,
      surface: 0xFFFFFFFF,
      raised: 0xFFECE8F2,
      sunk: 0xFFE3DEEC,
      primary: 0xFF5F4B8B,
      pressed: 0xFF4B3A70,
      tint: 0xFFE6E0F1,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF221E2A,
      muted: 0xFF5C5667,
      line: 0xFFE3DFEA,
      control: 0xFFBFB8CC,
      sage: 0xFF5E7D6F,
      sageTint: 0xFFE2ECE6,
      warm: 0xFFB5725A,
      danger: 0xFFA3322E,
      dangerTint: 0xFFF5DEDB,
      warning: 0xFF7A5714,
      warningTint: 0xFFF2E8D3,
    ),
  ),
  BookmarkLook(
    id: 'solar-citrus',
    en: 'Solar Citrus',
    vi: 'Nắng cam',
    tagEn: 'Sunlit cream, ripe orange',
    tagVi: 'Kem nắng, cam chín',
    light: _p(
      canvas: 0xFFFFF8E8,
      surface: 0xFFFFFFFF,
      raised: 0xFFFBEFCF,
      sunk: 0xFFF6E6BB,
      primary: 0xFFA44E0C,
      pressed: 0xFF8F430A,
      tint: 0xFFFCE4C6,
      onPrimary: 0xFFFFFFFF,
      ink: 0xFF2A2010,
      muted: 0xFF66563A,
      line: 0xFFF0E3C2,
      control: 0xFFD4BF91,
      sage: 0xFF5F7D47,
      sageTint: 0xFFE5EED9,
      warm: 0xFFC6402B,
      danger: 0xFFA52A26,
      dangerTint: 0xFFF8DEDA,
      warning: 0xFF7A5A0E,
      warningTint: 0xFFF7EBCB,
      display: 'Bricolage',
    ),
  ),
];

final allLooks = [libraryLook, ...premiumLooks];

/// The look for a stored id; unknown or removed ids fall back to null.
BookmarkLook? lookById(String? id) =>
    allLooks.where((l) => l.id == id).firstOrNull;

/// The finished theme for [look], built from the kit theme in the look's
/// own mode, so a dark look is dark even on a light system.
ThemeData lookTheme(BookmarkLook look, Brightness system) {
  final palette = look.palette(system);
  final mode = look.light == null
      ? Brightness.dark
      : (look.dark == null ? Brightness.light : system);
  return bookmarkTheme(
    buildHandyTheme(palette.primary, mode, bookmarkIdentity),
    palette,
  );
}

/// Applies the person's chosen look to everything below it. A premium
/// look shows only while Pro is verified; otherwise the free look shows
/// and the choice is kept, so it comes back when Pro does.
class LookScope extends StatelessWidget {
  final String? chosen;
  final Widget child;
  const LookScope({super.key, required this.chosen, required this.child});
  @override
  Widget build(BuildContext context) {
    final pro = hasPro(context);
    final look = lookById(chosen);
    if (look == null || look.id == libraryLook.id || (look.pro && !pro))
      return child;
    return Theme(
      data: lookTheme(look, Theme.of(context).brightness),
      child: child,
    );
  }
}
