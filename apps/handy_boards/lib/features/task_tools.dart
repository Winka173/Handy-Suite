import 'dart:async';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'advanced.dart';

Future<void> taskCustomFields(
  BuildContext context,
  BoardsScope scope,
  String id,
) async {
  if (!await requireBoardsPro(context) || !context.mounted) return;
  final task = scope.state.get('tasks', id),
      fields = scope.state
          .rows('fields')
          .where((f) => f.str('board') == task.str('board'))
          .toList(),
      values = object(task.data['custom'] ?? {});
  if (fields.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          tr(
            context,
            'Add field definitions in Advanced planning first.',
            'Thêm định nghĩa trường ở Kế hoạch nâng cao trước.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Close', 'Đóng')),
          ),
        ],
      ),
    );
    return;
  }
  await boardForm(
    context,
    tr(context, 'Task custom fields', 'Trường tùy chỉnh của task'),
    [
      for (final f in fields)
        BoardField(
          f.id,
          f.str('title'),
          f.str('title'),
          kind: switch (f.str('type')) {
            'checkbox' => 'bool',
            'single' => 'select',
            'multi' => 'multi',
            'date' => 'date',
            _ => 'text',
          },
          optional: true,
          options: ['single', 'multi'].contains(f.str('type'))
              ? {
                  if (f.str('type') == 'single')
                    '': tr(context, 'Not set', 'Chưa đặt'),
                  for (final v in f.strings('options')) v: v,
                }
              : null,
        ),
    ],
    {
      for (final f in fields)
        f.id: f.str('type') == 'multi'
            ? (values[f.id] as List? ?? [])
            : values[f.id] ?? (f.str('type') == 'single' ? '' : null),
    },
    (v) async {
      final custom = <String, dynamic>{};
      for (final f in fields) {
        final raw = v[f.id];
        if (raw == null || raw == '') continue;
        custom[f.id] = f.str('type') == 'multi'
            ? List<String>.from(raw as List)
            : raw;
      }
      await scope.controller.change(
        (s) => s.put('tasks', s.get('tasks', id).copy({'custom': custom})),
      );
    },
    footer: [
      Text(
        tr(
          context,
          'Choose any listed options. Decimal values keep their exact digits.',
          'Chọn các lựa chọn trong danh sách. Giá trị thập phân giữ nguyên chữ số.',
        ),
      ),
    ],
  );
}

Future<void> taskTags(
  BuildContext context,
  BoardsScope scope,
  String id,
) async {
  final t = scope.state.get('tasks', id);
  await boardForm(
    context,
    tr(context, 'Task tags', 'Tag của task'),
    [
      const BoardField(
        'tags',
        'Tags separated by commas',
        'Các tag ngăn cách bằng dấu phẩy',
        optional: true,
      ),
    ],
    {
      'tags': t
          .strings('tags')
          .map((id) => scope.state.get('tags', id).str('title'))
          .join(', '),
    },
    (v) async {
      await scope.controller.change((s) => assignTags(s, id, v['tags']));
    },
  );
}

