import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards/ui/form.dart';
import 'package:handy_boards/ui/labels.dart';
import 'package:handy_boards/features/board_views.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards/scope.dart';
import 'ui_test.dart' as fixtures;

Widget host(Widget child, {String locale = 'vi'}) => MaterialApp(
  locale: Locale(locale),
  supportedLocales: const [Locale('en'), Locale('vi')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);
void main() {
  testWidgets(
    'conditional field is absent and does not block saving unrelated format',
    (t) async {
      var saved = false;
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => boardForm(
                context,
                'Export',
                [
                  const BoardField(
                    'format',
                    'Format',
                    'Định dạng',
                    kind: 'select',
                    options: {'zip': 'ZIP', 'template': 'Template'},
                  ),
                  BoardField(
                    'private',
                    'Template option',
                    'Tùy chọn mẫu',
                    visibleWhen: (v) => v['format'] == 'template',
                  ),
                ],
                {'format': 'zip', 'private': ''},
                (_) async {
                  saved = true;
                },
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      );
      await fixtures.tap(t, find.text('Mở'));
      expect(find.text('Tùy chọn mẫu'), findsNothing);
      await fixtures.tap(t, find.text('ZIP'));
      await fixtures.tap(t, find.text('Template').last);
      expect(find.text('Tùy chọn mẫu'), findsOneWidget);
      await fixtures.tap(t, find.text('Template').first);
      await fixtures.tap(t, find.text('ZIP').last);
      await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
      expect(saved, true);
    },
  );
  testWidgets(
    'timed deadline label converts UTC to board day before Vietnamese formatting',
    (t) async {
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Text(
              deadlineLabel(context, {
                'kind': 'time',
                'at': '2026-11-02T02:30:00Z',
                'zone': 'UTC',
              }, 'America/New_York'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final rendered = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join('\n');
      expect(rendered, contains('1/11/2026'));
      expect(find.textContaining('America/New_York'), findsOneWidget);
      expect(find.textContaining('02/11/2026'), findsNothing);
      expect(find.textContaining('T02:30'), findsNothing);
    },
  );
  testWidgets(
    'Vietnamese priority explanations and weekdays contain no machine codes',
    (t) async {
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => Column(
              children: [
                for (final reason in [
                  'priority:2',
                  'due:1 days',
                  'category weight:5',
                  'estimate<=30m',
                  'blocked',
                ])
                  Text(priorityReason(context, reason)),
                Text(weekdayName(context, 7)),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Ưu tiên: Cao'), findsOneWidget);
      expect(find.text('Đến hạn sau 1 ngày'), findsOneWidget);
      expect(find.text('Điểm nhóm: 5'), findsOneWidget);
      expect(find.text('Ước lượng tối đa 30 phút'), findsOneWidget);
      expect(find.text('Chủ nhật'), findsOneWidget);
      expect(find.textContaining('priority:'), findsNothing);
    },
  );
  testWidgets(
    'DST validation error is localized and failed form retains input',
    (t) async {
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => boardForm(
                context,
                'Nhắc việc',
                [const BoardField('time', 'Time', 'Giờ')],
                {'time': ''},
                (_) async =>
                    throw const FormatException('Time falls in a DST gap'),
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      );
      await fixtures.tap(t, find.text('Mở'));
      await t.enterText(find.byType(TextField), '02:30');
      await fixtures.tap(t, find.byKey(const Key('boards-form-save')));
      expect(
        find.text(
          'Giờ này không tồn tại do đổi giờ mùa hè. Hãy chọn giờ khác.',
        ),
        findsOneWidget,
      );
      expect(find.text('02:30'), findsOneWidget);
      expect(find.textContaining('FormatException'), findsNothing);
    },
  );
  testWidgets(
    'form toggles/selectors expose distinct property names to semantics',
    (t) async {
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => boardForm(
                context,
                'Mẫu',
                [
                  const BoardField(
                    'confirm',
                    'Review private data',
                    'Kiểm tra dữ liệu riêng',
                    kind: 'bool',
                    optional: true,
                  ),
                  const BoardField(
                    'date',
                    'Start date',
                    'Ngày bắt đầu',
                    kind: 'date',
                    optional: true,
                  ),
                  const BoardField(
                    'status',
                    'Status',
                    'Trạng thái',
                    kind: 'select',
                    options: {'todo': 'Cần làm'},
                  ),
                ],
                {'confirm': false, 'date': null, 'status': 'todo'},
                (_) async {},
              ),
              child: const Text('Mở'),
            ),
          ),
        ),
      );
      await fixtures.tap(t, find.text('Mở'));
      expect(
        find.bySemanticsLabel(RegExp('Kiểm tra dữ liệu riêng')),
        findsWidgets,
      );
      expect(find.bySemanticsLabel(RegExp('Ngày bắt đầu')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Trạng thái')), findsWidgets);
      expect(find.text('Bật'), findsNothing);
      semantics.dispose();
    },
  );
  testWidgets('Ctrl Enter submits the current form exactly once', (t) async {
    var saved = 0;
    String? title;
    await t.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => boardForm(
              context,
              'Task',
              [const BoardField('title', 'Title', 'Tên')],
              {'title': ''},
              (v) async {
                saved++;
                title = v['title'];
              },
            ),
            child: const Text('Mở'),
          ),
        ),
      ),
    );
    await fixtures.tap(t, find.text('Mở'));
    await t.enterText(find.byType(TextField), 'Chuẩn bị bài');
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(saved, 1);
    expect(title, 'Chuẩn bị bài');
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('task checkbox semantics include its title', (t) async {
    final semantics = t.ensureSemantics();
    final c = BoardsController(
      open: () async => fixtures.TestStore(fixtures.sample()),
    );
    await c.load();
    await t.pumpWidget(
      host(TaskRow(scope: BoardsScope(c), task: c.state!.get('tasks', 'task'))),
    );
    await t.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Hoàn tất task: Practice equations')),
      findsOneWidget,
    );
    await t.pumpWidget(const SizedBox());
    c.dispose();
    semantics.dispose();
  });
}
