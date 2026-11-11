import 'dart:async';
import 'dart:ui' show DartPluginRegistrant, PlatformDispatcher;
import 'package:flutter/widgets.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:home_widget/home_widget.dart';
import 'controller.dart';
import 'home_widget.dart';
import 'widget_data.dart';

/// Every widget the app feeds, with the key prefix its data uses.
const habitWidgetFeeds = [
  (habitWidgetClass, '', 'today'),
  (singleHabitWidgetClass, 'habit_', 'habit'),
  (routineWidgetClass, 'routine_', 'routine'),
  (weekWidgetClass, 'week_', 'week'),
  (yearWidgetClass, 'year_', 'year'),
];

/// Writes what every widget shows and redraws them. Used by the app after
/// each change and by [habitWidgetTapped] after a check-in from the home
/// screen. Pro is passed by the app; in the background the last value the
/// app wrote is used. Never throws.
Future<void> publishHabitWidgets(
  HabitState s, {
  bool? pro,
  DateTime? now,
}) async {
  if (!homeWidgetsSupported) return;
  try {
    final owned = pro ?? (await HomeWidget.getWidgetData<String>('pro')) == '1';
    final locale = s.settings['locale'] as String? ?? 'system';
    final vi =
        locale == 'vi' ||
        locale == 'system' &&
            PlatformDispatcher.instance.locale.languageCode == 'vi';
    final today = habitDayAt(s, now ?? DateTime.now());
    final views = habitWidgetViews(s, today, vi: vi, pro: owned);
    await HomeWidget.saveWidgetData<String>('pro', owned ? '1' : '0');
    for (final (cls, prefix, key) in habitWidgetFeeds) {
      for (final e in views[key]!.toData().entries) {
        await HomeWidget.saveWidgetData<String>('$prefix${e.key}', e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: cls);
    }
    // Redraw just after each of the next midnights, so a new day starts
    // with an empty bead even when the app is not opened.
    final base = DateTime.now();
    final midnights = [
      for (var i = 1; i <= 3; i++)
        DateTime(base.year, base.month, base.day + i, 0, 1),
    ];
    for (final (cls, _, _) in habitWidgetFeeds) {
      try {
        await HomeWidget.scheduleWidgetUpdates(
          midnights,
          qualifiedAndroidName: cls,
        );
      } catch (_) {}
    }
  } catch (_) {}
}

/// A tap on a widget's bead, run in the background (no app on screen):
/// `handy-habit://tap/<id>` records one check-in as the app would (done,
/// one more, or one incident), then every widget is redrawn from the saved
/// data. `handy-habit://refresh` only redraws (a new day began). The app
/// reads the saved data again when it next comes to the front.
@pragma('vm:entry-point')
Future<void> habitWidgetTapped(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (uri == null) return;
  final c = HabitController();
  try {
    await c.load();
    final s = c.state;
    if (s == null) return;
    if (uri.host == 'tap') {
      final id = uri.pathSegments.firstOrNull;
      final today = habitDayAt(s, DateTime.now());
      final h = s.liveHabits
          .where((x) => x.id == id && !x.archived)
          .firstOrNull;
      if (h != null && widgetTapMode(h, today, HabitIndex.of(s)) == 'tap') {
        await c.change(
          (s) => record(
            s,
            HabitEvent(id: uid(), habit: h.id, day: today, value: 1000),
            today: today,
          ),
        );
      }
    }
    await publishHabitWidgets(c.state!);
  } catch (_) {
    // The widget falls back to what the app last wrote.
  } finally {
    c.dispose();
  }
}