Future<void> taskRecurrence(
  BuildContext context,
  BoardsScope scope,
  String id,
) async {
  final t = scope.state.get('tasks', id),
      existing = scope.state
          .rows('recurrence')
          .where((r) => r.str('task') == id)
          .firstOrNull;
  await boardForm(
    context,
    tr(context, 'Recurring task', 'Task lặp lại'),
    [
      BoardField(
        'frequency',
        'Frequency',
        'Tần suất',
        kind: 'select',
        options: {
          'daily': tr(context, 'Daily', 'Hằng ngày'),
          'weekly': tr(context, 'Weekly weekdays', 'Theo thứ trong tuần'),
          'monthly': tr(
            context,
            'Monthly, skip missing dates',
            'Hằng tháng, bỏ ngày không có',
          ),
        },
      ),
      const BoardField(
        'interval',
        'Every N periods',
        'Mỗi N kỳ',
        kind: 'number',
      ),
      const BoardField('start', 'Start', 'Bắt đầu', kind: 'date'),
      const BoardField(
        'until',
        'End date',
        'Ngày kết thúc',
        kind: 'date',
        optional: true,
      ),
      const BoardField(
        'weekdays',
        'Weekly weekdays 1–7, comma separated',
        'Các thứ 1–7, ngăn dấu phẩy',
        optional: true,
      ),
      const BoardField(
        'exceptions',
        'Skip dates YYYY-MM-DD, comma separated',
        'Bỏ các ngày YYYY-MM-DD, ngăn dấu phẩy',
        optional: true,
      ),
      const BoardField(
        'through',
        'Generate through (max 366 new tasks)',
        'Tạo đến ngày (tối đa 366 task mới)',
        kind: 'date',
      ),
    ],
    {
      'frequency': existing?.str('frequency') ?? 'daily',
      'interval': '${existing?.number('interval', 1) ?? 1}',
      'start':
          existing?.str('start') ??
          scope.clock().toIso8601String().substring(0, 10),
      'until': existing?.data['until'],
      'weekdays': (existing?.data['weekdays'] as List? ?? []).join(','),
      'exceptions': existing?.strings('exceptions').join(',') ?? '',
      'through': scope
          .clock()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
    },
    (v) async {
      await scope.controller.change((s) {
        final r = BoardRecord({
          'id': existing?.id ?? newId(),
          'task': id,
          'board': t.str('board'),
          'frequency': v['frequency'],
          'interval': int.parse(v['interval']),
          'start': v['start'],
          'until': v['until'],
          'zone': s.get('boards', t.str('board')).str('zone'),
          'weekdays': (v['weekdays'] as String).trim().isEmpty
              ? [DateTime.parse(v['start']).weekday]
              : (v['weekdays'] as String)
                    .split(',')
                    .map((v) => int.parse(v.trim()))
                    .toList(),
          'exceptions': (v['exceptions'] as String)
              .split(',')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          'status': s
              .rows('statuses')
              .firstWhere(
                (r) => r.str('board') == t.str('board') && !r.flag('done'),
              )
              .id,
        });
        return generateOccurrences(s.put('recurrence', r), r.id, v['through']);
      });
    },
    footer: [
      Text(
        tr(
          context,
          'Creates separate dated occurrences with an idempotent rule/day key. The source task is retained. No unlimited background generation.',
          'Tạo từng task theo ngày với khóa rule/ngày không trùng. Giữ task nguồn. Không tự tạo vô hạn ở nền.',
        ),
      ),
    ],
  );
}

class FocusPage extends StatefulWidget {
  final BoardsScope scope;
  final String task;
  const FocusPage({super.key, required this.scope, required this.task});
  @override
  State<FocusPage> createState() => _FocusState();
}

