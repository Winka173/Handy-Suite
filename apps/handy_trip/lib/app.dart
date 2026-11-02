import 'dart:async';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'scope.dart';
import 'platform/location.dart';
import 'platform/reminders.dart';
import 'shell/shell.dart';

class TripApp extends StatefulWidget {
  final TripController? controller;
  final HandyFiles files;
  final ForegroundLocation? locationPort;
  final DateTime Function()? clock;
  const TripApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.locationPort,
    this.clock,
  });
  @override
  State<TripApp> createState() => _TripAppState();
}

class _TripAppState extends State<TripApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? TripController();
  int? _syncedRevision;
  late final scope = TripScope(
    controller: c,
    files: widget.files,
    locationPort: widget.locationPort ?? SystemForegroundLocation(),
    reminders: TripReminders(),
    clock: widget.clock ?? DateTime.now,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(changed);
    if (c.state == null) unawaited(c.load());
  }

  void changed() {
    final s = c.state;
    if (s != null && s.revision != _syncedRevision) {
      _syncedRevision = s.revision;
      unawaited(
        scope.reminders.sync(s).catchError((Object _) {
          _syncedRevision = null;
        }),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncedRevision = null;
      changed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(changed);
    scope.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => HandyApp(
      brand: HandyBrand.trip,
      app: 'trip',
      title: 'Handy Trip',
      accent: const Color(0xff0284c7),
      locale: c.state?.settings['locale'] as String? ?? 'system',
      theme: c.state?.settings['theme'] as String? ?? 'system',
      adsVisible: c.adsVisible,
      home: c.state == null
          ? HandyLoading(error: c.error, retry: c.load)
          : TripShell(scope: scope),
      onGenerateRoute: (route) => MaterialPageRoute<void>(
        settings: route,
        builder: (context) => ListenableBuilder(
          listenable: c,
          builder: (context, _) => c.state == null
              ? HandyLoading(error: c.error, retry: c.load)
              : TripShell(
                  scope: scope,
                  initialArea: switch (route.name) {
                    '/explore' => 1,
                    '/journal' => 2,
                    '/passport' => 3,
                    _ => 0,
                  },
                ),
        ),
      ),
    ),
  );
}
