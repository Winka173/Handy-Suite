import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Spacing scale shared by every Handy app (4px base, one gap value).
abstract final class HandySpace {
  static const double xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32;

  /// Readable column on desktop/tablet.
  static const double content = 760;

  /// Two-column launchers and lists on desktop.
  static const double contentWide = 1120;

  /// Width at which navigation moves from the bottom bar to a sidebar.
  static const double wide = 840;
}

/// The suite's face, shared by every app; each app still brings its hue.
class HandyBrand {
  /// Family (bundled in handy_ui) for page titles and result figures.
  final String? display;
  final FontWeight displayWeight;
  final double card, control, title;

  /// The app hue fills the primary button and tints selections and the
  /// lead panel; otherwise those stay ink and grey.
  final bool ladder;

  /// The page ground leans a few percent toward the app hue.
  final bool tintGround;

  /// Panels are a tone step on a white page instead of white cards with an edge.
  final bool flatPanels;
  const HandyBrand({
    this.display,
    this.displayWeight = FontWeight.w500,
    this.card = 8,
    this.control = 6,
    this.title = 24,
    this.ladder = false,
    this.tintGround = false,
    this.flatPanels = false,
  });
  static const ledger = HandyBrand();
  static const workbench = HandyBrand(
    display: 'Bricolage',
    displayWeight: FontWeight.w600,
    tintGround: true,
    title: 28,
  );
  static const ladderBrand = HandyBrand(
    display: 'Bricolage',
    displayWeight: FontWeight.w600,
    ladder: true,
    card: 12,
    control: 8,
    title: 28,
  );
  static const notebook = HandyBrand(
    display: 'Newsreader',
    displayWeight: FontWeight.w400,
    card: 20,
    control: 22,
    title: 32,
    flatPanels: true,
  );
  static HandyBrand current = ladderBrand;
}

/// System faces tried, in order, for scripts the bundled fonts lack.
const handyFontFallback = [
  'Noto Sans CJK JP',
  'Noto Sans JP',
  'Hiragino Sans',
  'Yu Gothic UI',
  'Yu Gothic',
  'Microsoft YaHei UI',
  'PingFang SC',
  'Noto Sans CJK SC',
  'Malgun Gothic',
  'Apple SD Gothic Neo',
  'Noto Sans CJK KR',
];

/// Corner radii of the current brand.
abstract final class HandyRadius {
  static double get card => HandyBrand.current.card;
  static double get control => HandyBrand.current.control;
}

/// Roles the Material scheme has no slot for. Read with `HandyColors.of`.
/// The chrome is ink only; [accent] is each app's hue and goes on the
/// screen's main data element (the result, the current item), nowhere else.
@immutable
class HandyColors extends ThemeExtension<HandyColors> {
  final Color accent, ground, raised, border, rule, control, muted;
  final Color positive, negative, warning;
  final Color positiveBg, negativeBg, warningBg;

  /// Selected fill/ink (nav, chips, segments) and the lead panel's fill.
  final Color select, selectInk, lead;
  const HandyColors({
    required this.select,
    required this.selectInk,
    required this.lead,
    required this.accent,
    required this.ground,
    required this.raised,
    required this.border,
    required this.rule,
    required this.control,
    required this.muted,
    required this.positive,
    required this.negative,
    required this.warning,
    required this.positiveBg,
    required this.negativeBg,
    required this.warningBg,
  });
  static HandyColors of(BuildContext context) =>
      Theme.of(context).extension<HandyColors>()!;
  @override
  HandyColors copyWith({Color? accent}) => HandyColors(
    select: select,
    selectInk: selectInk,
    lead: lead,
    accent: accent ?? this.accent,
    ground: ground,
    raised: raised,
    border: border,
    rule: rule,
    control: control,
    muted: muted,
    positive: positive,
    negative: negative,
    warning: warning,
    positiveBg: positiveBg,
    negativeBg: negativeBg,
    warningBg: warningBg,
  );
  @override
  HandyColors lerp(HandyColors? other, double t) =>
      other == null || t < .5 ? this : other;
}

const _ink = Color(0xFF0A0A0A);
const _primaryLight = Color(0xFF141414);

double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

/// The app hue darkened until white text on it reads at 4.5:1.
Color deepAccent(Color accent) {
  var c = accent;
  for (var i = 0; i < 20 && _contrast(c, Colors.white) < 4.5; i++) {
    c = Color.lerp(c, Colors.black, .08)!;
  }
  return c;
}

