import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_habit/app.dart';
import 'package:handy_habit/controller.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' as fixtures;

/// Holds what was saved and hands back what is to be opened.
class _Files implements HandyFiles {
  final saved = <String, Uint8List>{};
  ImportedBytes? next;
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    saved[name] = bytes;
    return name;
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => next;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

void main() {
  testWidgets('a routine is shared as a page and imported back for review', (
    t,
  ) async {
    // A platform without a share sheet: the page is saved as a file.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final store = fixtures.MemoryStore()
      ..value = HabitState(
        routines: [
          Routine(
            id: 'r',
            title: 'Wind down',
            steps: [
              RoutineStep(id: 'a', title: 'Dim the lights', seconds: 120),
              RoutineStep(id: 'b', title: 'Read', seconds: 600),
            ],
          ),
        ],
        settings: {'onboarded': true, 'locale': 'en'},
      );
    final c = HabitController(open: () async => store);
    await c.load();
    final files = _Files();
    await t.pumpWidget(
      HabitApp(
        controller: c,
        files: files,
        clock: () => DateTime.utc(2024, 1, 8, 12),
      ),
    );
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.pushNamed('/routine/r');
    await t.pumpAndSettle();
    await fixtures.tapKey(t, 'more-menu');
    await fixtures.tapKey(t, 'routine-share');
    final page = files.saved['Wind down.html']!;
    expect(utf8.decode(page), contains('Dim the lights'));
    expect(c.state!.routines, hasLength(1));

    // Someone else opens it: New routine › Import.
    nav.pop();
    await t.pumpAndSettle();
    files.next = ImportedBytes('Wind down.html', page);
    await fixtures.tapKey(t, 'nav-2');
    await fixtures.tapKey(t, 'routine-new');
    await fixtures.tapKey(t, 'quick-routine-import');
    expect(
      t
          .widget<TextField>(find.byKey(const Key('field-title')))
          .controller!
          .text,
      'Wind down',
    );
    expect(c.state!.routines, hasLength(1));
    await fixtures.tapKey(t, 'editor-save');
    expect(c.state!.routines, hasLength(2));
    expect(c.state!.routines.last.steps, hasLength(2));
    expect(c.state!.routines.last.id, isNot('r'));

    // Not a routine: refused, nothing saved.
    files.next = ImportedBytes(
      'x.html',
      Uint8List.fromList(utf8.encode('<p>')),
    );
    await fixtures.tapKey(t, 'routine-new');
    await fixtures.tapKey(t, 'quick-routine-import');
    expect(
      find.text('This file is not a routine shared from Handy Habit.'),
      findsOneWidget,
    );
    expect(c.state!.routines, hasLength(2));
    await t.pumpWidget(const SizedBox());
    c.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
