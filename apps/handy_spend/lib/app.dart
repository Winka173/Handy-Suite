import 'dart:async';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'accounts/account_view.dart';
import 'controller.dart';
import 'home_widget.dart';
import 'import/import_page.dart';
import 'people/people_page.dart';
import 'receipts/receipt_view.dart';
import 'privacy.dart';
import 'reminders.dart';
import 'scope.dart';
import 'settings/categories_page.dart';
import 'settings/data.dart';
import 'settings/imports_page.dart';
import 'settings/rules_page.dart';
import 'settings/settings_page.dart';
import 'settings/templates_page.dart';
import 'shell/spend_shell.dart';

export 'import/statement_io.dart' show readDroppedStatement;
export 'scope.dart' show SpendScope;
export 'shell/spend_shell.dart' show SpendShell;

/// Spend's hue in the suite palette (docs/UX_REDESIGN.md): banknote green.
const spendAccent = Color(0xFF2E7D32);

class SpendApp extends StatefulWidget {
  final SpendController? controller;
  final HandyFiles files;
  final PreferencesRepository? preferences;
  final SpendPrivacy? privacy;
  final ScanCamera? camera;
  final bool enableDrop;

  /// Off in host tests: no folder backups, no home-screen widget.
  final bool device;
  const SpendApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.preferences,
    this.privacy,
    this.camera,
    this.enableDrop = true,
    this.device = true,
  });
  @override
  State<SpendApp> createState() => _SpendAppState();
}

class _SpendAppState extends State<SpendApp> with WidgetsBindingObserver {
  late final controller = widget.controller ?? SpendController();
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-spend',
        knownTools: {},
        workflowSteps: {},
      );
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final SpendScope scope = SpendScope(
    controller: controller,
    files: widget.files,
    reminders: SpendReminders(),
    privacy: widget.privacy ?? SpendPrivacy(),
    camera: widget.camera,
    autoBackup: widget.device
        ? HandyAutoBackup.local(
            app: 'spend',
            extension: 'zip',
            build: () => spendBackupBytes(scope),
            revision: () => controller.state?.revision.toString(),
          )
        : null,
  );
  late final routes = _Depth(_ads);
  final widgetFeed = HomeWidgetFeed(spendWidgetClass);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_changed);
    scope.area.addListener(_ads);
    if (controller.state == null) unawaited(controller.load());
    unawaited(loadPreferences());
    _ads();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scope.autoBackup?.dispose();
    controller.removeListener(_changed);
    scope.area.removeListener(_ads);
    scope.dispose();
    if (widget.controller == null) controller.dispose();
    prefs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _changed() {
    _sync();
    _ads();
  }

  void _sync() {
    final s = controller.state;
    if (s == null) return;
    // The in-app list stays right if the OS refuses; settings says why.
    unawaited(scope.reminders.sync(s).catchError((Object _) {}));
    scope.autoBackup?.attach();
    if (widget.device) {
      try {
        final locale = prefs.value?.locale ?? 'system';
        final vi =
            locale == 'vi' ||
            locale == 'system' &&
                WidgetsBinding
                        .instance
                        .platformDispatcher
                        .locale
                        .languageCode ==
                    'vi';
        final safe = safeToSpend(
          s,
          scope.today,
          scope.end,
          accounts: scope.planningAccounts,
          conservative: scope.conservative.value,
        );
        unawaited(widgetFeed.publish(spendWidgetView(s, safe, vi: vi)));
      } catch (_) {
        // A widget that cannot be worked out keeps its last picture.
      }
    }
  }

  /// Ads only on the home of Today, the ledger and accounts; never over a
  /// form, a page above the home, the plan, or before the ledger opens.
  void _ads() {
    if (controller.disposed) return;
    controller.adsVisible.value =
        controller.state != null && routes.depth <= 1 && scope.area.value != 2;
  }

  Future<void> loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      // Unreadable preferences fall back to defaults; the ledger is apart.
      if (mounted) setState(() => prefs.value = HandyPreferences());
    }
  }

  Future<void> save(HandyPreferences next) async {
    await repo.save(next);
    if (mounted) setState(() => prefs.value = next);
  }

  Widget _ready(Widget Function() page) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (controller.state == null && controller.error != null)
        return HandyLoadError(
          title: tr(
            context,
            'Spend could not open your ledger',
            'Spend chưa mở được sổ',
          ),
          error: controller.error!,
          onRetry: controller.load,
        );
      if (controller.state == null) return const HandyLoading();
      return page();
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final name = s.name ?? '/';
    final Widget Function()? page = switch (name.split('/')) {
      ['', 'settings'] => () => SpendSettingsPage(
        scope: scope,
        read: () => prefs.value!,
        save: save,
      ),
      ['', 'settings', 'categories'] => () => CategoriesPage(scope: scope),
      ['', 'settings', 'rules'] => () => RulesPage(scope: scope),
      ['', 'settings', 'templates'] => () => TemplatesPage(scope: scope),
      ['', 'people'] => () => PeoplePage(scope: scope),
      ['', 'person', final id] => () => PersonPage(scope: scope, id: id),
      ['', 'receipt', final id] => () => ReceiptPage(scope: scope, id: id),
      ['', 'imports'] => () => ImportsPage(scope: scope),
      ['', 'import'] => () => ImportPage(scope: scope),
      ['', 'import', final id] => () => ImportPage(scope: scope, account: id),
      ['', 'account', final id] => () => AccountPage(scope: scope, id: id),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(
      settings: s,
      builder: (_) => _ready(() {
        // A web link to an import needs an account to import into.
        if (name.startsWith('/import') && scope.openAccounts.isEmpty)
          return HandyPage(
            title: tr(context, 'Import a statement', 'Nhập sao kê'),
            children: [
              HandyEmpty(
                title: tr(
                  context,
                  'Add an account first',
                  'Hãy thêm tài khoản trước',
                ),
              ),
            ],
          );
        return page();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return SpendPrivacyGate(
      controller: controller,
      authentication: scope.privacy,
      accent: spendAccent,
      child: HandyApp(
        brand: HandyBrand.spend,
        app: 'spend',
        title: 'Handy Spend',
        accent: spendAccent,
        theme: p?.theme ?? 'system',
        locale: p?.locale ?? 'system',
        adsVisible: controller.adsVisible,
        navigatorObservers: [routes],
        onGenerateRoute: route,
        home: p == null
            ? const HandyLoading()
            : _ready(
                () => SpendShell(scope: scope, enableDrop: widget.enableDrop),
              ),
      ),
    );
  }
}

/// Counts the routes above the home so ads know when a form or page is up.
class _Depth extends NavigatorObserver {
  final VoidCallback changed;
  int depth = 0;
  _Depth(this.changed);
  void _set(int next) {
    depth = next < 0 ? 0 : next;
    // Route changes land mid-frame; the banner follows on the next one.
    WidgetsBinding.instance.addPostFrameCallback((_) => changed());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth + 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth - 1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth - 1);
}