HandyColors _colors(Color accent, bool light, HandyBrand b) {
  final soft = Color.lerp(accent, light ? Colors.white : Colors.black, .86)!;
  final softInk = light
      ? Color.lerp(accent, Colors.black, .5)!
      : Color.lerp(accent, Colors.white, .45)!;
  if (light) {
    return HandyColors(
      select: b.ladder ? soft : const Color(0xFFEEEEEE),
      selectInk: b.ladder ? softInk : _ink,
      lead: b.ladder
          ? Color.lerp(accent, Colors.white, .93)!
          : b.flatPanels
          ? const Color(0xFFF5F5F3)
          : Colors.white,
      accent: accent,
      ground: b.flatPanels
          ? Colors.white
          : b.tintGround
          ? Color.lerp(const Color(0xFFF7F7F6), accent, .035)!
          : const Color(0xFFF8F8F8),
      raised: const Color(0xFFEEEEEE),
      border: const Color(0xFFE6E6E6),
      rule: const Color(0xFFEDEDED),
      control: const Color(0xFFD4D4D4),
      muted: const Color(0xFF6B6B6B),
      positive: const Color(0xFF2E7D32),
      negative: const Color(0xFFC4242A),
      warning: const Color(0xFF92400E),
      positiveBg: const Color(0xFFDCFAE5),
      negativeBg: const Color(0xFFFFEDEA),
      warningBg: const Color(0xFFFFFBEB),
    );
  }
  return HandyColors(
    select: b.ladder ? soft : const Color(0xFF222222),
    selectInk: b.ladder ? softInk : Colors.white,
    lead: b.ladder
        ? Color.lerp(accent, Colors.black, .9)!
        : const Color(0xFF111111),
    accent: Color.lerp(accent, Colors.white, 0.25)!,
    ground: b.tintGround
        ? Color.lerp(Colors.black, accent, .04)!
        : const Color(0xFF000000),
    raised: const Color(0xFF222222),
    border: const Color(0xFF2E2E2E),
    rule: const Color(0xFF1C1C1C),
    control: const Color(0xFF444444),
    muted: const Color(0xFFB4B4B4),
    positive: const Color(0xFF3FC07A),
    negative: const Color(0xFFE5566F),
    warning: const Color(0xFFF5B454),
    positiveBg: const Color(0xFF172A1D),
    negativeBg: const Color(0xFF2C1A20),
    warningBg: const Color(0xFF2A2210),
  );
}

const tabular = [FontFeature.tabularFigures()];

