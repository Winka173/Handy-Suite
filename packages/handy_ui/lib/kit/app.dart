import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

bool _fontLicense = false;
void _registerFontLicense() {
  if (_fontLicense) return;
  _fontLicense = true;
  LicenseRegistry.addLicense(() async* {
    for (final face in ['Geist', 'Bricolage']) {
      yield LicenseEntryWithLineBreaks([
        face,
      ], await rootBundle.loadString('packages/handy_ui/fonts/$face-OFL.txt'));
    }
  });
}

/// Root of every Handy app: theme, language, Pro/ads host.
class HandyApp extends StatelessWidget {
  final String app, title;
  final Color accent;
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
  const HandyApp({
    super.key,
    required this.app,
    required this.title,
    required this.accent,
    this.theme = 'system',
    this.locale = 'system',
    this.adsVisible,
    required this.home,
    this.onGenerateRoute,
    this.navigatorKey,
    this.navigatorObservers = const [],
  });
  @override
  Widget build(BuildContext context) {
    _registerFontLicense();
    return MonetizationHost(
      app: app,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: navigatorObservers,
        title: title,
        debugShowCheckedModeBanner: false,
        theme: buildHandyTheme(accent, Brightness.light),
        darkTheme: buildHandyTheme(accent, Brightness.dark),
        themeMode: switch (theme) {
          'dark' => ThemeMode.dark,
          'light' => ThemeMode.light,
          _ => ThemeMode.system,
        },
        locale: locale == 'system' ? null : Locale(locale),
        supportedLocales: const [Locale('en'), Locale('vi')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            if (adsVisible == null)
              const LifetimeBanner()
            else
              ValueListenableBuilder<bool>(
                valueListenable: adsVisible!,
                builder: (context, visible, _) =>
                    visible ? const LifetimeBanner() : const SizedBox.shrink(),
              ),
          ],
        ),
        home: home,
        onGenerateRoute: onGenerateRoute,
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
