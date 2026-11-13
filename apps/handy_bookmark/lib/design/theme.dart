import 'package:handy_ui/kit.dart';

/// Handy Bookmark's design tokens (2026-11-13 audit). Everything on
/// screen is built from these and nothing else:
///
/// * **Five key colours** per theme: ground, surface, ink, teal (the band,
///   every action, selection) and gold (the one Save action, the
///   read-later ribbon). Greys and tints are steps between two of them;
///   red and amber appear only as a state (error, warning). A collection's
///   own colour is the person's data and shows as a dot, never as chrome.
/// * **Spacing** on the kit's 4-point scale: 4, 8, 12, 16, 24, 32.
/// * **Type**: one face, five sizes (13.5, 15.5, 17, 21, 28) and three
///   weights (400, 600, 700).
/// * **Corners**: 8 (pictures), 12 (controls, rows), 20 (panels, sheets),
///   and the full pill for chips.
///
/// Every text pair reaches 4.5:1 and every control edge 3:1 (WCAG 2.2 AA;
/// `test/tokens_test.dart` measures them).
///
/// Warm Modern Library: Handy Bookmark's own palette, shapes and type,
/// laid over the kit theme so the kit's behaviour (spacing, motion,
/// accessibility) stays and only this app's look changes.
///
/// Light is a warm ivory ground with white surfaces that part by tone, not
/// by lines; dark is a warm charcoal designed on its own, never an
/// inversion. The one hue is the app's teal, the same as the first-run
/// guide, so the app reads as the guide's continuation.
@immutable
class BookmarkPalette extends ThemeExtension<BookmarkPalette> {
  final Color canvas, surface, raised, sunk;
  final Color primary, pressed, tint, onPrimary;
  final Color ink, muted, line, control;
  final Color sage, sageTint, warm;
  final Color danger, dangerTint, warning, warningTint;

  /// The strong-contrast header band (3a, 2026-11-09): a deep teal field
  /// with white words, its figures in [bandSub], and the gold action.
  final Color band, bandInk, bandSub, gold, onGold;

  /// The face of the editorial moments (library and collection names,
  /// an item's title); a theme may set a sans or a display face instead.
  final String display;

  /// Surfaces carry a hairline edge (an editorial or minimal theme)
  /// instead of parting by tone alone.
  final bool edges;
  const BookmarkPalette({
    this.display = 'Manrope',
    this.edges = false,
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.sunk,
    required this.primary,
    required this.pressed,
    required this.tint,
    required this.onPrimary,
    required this.ink,
    required this.muted,
    required this.line,
    required this.control,
    required this.sage,
    required this.sageTint,
    required this.warm,
    required this.danger,
    required this.dangerTint,
    required this.warning,
    required this.warningTint,
    this.band = const Color(0xFF0F4B54),
    this.bandInk = const Color(0xFFFFFFFF),
    this.bandSub = const Color(0xFFCFE5E6),
    this.gold = const Color(0xFFE0A93B),
    this.onGold = const Color(0xFF241A05),
  });