/// Achromatic ledger: ink chrome on an off-white ground, white cards with a
/// 1px edge, a near-black primary, one app hue reserved for data.
ThemeData buildHandyTheme(
  Color accent,
  Brightness brightness, [
  HandyBrand? brand,
]) {
  final b = brand ?? HandyBrand.current;
  final light = brightness == Brightness.light;
  final c = _colors(accent, light, b);
  final ink = light ? _ink : Colors.white;
  final surface = light ? Colors.white : const Color(0xFF111111);
  final fill = b.ladder
      ? (light ? deepAccent(accent) : c.accent)
      : (light ? _primaryLight : Colors.white);
  final onFill = light ? Colors.white : Colors.black;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: fill,
        onPrimary: onFill,
        secondaryContainer: c.select,
        onSecondaryContainer: c.selectInk,
        surface: surface,
        onSurface: ink,
        onSurfaceVariant: c.muted,
        surfaceContainerLowest: surface,
        surfaceContainerLow: c.ground,
        surfaceContainer: c.ground,
        surfaceContainerHigh: c.raised,
        surfaceContainerHighest: c.raised,
        outline: c.control,
        outlineVariant: c.border,
        error: c.negative,
        onError: Colors.white,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: 'Geist',
    package: 'handy_ui',
    // The bundled faces cover Latin and Vietnamese. Other scripts (Japanese,
    // Chinese, Korean…) fall back to the system's own faces by name.
    fontFamilyFallback: handyFontFallback,
  );
  TextStyle? t(TextStyle? s, double size, FontWeight w, [double? height]) =>
      s?.copyWith(
        fontSize: size,
        fontWeight: w,
        height: height,
        letterSpacing: 0,
        color: ink,
      );
  TextStyle? display(TextStyle? s) => b.display == null
      ? s
      : s?.copyWith(
          fontFamily: b.display,
          package: 'handy_ui',
          fontWeight: b.displayWeight,
        );
  final text = base.textTheme.copyWith(
    // Result figure: the largest type on any screen.
    headlineMedium: display(
      t(
        base.textTheme.headlineMedium,
        b.display == null ? 30 : 34,
        FontWeight.w500,
        1.15,
      )?.copyWith(letterSpacing: -0.4, fontFeatures: tabular),
    ),
    // Page title.
    headlineSmall: display(
      t(
        base.textTheme.headlineSmall,
        b.title,
        FontWeight.w500,
        1.2,
      )?.copyWith(letterSpacing: b.display == null ? -0.2 : -0.5),
    ),
    titleLarge: display(t(base.textTheme.titleLarge, 20, FontWeight.w500, 1.3)),
    titleMedium: t(base.textTheme.titleMedium, 16, FontWeight.w500, 1.4),
    titleSmall: t(base.textTheme.titleSmall, 14, FontWeight.w500, 1.4),
    bodyLarge: t(base.textTheme.bodyLarge, 16, FontWeight.w400, 1.5),
    bodyMedium: t(base.textTheme.bodyMedium, 14, FontWeight.w400, 1.45),
    bodySmall: t(
      base.textTheme.bodySmall,
      12,
      FontWeight.w400,
      1.4,
    )?.copyWith(color: c.muted),
    labelLarge: t(base.textTheme.labelLarge, 14, FontWeight.w500),
    labelMedium: t(base.textTheme.labelMedium, 12, FontWeight.w500),
    labelSmall: t(base.textTheme.labelSmall, 11, FontWeight.w500),
  );
  final control = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(b.control),
  );
  OutlineInputBorder edge(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(b.control),
        borderSide: BorderSide(color: color, width: width),
      );
  // 44px keeps touch targets honest on phones; desktop still reads compact.
  const buttonSize = Size(64, 44);
  return base.copyWith(
    textTheme: text,
    // Each platform keeps its own way of going back.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    extensions: [c],
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.ground,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: edge(c.border),
      enabledBorder: edge(c.border),
      disabledBorder: edge(c.rule),
      focusedBorder: edge(ink, 1.5),
      errorBorder: edge(c.negative),
      focusedErrorBorder: edge(c.negative, 1.5),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      hintStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w400),
      helperStyle: text.bodySmall,
      errorStyle: text.bodySmall?.copyWith(color: c.negative),
      prefixIconColor: c.muted,
      suffixIconColor: c.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        shape: control,
        textStyle: text.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: control,
        side: BorderSide(color: c.control),
        foregroundColor: ink,
        backgroundColor: surface,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: control,
        foregroundColor: ink,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: ink,
        shape: control,
      ),
    ),
    iconTheme: IconThemeData(color: ink, size: 20),
    cardTheme: CardThemeData(
      color: b.flatPanels && light ? c.lead : surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(b.card),
        side: b.flatPanels ? BorderSide.none : BorderSide(color: c.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
      minVerticalPadding: 10,
      minTileHeight: 48,
      horizontalTitleGap: HandySpace.m,
      iconColor: c.muted,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: c.muted),
    ),
    dividerTheme: DividerThemeData(color: c.rule, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      shape: control,
      side: BorderSide(color: c.border),
      backgroundColor: surface,
      selectedColor: c.select,
      showCheckmark: false,
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: control,
        side: BorderSide(color: c.border),
        backgroundColor: surface,
        selectedBackgroundColor: c.select,
        selectedForegroundColor: c.selectInk,
        foregroundColor: c.muted,
        textStyle: text.labelLarge,
        minimumSize: const Size(44, 40),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(surface),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? fill : c.control,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? ink : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(surface),
      side: BorderSide(color: c.control, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.select,
      indicatorShape: control,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? c.selectInk : c.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected) ? ink : c.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: control,
      backgroundColor: light ? _primaryLight : Colors.white,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: light ? Colors.white : Colors.black,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(b.card),
      ),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: c.muted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(b.card),
        side: BorderSide(color: c.border),
      ),
      textStyle: text.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: ink,
      linearTrackColor: c.raised,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: fill,
      thumbColor: fill,
      inactiveTrackColor: c.raised,
      overlayColor: ink.withValues(alpha: 0.06),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: light ? _primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(b.control),
      ),
      textStyle: text.bodySmall?.copyWith(
        color: light ? Colors.white : Colors.black,
      ),
    ),
  );
}
