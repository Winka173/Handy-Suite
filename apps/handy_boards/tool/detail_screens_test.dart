import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_boards/app.dart' show boardsBrand;
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/scope.dart';
import 'package:handy_boards/features/advanced.dart';
import 'package:handy_boards/features/editors.dart';
import 'package:handy_boards/features/task_detail.dart';
import 'package:handy_boards/features/task_tools.dart';
import 'package:handy_boards/features/rule_editor.dart';
import 'package:handy_boards/features/planner.dart';
import 'package:handy_boards/features/study.dart';
import 'package:handy_boards/features/portability.dart';
import 'package:handy_boards/features/saved_view_editor.dart';
import 'package:handy_boards/features/exam_editor.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'dart:io';
import '../test/ui_test.dart' as fixtures;
import 'screens_test.dart' as capture;

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    const fonts = '../../packages/handy_ui/fonts';
    await capture.loadFont('packages/handy_ui/Geist', [
      '$fonts/Geist-Regular.ttf',
      '$fonts/Geist-Medium.ttf',
      '$fonts/Geist-Bold.ttf',
    ]);
    await capture.loadFont('packages/handy_ui/Bricolage', [
      '$fonts/BricolageGrotesque-Medium.ttf',
      '$fonts/BricolageGrotesque-Display.ttf',
    ]);
    await capture.loadFont('PlusJakartaSans', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await capture.loadFont('MaterialIcons', [
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });
  for (final (name, width, locale, scale) in [
    ('phone', 375.0, 'en', 1.0),
    ('large-text', 320.0, 'vi', 2.0),
    ('desktop', 1440.0, 'en', 1.0),
  ]) {
    testWidgets('$name editors and advanced review', (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      // Approved test-owned channel fixture, absent from app/release sources.
      const channel = MethodChannel('boards_capture_store');
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
      await t.runAsync(() async {
        lifetime.accept(await lifetime.store.read());
      });
      var data = fixtures.sample();
      data = data.put(
        'tasks',
        data.get('tasks', 'task').copy({
          'start': {'kind': 'day', 'day': '2026-11-01'},
        }),
      );
      data = saveTask(
        data,
        newTask(
          data,
          'b',
          'Checkpoint',
          category: data.rows('categories').last.id,
        ).copy({
          'kind': 'milestone',
          'start': {'kind': 'day', 'day': '2026-11-05'},
          'due': {'kind': 'day', 'day': '2026-11-05'},
        }),
      );
      final c = BoardsController(open: () async => fixtures.TestStore(data));
      await c.load();
      final scope = BoardsScope(c, clock: () => DateTime.utc(2026, 11, 2));
      Future<void> mount(Widget page) async {
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          RepaintBoundary(
            key: capture.boundary,
            child: LifetimeScope(
              notifier: lifetime,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                supportedLocales: const [Locale('en'), Locale('vi')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: buildHandyTheme(
                  const Color(0xffa61c8e),
                  Brightness.light,
                  boardsBrand,
                ),
                home: page,
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await mount(TaskDetail(scope: scope, id: 'task'));
      await capture.shot(t, '$name-task-detail');
      for (final (id, open) in <(String, Future<void> Function(BuildContext))>[
        ('task-editor', (context) => editTask(context, scope, 'task')),
        ('rule-editor', (context) => editAutomationRule(context, scope, 'b')),
        (
          'exam-editor',
          (context) => editExam(
            context,
            scope,
            'b',
            data.rows('categories').first.id,
            task: c.state!.get('tasks', 'task'),
          ),
        ),
        ('saved-view-editor', (context) => editSavedView(context, scope, 'b')),
        ('export', (context) => exportBoards(context, scope, 'b')),
      ]) {
        await mount(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => open(context),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await fixtures.tap(t, find.text('Open'));
        if (id == 'working-calendar')
          await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
        await capture.shot(t, '$name-$id');
      }
      await mount(StudyPage(scope: scope, board: 'b'));
      await capture.shot(t, '$name-study');
      await mount(FocusPage(scope: scope, task: 'task'));
      await capture.shot(t, '$name-focus');
      await mount(
        Scaffold(
          body: BoardsCalendar(scope: scope, board: 'b'),
        ),
      );
      await fixtures.tap(
        t,
        find.widgetWithText(ChoiceChip, locale == 'vi' ? 'Tuần' : 'Week'),
      );
      await capture.shot(t, '$name-calendar-week');
      await mount(AdvancedPage(scope: scope, board: 'b'));
      await capture.shot(t, '$name-timeline');
      for (final (id, en, vi) in [
        ('priority', 'Smart priority', 'Ưu tiên thông minh'),
        ('fields', 'Custom fields', 'Trường tùy chỉnh'),
        ('views', 'Saved views', 'View đã lưu'),
        ('rules', 'Rules', 'Quy tắc'),
        ('study-report', 'Study report', 'Báo cáo học tập'),
      ]) {
        await fixtures.tap(
          t,
          find.widgetWithText(ChoiceChip, locale == 'vi' ? vi : en),
        );
        await capture.shot(t, '$name-advanced-$id');
      }
      await t.pumpWidget(const SizedBox());
      c.dispose();
      lifetime.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  }
}