class _FocusState extends State<FocusPage> {
  late final Timer pulse;
  @override
  void initState() {
    super.initState();
    pulse = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    pulse.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.scope.controller,
    builder: (context, _) {
      final scope = widget.scope,
          t = scope.state.get('tasks', widget.task),
          sessions = scope.state
              .rows('sessions')
              .where((r) => r.str('task') == widget.task)
              .toList(),
          session = sessions.lastOrNull;
      final running = session?.data['runningAt'] != null,
          delta = running
              ? scope
                    .clock()
                    .difference(DateTime.parse(session!.str('runningAt')))
                    .inSeconds
              : 0,
          total =
              (session?.number('elapsed') ?? 0) +
              (delta < 0 || delta > 86400 ? 0 : delta);
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Focus on one task', 'Tập trung một việc')),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.str('title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    if (running && (delta < 0 || delta > 86400)) ...[
                      Text(
                        tr(
                          context,
                          'Clock changed or the session exceeded 24 hours. Only previously saved seconds are shown; review before continuing.',
                          'Giờ máy thay đổi hoặc phiên vượt 24 giờ. Chỉ hiện số giây đã lưu; cần kiểm tra trước khi tiếp tục.',
                        ),
                      ),
                      TextButton(
                        onPressed: () => scope.run(
                          context,
                          () => boardForm(
                            context,
                            tr(
                              context,
                              'Review interrupted session',
                              'Kiểm tra phiên bị gián đoạn',
                            ),
                            [
                              const BoardField(
                                'seconds',
                                'Additional worked seconds you confirm (0–86400)',
                                'Số giây làm thêm bạn xác nhận (0–86400)',
                                kind: 'number',
                              ),
                            ],
                            {'seconds': ''},
                            (v) async {
                              await scope.controller.change(
                                (s) => reviewInterruptedFocus(
                                  s,
                                  session!.id,
                                  int.parse(v['seconds']),
                                  scope.clock(),
                                ),
                              );
                            },
                          ),
                        ),
                        child: Text(
                          tr(
                            context,
                            'Confirm actual work duration',
                            'Xác nhận thời lượng thực tế',
                          ),
                        ),
                      ),
                    ],
                    Text(
                      '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text(
                      tr(
                        context,
                        'Elapsed time is computed from saved timestamps. The app does not run an uninterrupted background timer.',
                        'Thời gian tính từ mốc đã lưu, không phải bộ đếm chạy liên tục ở nền.',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: scope.controller.busy
                          ? null
                          : () => scope.run(
                              context,
                              () => scope.controller.change(
                                (s) => session == null
                                    ? startFocus(s, t.id, scope.clock())
                                    : running
                                    ? pauseFocus(s, session.id, scope.clock())
                                    : resumeFocus(s, session.id, scope.clock()),
                              ),
                            ),
                      child: Text(
                        tr(
                          context,
                          session == null
                              ? 'Start'
                              : running
                              ? 'Pause'
                              : 'Resume',
                          session == null
                              ? 'Bắt đầu'
                              : running
                              ? 'Tạm dừng'
                              : 'Tiếp tục',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: session == null || scope.controller.busy
                          ? null
                          : () => scope.run(context, () async {
                              if (running)
                                await scope.controller.change(
                                  (s) =>
                                      pauseFocus(s, session.id, scope.clock()),
                                );
                              await scope.controller.change(
                                (s) => startFocus(s, t.id, scope.clock()),
                              );
                            }),
                      child: Text(tr(context, 'New session', 'Phiên mới')),
                    ),
                    for (final r in sessions.reversed.take(10))
                      Text(
                        '${r.number('elapsed')} ${tr(context, 'saved seconds', 'giây đã lưu')} · ${r.str('created')}',
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> taskReminder(
  BuildContext context,
  BoardsScope scope,
  String id,
) async {
  final t = scope.state.get('tasks', id),
      name = scope.state.get('boards', t.str('board')).str('zone');
  await boardForm(
    context,
    tr(context, 'Local reminder', 'Nhắc cục bộ'),
    [
      const BoardField('day', 'Reminder date', 'Ngày nhắc', kind: 'date'),
      const BoardField(
        'clock',
        'Time HH:mm in board timezone',
        'Giờ HH:mm theo múi giờ bảng',
      ),
      BoardField(
        'fold',
        'Ambiguous time choice',
        'Lựa chọn giờ bị trùng',
        kind: 'select',
        options: {
          'ask': tr(context, 'Reject ambiguous time', 'Từ chối giờ bị trùng'),
          'early': tr(context, 'Earlier', 'Lần sớm'),
          'late': tr(context, 'Later', 'Lần muộn'),
        },
      ),
    ],
    {'day': localDay(scope.clock(), name), 'clock': '09:00', 'fold': 'ask'},
    (v) async {
      final at = wallTime(
        v['day'],
        v['clock'],
        name,
        lateFold: v['fold'] == 'ask' ? null : v['fold'] == 'late',
      );
      if (!at.isAfter(scope.clock()))
        throw const FormatException('Reminder must be in future');
      await scope.controller.change(
        (s) => s.put(
          'reminders',
          BoardRecord({
            'id': newId(),
            'task': id,
            'board': t.str('board'),
            'at': at.toUtc().toIso8601String(),
            'zone': name,
            'enabled': true,
          }),
        ),
      );
    },
    footer: [
      Text(
        tr(
          context,
          'The reminder remains in the app. System delivery requires supported OS permission; Windows/Web use the in-app reminder center.',
          'Nhắc được giữ trong app. Thông báo hệ thống cần quyền OS được hỗ trợ; Windows/Web dùng trung tâm nhắc trong app.',
        ),
      ),
    ],
  );
}
