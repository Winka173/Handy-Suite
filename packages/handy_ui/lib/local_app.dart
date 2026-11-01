import 'package:flutter_localizations/flutter_localizations.dart';
import 'handy_ui.dart';
import 'package:handy_monetization/handy_monetization.dart';

/// App supplies persistence: user data stays outside this presentation package.
class LocalApp extends StatefulWidget {
  final String title;
  final Color accent;
  final FloatingLabelBehavior? floatingLabelBehavior;
  final ValueNotifier<bool>? adsVisible;
  final Future<Map<String, String>> Function() loadPreferences;
  final Future<void> Function(Map<String, String>) savePreferences;
  final Widget Function(BuildContext, Widget settings) content;
  final Widget Function(BuildContext, Future<void> Function() reload)?
  extraSettings;
  const LocalApp({
    super.key,
    required this.title,
    required this.accent,
    this.floatingLabelBehavior,
    this.adsVisible,
    required this.loadPreferences,
    required this.savePreferences,
    required this.content,
    this.extraSettings,
  });
  @override
  State<LocalApp> createState() => _LocalAppState();
}

class _LocalAppState extends State<LocalApp> {
  Map<String, String>? prefs;
  String error = '';
  bool busy = false;
  ThemeData appTheme(Brightness brightness) {
    final theme = handyTheme(widget.accent, brightness);
    return widget.floatingLabelBehavior == null
        ? theme
        : theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              floatingLabelBehavior: widget.floatingLabelBehavior,
            ),
          );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await widget.loadPreferences();
      if (mounted) setState(() => prefs = p);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> change(String key, String? value) async {
    if (value == null || busy) return;
    setState(() => busy = true);
    try {
      final next = {...prefs!, key: value};
      await widget.savePreferences(next);
      if (mounted) setState(() => prefs = next);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MonetizationHost(
    app: widget.title.split(' ').last.toLowerCase(),
    child: MaterialApp(
      title: widget.title,
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          if (widget.adsVisible == null)
            const LifetimeBanner()
          else
            ValueListenableBuilder<bool>(
              valueListenable: widget.adsVisible!,
              builder: (context, visible, _) =>
                  visible ? const LifetimeBanner() : const SizedBox.shrink(),
            ),
        ],
      ),
      debugShowCheckedModeBanner: false,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: prefs?['theme'] == 'dark'
          ? ThemeMode.dark
          : prefs?['theme'] == 'light'
          ? ThemeMode.light
          : ThemeMode.system,
      locale: prefs?['locale'] == 'system' || prefs == null
          ? null
          : Locale(prefs!['locale']!),
      supportedLocales: const [Locale('en'), Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Builder(
        builder: (context) {
          if (prefs == null)
            return Scaffold(
              body: error.isNotEmpty
                  ? HandyErrorState(error, retry: load)
                  : const Center(child: CircularProgressIndicator()),
            );
          final settings = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey('locale-${prefs!['locale']}'),
                initialValue: prefs!['locale'],
                decoration: InputDecoration(
                  labelText: tr(context, 'Language', 'Ngôn ngữ'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('System / Hệ thống'),
                  ),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                ],
                onChanged: busy ? null : (v) => change('locale', v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('theme-${prefs!['theme']}'),
                initialValue: prefs!['theme'],
                decoration: InputDecoration(
                  labelText: tr(context, 'Appearance', 'Giao diện'),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'system',
                    child: Text('System / Hệ thống'),
                  ),
                  DropdownMenuItem(value: 'light', child: Text('Light / Sáng')),
                  DropdownMenuItem(value: 'dark', child: Text('Dark / Tối')),
                ],
                onChanged: busy ? null : (v) => change('theme', v),
              ),
              if (error.isNotEmpty) Text(error),
              const SizedBox(height: 20),
              Text(
                tr(
                  context,
                  'Local data is not encrypted. Export a backup before uninstalling or clearing browser data.',
                  'Dữ liệu cục bộ không mã hóa. Hãy xuất bản sao trước khi gỡ app hoặc xóa dữ liệu trình duyệt.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr(
                  context,
                  'Free + Ads + Pro Lifetime.',
                  'Free + Ads + Pro Lifetime.',
                ),
              ),
            ],
          );
          final withStore = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              settings,
              if (widget.extraSettings != null)
                widget.extraSettings!(context, load),
              const SizedBox(height: 16),
              const LifetimeSettings(),
            ],
          );
          return widget.content(context, withStore);
        },
      ),
    ),
  );
}
