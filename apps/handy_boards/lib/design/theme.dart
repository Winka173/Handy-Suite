import 'package:handy_ui/kit.dart';

/// Pinboard: Handy Boards' own palette, shapes and type over the kit theme
/// (the kit keeps behaviour, spacing, motion and accessibility).
///
/// Light is a warm stone ground, the colour of a pin board's cork; cards are
/// white and part from it by tone. Dark is a warm near-black made on its
/// own, not an inversion. The app's hue is terracotta (chosen 2026-11-09,
/// replacing the magenta), kept to the primary action, selection, focus
/// and the header band: the colour on a board belongs to its categories
/// and covers.
@immutable
class BoardsPalette extends ThemeExtension<BoardsPalette> {
  final Color canvas, surface, raised, sunk;
  final Color primary, pressed, tint, onPrimary;
  final Color ink, muted, line, control;
  final Color danger, dangerTint, warning, warningTint, positive;

  /// The strong-contrast header band (3a, 2026-11-09): deep terracotta,
  /// white words, its line in [bandSub], and the gold action.
  final Color band, bandInk, bandSub, gold, onGold;
  const BoardsPalette({
    this.band = const Color(0xFF7C2D12),
    this.bandInk = const Color(0xFFFFFFFF),
    this.bandSub = const Color(0xFFFCDCC8),
    this.gold = const Color(0xFFE0A93B),
    this.onGold = const Color(0xFF241A05),
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
    required this.danger,
    required this.dangerTint,
    required this.warning,
    required this.warningTint,
    required this.positive,
  });

  static const light = BoardsPalette(
    canvas: Color(0xFFF5F1EE),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFECE6E1),
    sunk: Color(0xFFE3DBD5),
    primary: Color(0xFFB53C0A),
    pressed: Color(0xFF7C2D12),
    tint: Color(0xFFFBE5D8),
    onPrimary: Color(0xFFFFFFFF),
    ink: Color(0xFF17110D),
    muted: Color(0xFF3D332D),
    line: Color(0xFFE6DDD6),
    control: Color(0xFFCBBFB6),
    danger: Color(0xFFB3261E),
    dangerTint: Color(0xFFF9E3E0),
    warning: Color(0xFF8A5A0F),
    warningTint: Color(0xFFF7EBD6),
    positive: Color(0xFF2F6F4A),
  );

  static const dark = BoardsPalette(
    canvas: Color(0xFF121314),
    surface: Color(0xFF26292B),
    raised: Color(0xFF1B1D1F),
    sunk: Color(0xFF0E0F10),
    primary: Color(0xFFF0936A),
    pressed: Color(0xFFF6B08F),
    tint: Color(0xFF3D2318),
    onPrimary: Color(0xFF2B0F04),
    ink: Color(0xFFF5F5F5),
    muted: Color(0xFFBCC1C4),
    line: Color(0xFF2C2F31),
    control: Color(0xFF3A3D40),
    danger: Color(0xFFFF9B8C),
    dangerTint: Color(0xFF3B2522),
    warning: Color(0xFFE9C27F),
    warningTint: Color(0xFF3A2F1C),
    positive: Color(0xFF8FD3A8),
    band: Color(0xFF6E2A12),
    gold: Color(0xFFE6B44F),
  );

  static BoardsPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BoardsPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  BoardsPalette copyWith() => this;

  @override
  BoardsPalette lerp(BoardsPalette? other, double t) =>
      other == null || t < .5 ? this : other;
}

/// Corners step down from the sheet to the chip.
abstract final class BoardsRadii {
  static const chip = 999.0;
  static const control = 12.0;
  static const card = 14.0;
  static const column = 18.0;
  static const tile = 20.0;
  static const sheet = 26.0;
}

/// Spacing on a 4px base.
abstract final class BoardsSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0;
}

/// Finishes the kit theme with the pinboard palette and shapes.
ThemeData boardsTheme(ThemeData base, [BoardsPalette? palette]) {
  final dark = base.brightness == Brightness.dark;
  final p = palette ?? (dark ? BoardsPalette.dark : BoardsPalette.light);
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
    positive: p.positive,
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
    secondary: p.ink,
    secondaryContainer: p.raised,
    onSecondaryContainer: p.ink,
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
    inverseSurface: dark ? const Color(0xFFEFE7EC) : const Color(0xFF2C2229),
    onInverseSurface: dark ? const Color(0xFF1E181C) : const Color(0xFFF6EFF3),
    shadow: Colors.black,
  );
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  final textTheme = text.copyWith(
    // Larger type for tired eyes (2026-11-09): reading text 15–16,
    // secondary never under 13.5, section titles 21 bold.
    headlineMedium: text.headlineMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
      height: 1.15,
    ),
    headlineSmall: text.headlineSmall?.copyWith(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -.4,
      height: 1.2,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      letterSpacing: -.2,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: text.titleSmall?.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: text.bodyLarge?.copyWith(fontSize: 16.5),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 15.5),
    bodySmall: text.bodySmall?.copyWith(color: p.muted, fontSize: 13.5),
    labelLarge: text.labelLarge?.copyWith(fontSize: 15),
    labelMedium: text.labelMedium?.copyWith(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: text.labelSmall?.copyWith(fontSize: 12.5),
  );
  RoundedRectangleBorder round(double r, [BorderSide side = BorderSide.none]) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side,
      );
  OutlineInputBorder field([Color? color, double width = 1.5]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(BoardsRadii.control),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
  final button = textTheme.labelLarge?.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  return base.copyWith(
    colorScheme: scheme,
    textTheme: textTheme,
    extensions: [colors, p],
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    dividerColor: p.line,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: dark ? p.raised : p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: field(p.line, 1),
      enabledBorder: field(p.line, 1),
      disabledBorder: field(p.line, 1),
      focusedBorder: field(p.primary),
      errorBorder: field(p.danger, 1),
      focusedErrorBorder: field(p.danger),
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
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: round(BoardsRadii.control),
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
        side: BorderSide(color: p.line, width: 1.2),
        shape: round(BoardsRadii.control),
        textStyle: button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? p.primary : p.pressed,
        minimumSize: const Size(48, 48),
        shape: round(BoardsRadii.control),
        textStyle: button,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(48, 48),
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
      shape: round(18),
      extendedTextStyle: button,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: round(BoardsRadii.card),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      iconColor: p.muted,
      minTileHeight: 52,
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
        side: BorderSide(color: p.line),
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
      shape: round(6),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.control,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: round(14),
      backgroundColor: scheme.inverseSurface,
      actionTextColor: dark ? p.pressed : const Color(0xFFF5B8E6),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      elevation: 2,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: round(22),
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
          top: Radius.circular(BoardsRadii.sheet),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? p.raised : p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: .25),
      shape: round(16),
      textStyle: textTheme.bodyMedium,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(dark ? p.raised : p.surface),
        shape: WidgetStatePropertyAll(round(16)),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: p.ink,
      unselectedLabelColor: p.muted,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
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
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(10),
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
