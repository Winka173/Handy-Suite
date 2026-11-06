import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

bool _fontLicense = false;
void _registerFontLicense(HandyBrand brand) {
  if (_fontLicense) return;
  _fontLicense = true;
  // The app's own faces keep their licence beside them in its fonts/.
  final own = {
    brand.text,
    ?brand.display,
  }.where((f) => handyFontPackage(f) == null);
  LicenseRegistry.addLicense(() async* {
    for (final face in ['Geist', 'Bricolage']) {
      yield LicenseEntryWithLineBreaks([
        face,
      ], await rootBundle.loadString('packages/handy_ui/fonts/$face-OFL.txt'));
    }
    for (final face in own) {
      yield LicenseEntryWithLineBreaks([
        face,
      ], await rootBundle.loadString('fonts/$face-OFL.txt'));
    }
  });
}

/// Root of every Handy app: theme, language, Pro/ads host.
class HandyApp extends StatelessWidget {
  final String app, title;
  final Color accent;

  /// The app's own face; see [HandyBrand].
  final HandyBrand? brand;
  final String theme, locale;
  final ValueListenable<bool>? adsVisible;
  final Widget home;

  /// Named screens (`/tool/loan`, `/settings`). On the web these become the
  /// address bar and the browser's back button; deep links open them.
  final RouteFactory? onGenerateRoute;

  /// For opening a screen from outside the widget tree (a notification).
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Watches the app's routes (for example to hide ads above the home).
  final List<NavigatorObserver> navigatorObservers;

  /// The app's own finishing touches on the kit theme (both brightnesses).
  /// Optional: apps without one get the kit theme unchanged.
  final ThemeData Function(ThemeData theme)? themeOverride;
  const HandyApp({
    super.key,
    required this.app,
    required this.title,
    required this.accent,
    this.brand,
    this.theme = 'system',
    this.locale = 'system',
    this.adsVisible,
    required this.home,
    this.onGenerateRoute,
    this.navigatorKey,
    this.navigatorObservers = const [],
    this.themeOverride,
  });
  ThemeData _finish(ThemeData theme) =>
      themeOverride == null ? theme : themeOverride!(theme);

  @override
  Widget build(BuildContext context) {
    final b = brand ?? HandyBrand.current;
    HandyBrand.current = b;
    _registerFontLicense(b);
    return MonetizationHost(
      app: app,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: navigatorObservers,
        title: title,
        debugShowCheckedModeBanner: false,
        theme: _finish(buildHandyTheme(accent, Brightness.light, b)),
        darkTheme: _finish(buildHandyTheme(accent, Brightness.dark, b)),
        themeMode: switch (theme) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => b.darkFirst ? ThemeMode.dark : ThemeMode.system,
        },
        locale: locale == 'system' ? null : Locale(locale),
        supportedLocales: const [Locale('en'), Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => _Frame(
          color: b.frame,
          child: Column(
            children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              if (adsVisible == null)
                const LifetimeBanner()
              else
                ValueListenableBuilder<bool>(
                  valueListenable: adsVisible!,
                  builder: (context, visible, _) => visible
                      ? const LifetimeBanner()
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        home: home,
        onGenerateRoute: onGenerateRoute,
      ),
    );
  }
}

/// The framed-sheet styles: the page on a sheet inset in a tinted frame,
/// no shadow. Other styles pass straight through.
class _Frame extends StatelessWidget {
  final Color? color;
  final Widget child;
  const _Frame({required this.color, required this.child});
  @override
  Widget build(BuildContext context) {
    if (color == null) return child;
    final mq = MediaQuery.of(context);
    final inset = mq.size.width < 360 ? HandySpace.xs : HandySpace.s;
    final p = mq.padding;
    final outer = EdgeInsets.fromLTRB(
      p.left + inset,
      p.top + inset,
      p.right + inset,
      p.bottom + inset,
    );
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF1B1B1B) : color!,
      child: Padding(
        padding: outer,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(
                (mq.size.width - outer.horizontal).clamp(0, double.infinity),
                (mq.size.height - outer.vertical).clamp(0, double.infinity),
              ),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: mq.viewInsets.copyWith(
                bottom: (mq.viewInsets.bottom - outer.bottom).clamp(
                  0,
                  double.infinity,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shown while an app loads its local state, or when that load fails.
class HandyLoading extends StatelessWidget {
  final Object? error;
  final VoidCallback? retry;
  const HandyLoading({super.key, this.error, this.retry});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(HandySpace.xl),
              child: HandyContent(
                child: HandyEmpty(
                  title: tr(
                    context,
                    'Could not open saved data',
                    'Chưa mở được dữ liệu đã lưu',
                  ),
                  message: '$error',
                  action: retry == null
                      ? null
                      : FilledButton(
                          onPressed: retry,
                          child: Text(tr(context, 'Try again', 'Thử lại')),
                        ),
                ),
              ),
            ),
    ),
  );
}

/// The product's mark: its symbol on its own hue.
class HandyMark extends StatelessWidget {
  final IconData icon;
  final double size;
  const HandyMark(this.icon, {super.key, this.size = 28});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: HandyColors.of(context).accent,
      borderRadius: BorderRadius.circular(HandyRadius.control),
    ),
    child: Icon(icon, size: size * 0.6, color: Colors.white),
  );
}
