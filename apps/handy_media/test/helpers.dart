import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/app.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

/// The app's own theme, for widgets tested on their own.
final kitTheme = buildHandyTheme(mediaAccent, Brightness.light);

class Prefs implements PreferencesRepository {
  HandyPreferences value = HandyPreferences(locale: 'en');
  @override
  Future<HandyPreferences> load() async => value;
  @override
  Future<void> save(HandyPreferences next) async => value = next;
}

/// The whole app, on [documents] and [files].
Future<void> start(
  WidgetTester tester, {
  required DocumentRepository documents,
  required HandyFiles files,
  ScanCamera? camera,
  ExportHistory? history,
  Prefs? prefs,
  Map<String, DocumentRepository>? drafts,
  Size size = const Size(800, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaApp(
      files: files,
      documents: documents,
      preferences: prefs ?? Prefs(),
      camera: camera,
      history: history,
      drafts: drafts == null ? null : (id) => drafts[id] ??= Memory(),
    ),
  );
  await tester.pumpAndSettle();
}

/// A document store in memory.
class Memory implements DocumentRepository {
  String? text;
  bool fail = false;
  int attempts = 0;
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String value) async {
    attempts++;
    if (fail) throw StateError('Disk full');
    text = value;
  }
}

Future<void> go(WidgetTester tester, String route) async {
  Navigator.of(
    tester.element(find.byKey(const Key('media-studio'))),
  ).pushNamed(route);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(f, 200, scrollable: list);
    }
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Picks [key] from whichever visible "More" menu holds it.
Future<void> menu(WidgetTester tester, String key) async {
  final menus = find.byKey(const Key('more-menu')).hitTestable();
  for (var i = menus.evaluate().length - 1; i >= 0; i--) {
    await tester.tap(menus.at(i));
    await tester.pumpAndSettle();
    final item = find.byKey(Key(key));
    if (item.evaluate().isNotEmpty) {
      await tester.tap(item);
      await tester.pumpAndSettle();
      return;
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }
  fail('No menu on screen holds $key');
}

/// Scrolls [finder] into view in the visible list, then taps it.
Future<void> press(WidgetTester tester, Finder finder) async {
  // A message from the last step may float over the control.
  final messenger = find.byType(ScaffoldMessenger);
  if (messenger.evaluate().isNotEmpty) {
    tester.state<ScaffoldMessengerState>(messenger.first).clearSnackBars();
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable()
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(finder, 160, scrollable: list);
    }
  }
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
