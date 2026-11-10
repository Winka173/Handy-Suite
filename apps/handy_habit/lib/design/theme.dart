import 'package:handy_ui/kit.dart';
import 'palette.dart';

/// Keep kit mechanics; set every material text role to the bundled Nunito.
ThemeData habitTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final p = dark ? HabitPalette.dark : HabitPalette.light;
  final text = base.textTheme.apply(
    fontFamily: handyFontFamily('Nunito'),
    bodyColor: p.ink,
    displayColor: p.ink,
  );
  final type = text.copyWith(
    headlineMedium: text.headlineMedium?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    headlineSmall: text.headlineSmall?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.15,
    ),
    titleLarge: text.titleLarge?.copyWith(
      fontSize: 21,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: text.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: text.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: text.bodyLarge?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: text.bodyMedium?.copyWith(fontSize: 15.5),
    bodySmall: text.bodySmall?.copyWith(fontSize: 14, color: p.muted),
    labelLarge: text.labelLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: text.labelMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: text.labelSmall?.copyWith(fontSize: 14, color: p.muted),
  );
  final colors = HandyColors(
    select: p.tint,
    selectInk: p.vermilion,
    lead: p.ochreField,
    accent: p.vermilion,
    ground: p.canvas,
    raised: p.surface,
    border: p.line,
    rule: p.line,
    control: p.control,
    muted: p.muted,
    positive: p.ochre,
    negative: p.vermilion,
    warning: p.ochre,
    positiveBg: p.ochreField,
    negativeBg: p.tint,
    warningBg: p.ochreField,
  );
  final scheme = base.colorScheme.copyWith(
    primary: p.vermilion,
    onPrimary: p.onVermilion,
    primaryContainer: p.tint,
    onPrimaryContainer: p.vermilion,
    secondary: p.anchor,
    onSecondary: p.onAnchor,
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
    error: p.vermilion,
    onError: p.onVermilion,
  );
  final button = type.labelLarge;
  return base.copyWith(
    colorScheme: scheme,
    textTheme: type,
    extensions: [
      ...base.extensions.values.where((e) => e is! HandyColors),
      colors,
      p,
    ],
    scaffoldBackgroundColor: p.canvas,
    canvasColor: p.canvas,
    dividerColor: p.line,
    cardTheme: base.cardTheme.copyWith(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: p.canvas,
      foregroundColor: p.anchor,
      titleTextStyle: type.titleLarge?.copyWith(color: p.anchor),
      surfaceTintColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.raised : p.anchor,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.muted : p.onAnchor,
        ),
        textStyle: WidgetStatePropertyAll(button),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(p.anchor),
        textStyle: WidgetStatePropertyAll(button),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(p.anchor),
        textStyle: WidgetStatePropertyAll(button),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.surface,
      selectedColor: p.tint,
      labelStyle: type.labelMedium?.copyWith(color: p.ink),
      secondaryLabelStyle: type.labelMedium?.copyWith(color: p.vermilion),
      checkmarkColor: p.vermilion,
      side: BorderSide(color: p.control),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: p.surface,
      hintStyle: type.bodyMedium?.copyWith(color: p.muted),
      labelStyle: type.titleSmall,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: p.canvas,
      indicatorColor: p.raised,
      labelTextStyle: WidgetStatePropertyAll(
        type.labelSmall?.copyWith(color: p.ink),
      ),
    ),
    iconTheme: base.iconTheme.copyWith(color: p.muted),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      backgroundColor: p.anchor,
      foregroundColor: p.onAnchor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      textColor: p.ink,
      iconColor: p.muted,
      titleTextStyle: type.bodyLarge,
      subtitleTextStyle: type.bodySmall,
    ),
    tooltipTheme: base.tooltipTheme.copyWith(
      textStyle: type.bodySmall?.copyWith(color: p.onAnchor),
      decoration: BoxDecoration(
        color: p.anchor,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
