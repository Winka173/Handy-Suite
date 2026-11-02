import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/app.dart' show boardsBrand;
import 'package:handy_boards/scope.dart';
import 'package:handy_boards/features/advanced.dart';
import 'package:handy_boards/features/study.dart';
import 'package:handy_boards/features/task_tools.dart';
import 'package:handy_boards/features/portability.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'ui_test.dart' as fixtures;

void main() {
  test(
    'real board/timeline/study PDFs contain Vietnamese text and serializable output',
    () async {
      var s = fixtures.sample();
      s = s.put(
        'tasks',
        s.get('tasks', 'task').copy({
          'title': 'Bài tập toán',
          'start': {'kind': 'day', 'day': '2026-11-01'},
        }),
      );
      final out = Directory('../../docs/qa/evidence/exports')
        ..createSync(recursive: true);
      for (final (name, render) in [
        ('summary', boardPdf),
        ('study', studyPlannerPdf),
      ]) {
        final bytes = await render(s, 'b');
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        File('${out.path}/boards-$name.pdf').writeAsBytesSync(bytes);
      }
    },
  );
  testWidgets(
    'Study grade planner remains free and shows impossible targets honestly',
    (t) async {
      var s = fixtures.sample();
      final cat = s.rows('categories').first.id,
          subject = s.rows('subjects').first;
      s = s
          .put('subjects', subject.copy({'target': 90}))
          .put(
            'grades',
            BoardRecord({
              'id': 'g1',
              'board': 'b',
              'category': cat,
              'title': 'Midterm',
              'weight': 50,
              'possible': 10,
              'earned': 2,
            }),
          )
          .put(
            'grades',
            BoardRecord({
              'id': 'g2',
              'board': 'b',
              'category': cat,
              'title': 'Final',
              'weight': 50,
              'possible': 10,
            }),
          );
      final c = BoardsController(open: () async => fixtures.TestStore(s));
      await c.load();
      await t.pumpWidget(
        HandyApp(
          app: 'boards',
          title: 'Boards',
          accent: const Color(0xffa61c8e),
          home: StudyPage(scope: BoardsScope(c), board: 'b'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('160.00'), findsOneWidget);
      expect(
        find.text('Target impossible with remaining weight'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'focus recovers persisted session and pauses using saved timestamps',
    (t) async {
      final start = DateTime.utc(2026, 11, 2),
          s = startFocus(fixtures.sample(), 'task', start),
          c = BoardsController(open: () async => fixtures.TestStore(s));
      await c.load();
      await t.pumpWidget(
        HandyApp(
          app: 'boards',
          title: 'Boards',
          accent: const Color(0xffa61c8e),
          home: FocusPage(
            scope: BoardsScope(
              c,
              clock: () => start.add(const Duration(seconds: 125)),
            ),
            task: 'task',
          ),
        ),
      );
      await t.pump();
      expect(find.text('2:05'), findsOneWidget);
      await fixtures.tap(t, find.text('Pause'));
      await fixtures.settleIO(t);
      expect(c.state!.rows('sessions').single.number('elapsed'), 125);
      expect(c.state!.rows('sessions').single.data['runningAt'], isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'advanced UI uses actual LifetimeScope and an unconfigured store never unlocks',
    (t) async {
      final c = BoardsController(
        open: () async => fixtures.TestStore(fixtures.sample()),
      );
      await c.load();
      await t.pumpWidget(
        HandyApp(
          app: 'boards',
          title: 'Boards',
          accent: const Color(0xffa61c8e),
          home: AdvancedPage(scope: BoardsScope(c), board: 'b'),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.textContaining('Advanced planning uses Pro Lifetime'),
        findsOneWidget,
      );
      expect(find.text('Add field definition'), findsNothing);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'advanced priority/fields/views/rules render under test-owned native store response',
    (t) async {
      // Native channel fixture exists only in this test, never in app/release code.
      const channel = MethodChannel('boards_test_store');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {
              'status': 'owned',
              'productId': 'boards_test_pro',
              'owned': true,
              'verified': true,
            },
          );
      final lifetime = LifetimeController(
        const MonetizationConfig(productId: 'boards_test_pro'),
        NativeLifetimeStore(productId: 'boards_test_pro', channel: channel),
      );
      lifetime.accept(await lifetime.store.read());
      expect(lifetime.pro, true);
      final initial = fixtures.sample();
      final c = BoardsController(
        open: () async => fixtures.TestStore(
          initial.put(
            'tasks',
            initial.get('tasks', 'task').copy({
              'start': {'kind': 'day', 'day': '2026-11-01'},
            }),
          ),
        ),
      );
      await c.load();
      await t.pumpWidget(
        LifetimeScope(
          notifier: lifetime,
          child: MaterialApp(
            theme: buildHandyTheme(
              const Color(0xffa61c8e),
              Brightness.light,
              boardsBrand,
            ),
            home: AdvancedPage(scope: BoardsScope(c), board: 'b'),
          ),
        ),
      );
      await t.pumpAndSettle();
      // The timeline and its critical path were removed on 2026-11-03.
      expect(find.widgetWithText(ChoiceChip, 'Timeline'), findsNothing);
      expect(
        t
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Smart priority'),
            )
            .selected,
        isTrue,
      );
      expect(c.state!.rows('tasks').single.id, 'task');
      for (final (tab, expected) in [
        ('Custom fields', 'Add field definition'),
        ('Saved views', 'Save a smart view'),
        ('Rules', 'New rule'),
      ]) {
        await fixtures.tap(t, find.widgetWithText(ChoiceChip, tab));
        expect(find.text(expected), findsOneWidget);
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
      lifetime.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}