  static const light = BookmarkPalette(
    canvas: Color(0xFFEEF3F3),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFE6EDED),
    sunk: Color(0xFFDDE6E6),
    primary: Color(0xFF0F4B54),
    pressed: Color(0xFF0B373E),
    tint: Color(0xFFD4EBEE),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF0B1213),
    muted: Color(0xFF38423F),
    line: Color(0xFFDCE3E3),
    control: Color(0xFF6E7B7C),
    sage: Color(0xFF0F4B54),
    sageTint: Color(0xFFD4EBEE),
    warm: Color(0xFFE0A93B),
    danger: Color(0xFFB03A36),
    dangerTint: Color(0xFFF8E4E1),
    warning: Color(0xFF8A5A14),
    warningTint: Color(0xFFF6ECD8),
  );

  static const dark = BookmarkPalette(
    canvas: Color(0xFF121415),
    surface: Color(0xFF1E2123),
    raised: Color(0xFF282C2E),
    sunk: Color(0xFF0E0F10),
    primary: Color(0xFF7CC8D8),
    pressed: Color(0xFF9AD6E3),
    tint: Color(0xFF1F3A40),
    onPrimary: Color(0xFF0B2A31),
    ink: Color(0xFFF5F5F5),
    muted: Color(0xFFBCC1C4),
    line: Color(0xFF2C2F31),
    control: Color(0xFF7D8588),
    sage: Color(0xFF7CC8D8),
    sageTint: Color(0xFF1F3A40),
    warm: Color(0xFFE6B44F),
    danger: Color(0xFFF0A29C),
    dangerTint: Color(0xFF3F2624),
    warning: Color(0xFFE8C07A),
    warningTint: Color(0xFF3A2F1C),
    band: Color(0xFF145A64),
    bandSub: Color(0xFFD3EAEC),
    gold: Color(0xFFE6B44F),
    onGold: Color(0xFF241A05),
  );

  /// The palette of the theme in force (a chosen look, or the default).
  static BookmarkPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BookmarkPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  BookmarkPalette copyWith() => this;

  @override
  BookmarkPalette lerp(BookmarkPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// The five type sizes; nothing on screen is set at any other.
abstract final class BookmarkType {
  static const meta = 13.5;
  static const body = 15.5;
  static const lead = 17.0;
  static const section = 21.0;
  static const page = 28.0;
}

/// Corners step down from the largest surface to the smallest control.
abstract final class BookmarkRadii {
  static const chip = 999.0;
  static const field = 12.0;
  static const button = 12.0;
  static const thumb = 8.0;
  static const item = 12.0;
  static const panel = 20.0;
  static const collection = 20.0;
  static const focus = 20.0;
  static const dialog = 20.0;
  static const sheet = 20.0;
}

/// The display face for a few moments (the library's name, an item's
/// title on its own page): Manrope in the pastel look, a serif in some
/// Pro looks.
TextStyle bookmarkSerif(BuildContext context, double size) => TextStyle(
  fontFamily: handyFontFamily(BookmarkPalette.of(context).display),
  fontSize: size,
  height: 1.12,
  letterSpacing: -.4,
  fontWeight: BookmarkPalette.of(context).display == 'Manrope'
      ? FontWeight.w600
      : FontWeight.w500,
  color: BookmarkPalette.of(context).ink,
);

/// Finishes the kit theme with the library's palette and shapes.
ThemeData bookmarkTheme(ThemeData base, [BookmarkPalette? palette]) {
  final dark = base.brightness == Brightness.dark;
  final p = palette ?? (dark ? BookmarkPalette.dark : BookmarkPalette.light);
  final colors = HandyColors(
    select: p.tint,
    selectInk: dark ? p.ink : p.pressed,
    lead: p.surface,
    accent: p.primary,
    ground: p.canvas,
    raised: p.raised,
    border: p.line,
    rule: p.line,
    control: p.control,
    muted: p.muted,
    positive: dark ? const Color(0xFF8FD3A8) : const Color(0xFF2F6F4A),
    negative: p.danger,
    warning: p.warning,
    positiveBg: dark ? const Color(0xFF203A2B) : const Color(0xFFE2F1E6),
    negativeBg: p.dangerTint,
    warningBg: p.warningTint,
  );
  final scheme = base.colorScheme.copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.tint,
    onPrimaryContainer: dark ? p.ink : p.pressed,
    secondary: p.sage,
    secondaryContainer: p.tint,
    onSecondaryContainer: dark ? p.ink : p.pressed,
    tertiary: p.warm,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.canvas,
    surfaceContainer: p.canvas,
    surfaceContainerHigh: p.raised,
    surfaceContainerHighest: p.raised,
    outline: p.control,
    outlineVariant: p.line,
    error: p.danger,
    onError: dark ? const Color(0xFF2B0F0D) : Colors.white,
    inverseSurface: dark ? const Color(0xFFE9EEEA) : const Color(0xFF223031),
    onInverseSurface: dark ? const Color(0xFF1A2120) : const Color(0xFFF1F4F1),
    shadow: Colors.black,
  );
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  // Larger type for tired eyes (2026-11-09): reading text 15–16,
  // secondary never under 13.5, section titles 21 bold.
  final textTheme = text.copyWith(
    headlineSmall: text.headlineSmall?.copyWith(
      fontSize: BookmarkType.page,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      height: 1.2,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontSize: BookmarkType.section,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: BookmarkType.lead,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: text.titleSmall?.copyWith(
      fontSize: BookmarkType.body,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: BookmarkType.body),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: BookmarkType.body),
    bodySmall: text.bodySmall?.copyWith(
      color: p.muted,
      fontSize: BookmarkType.meta,
    ),
    labelLarge: text.labelLarge?.copyWith(fontSize: BookmarkType.body),
    labelMedium: text.labelMedium?.copyWith(fontSize: BookmarkType.meta),
    labelSmall: text.labelSmall?.copyWith(fontSize: BookmarkType.meta),
  );
  RoundedRectangleBorder round(double r, [BorderSide side = BorderSide.none]) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side,
      );
  OutlineInputBorder field([Color? color, double width = 1.5]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BookmarkRadii.field),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
  final button = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
  return base.copyWith(
    colorScheme: scheme,
    textTheme: textTheme,
    extensions: [colors, p],
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    dividerColor: p.line,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: p.canvas,
      foregroundColor: p.ink,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: dark ? p.raised : p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: field(p.control, 1),
      enabledBorder: field(p.control, 1),
      disabledBorder: field(p.line, 1),
      focusedBorder: field(p.primary, 2),
      errorBorder: field(p.danger, 1),
      focusedErrorBorder: field(p.danger, 2),
      hintStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w400),
      prefixIconColor: p.muted,
      suffixIconColor: p.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        disabledBackgroundColor: p.raised,
        disabledForegroundColor: p.muted,
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: round(BookmarkRadii.button),
        textStyle: button,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surface,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: BorderSide(color: p.control, width: 1),
        shape: round(BookmarkRadii.button),
        textStyle: button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? p.primary : p.pressed,
        minimumSize: const Size(48, 48),
        shape: round(BookmarkRadii.button),
        textStyle: button,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
    ),
    iconTheme: IconThemeData(color: p.ink, size: 22),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 2,
      shape: round(BookmarkRadii.panel),
      extendedTextStyle: button,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: round(
        BookmarkRadii.item,
        p.edges ? BorderSide(color: p.line) : BorderSide.none,
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      iconColor: p.muted,
      minTileHeight: 52,
      // Rows sit in grouped cards that clip them; a selected row is a flat
      // band between its dividers, never a pill that overlaps them.
      shape: const RoundedRectangleBorder(),
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: p.raised,
      selectedColor: p.tint,
      labelStyle: textTheme.labelLarge?.copyWith(color: p.ink),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: dark ? p.ink : p.pressed,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      iconTheme: IconThemeData(color: p.muted, size: 18),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: p.control),
        backgroundColor: p.surface,
        selectedBackgroundColor: p.tint,
        selectedForegroundColor: dark ? p.ink : p.pressed,
        foregroundColor: p.muted,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(44, 44),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(dark ? p.ink : Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.control,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onPrimary),
      side: BorderSide(color: p.control, width: 1.6),
      shape: round(4),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.control,
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: p.surface,
      indicatorColor: p.tint,
      indicatorShape: const StadiumBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: round(BookmarkRadii.item),
      backgroundColor: scheme.inverseSurface,
      actionTextColor: dark ? p.pressed.withValues(alpha: 1) : p.tint,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      elevation: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: round(BookmarkRadii.dialog),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.control,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(BookmarkRadii.sheet),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? p.raised : p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: .25),
      shape: round(BookmarkRadii.item),
      textStyle: textTheme.bodyMedium,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(dark ? p.raised : p.surface),
        shape: WidgetStatePropertyAll(round(BookmarkRadii.item)),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: p.ink,
      unselectedLabelColor: p.muted,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        color: p.tint,
        borderRadius: BorderRadius.circular(999),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.raised,
      circularTrackColor: p.raised,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: p.primary,
      thumbColor: p.primary,
      inactiveTrackColor: p.raised,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primary.withValues(alpha: .28),
      selectionHandleColor: p.primary,
    ),
  );
}
