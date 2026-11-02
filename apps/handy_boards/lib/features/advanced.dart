import 'package:flutter/gestures.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/labels.dart';
import 'editors.dart';
import 'board_views.dart';
import 'rule_editor.dart';
import 'saved_view_editor.dart';
import 'remaining_views.dart';

bool boardsPro(BuildContext context) =>
    LifetimeScope.maybeOf(context)?.pro == true;
Future<bool> requireBoardsPro(BuildContext context) async {
  if (boardsPro(context)) return true;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Pro Lifetime', 'Pro trọn đời')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(
              context,
              'This advanced tool requires verified Pro ownership. Core tasks and full backups stay free. Store purchase is available only after publisher configuration.',
              'Công cụ nâng cao cần quyền Pro đã xác minh. Task cơ bản và sao lưu đầy đủ vẫn miễn phí. Chỉ mua được sau khi cấu hình nhà phát hành.',
            ),
          ),
          const LifetimeSettings(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Close', 'Đóng')),
        ),
      ],
    ),
  );
  return false;
}

class AdvancedPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const AdvancedPage({super.key, required this.scope, required this.board});
  @override
  State<AdvancedPage> createState() => _AdvancedState();
}

class _AdvancedState extends State<AdvancedPage> {
  String tab = 'timeline';
  double dayWidth = 32;
  bool weeklyWorkload = false;
  BoardsScope get scope => widget.scope;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope.controller,
    builder: (context, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Advanced planning', 'Kế hoạch nâng cao')),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (id, en, vi) in [
                      ('timeline', 'Timeline', 'Dòng thời gian'),
                      ('priority', 'Smart priority', 'Ưu tiên thông minh'),
                      ('workload', 'Workload', 'Khối lượng'),
                      ('fields', 'Custom fields', 'Trường tùy chỉnh'),
                      ('views', 'Saved views', 'View đã lưu'),
                      ('rules', 'Rules', 'Quy tắc'),
                      ('study-report', 'Study report', 'Báo cáo học tập'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tr(context, en, vi)),
                          selected: tab == id,
                          onSelected: (_) => setState(() => tab = id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!boardsPro(context))
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(
                              context,
                              'Advanced planning uses Pro Lifetime. Your existing task dates, dependencies and data are preserved.',
                              'Kế hoạch nâng cao dùng Pro trọn đời. Ngày, phụ thuộc và dữ liệu task hiện có được giữ nguyên.',
                            ),
                          ),
                          TextButton(
                            onPressed: () => requireBoardsPro(context),
                            child: Text(
                              tr(
                                context,
                                'View purchase availability',
                                'Xem khả năng mua',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: switch (tab) {
                    'timeline' => _timeline(context),
                    'priority' => _priority(context),
                    'workload' => _workload(context),
                    'fields' => _fields(context),
                    'views' => _views(context),
                    'study-report' => StudyReports(
                      scope: scope,
                      board: widget.board,
                    ),
                    _ => _rules(context),
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
  Widget _timeline(BuildContext context) {
    final s = scope.state,
        tasks = queryTasks(
          s,
          board: widget.board,
          filter: {'parentOnly': true},
        ),
        dated = tasks
            .where((t) => t.data['start'] != null && t.data['due'] != null)
            .toList(),
        name = s.get('boards', widget.board).str('zone'),
        path = criticalPath(s, widget.board);
    final dates =
        dated
            .expand(
              (t) => [
                calendarDate(deadlineDay(object(t.data['start']), name)),
                calendarDate(deadlineDay(object(t.data['due']), name)),
              ],
            )
            .toList()
          ..sort();
    final start = dates.firstOrNull ?? scope.clock(),
        days = dates.isEmpty ? 1 : dates.last.difference(start).inDays + 1;
    if (days > 366)
      return Text(
        tr(
          context,
          'Timeline window exceeds 366 days. Narrow task dates before rendering.',
          'Cửa sổ vượt 366 ngày. Hãy thu gọn ngày task trước khi xem.',
        ),
      );
    if (dated.length > 300)
      return Text(
        tr(
          context,
          'Timeline supports up to 300 dated tasks. Narrow the board before rendering.',
          'Timeline hỗ trợ tối đa 300 task có ngày. Hãy thu gọn bảng trước khi xem.',
        ),
      );
    return ListView(
      children: [
        Text(
          tr(
            context,
            'Bars use saved start and due dates.',
            'Thanh dùng ngày bắt đầu và hạn đã lưu.',
          ),
        ),
        TextButton.icon(
          onPressed: () => scope.run(
            context,
            () => editWorkingCalendar(context, scope, widget.board),
          ),
          icon: const Icon(Icons.work_history_outlined),
          label: Text(
            tr(
              context,
              'Working days & resource availability',
              'Ngày làm việc và lịch nguồn lực',
            ),
          ),
        ),
        if (s.get('boards', widget.board).data['workingCalendar'] != null &&
            path['valid'] == true)
          Builder(
            builder: (context) {
              final projection = projectWorkingDuration(
                boardWorkingCalendar(s, widget.board),
                start.toIso8601String().substring(0, 10),
                path['minutes'] as int,
              );
              return Text(
                '${tr(context, 'Duration-path projection in board working calendar', 'Dự kiến theo đường găng và lịch bảng')}: ${projection['start']} → ${projection['finish']} (${projection['workingDays']} ${tr(context, 'working days; no resource booking inferred', 'ngày làm việc; không tự xếp chỗ nguồn lực')})',
              );
            },
          ),
        if (s.get('boards', widget.board).data['workingCalendar'] != null ||
            object(
              s.get('boards', widget.board).data['resourceCalendars'] ?? {},
            ).isNotEmpty)
          for (final t in dated.where(
            (t) => !isWorkingDay(
              boardWorkingCalendar(
                s,
                widget.board,
                assignee: t.str('assignee'),
              ),
              deadlineDay(object(t.data['due']), name),
            ),
          ))
            Text(
              '${tr(context, 'Deadline outside configured availability', 'Hạn ngoài lịch làm việc')}: ${t.str('title')}',
            ),
        Row(
          children: [
            Text(tr(context, 'Zoom', 'Thu phóng')),
            Expanded(
              child: Slider(
                value: dayWidth,
                min: 16,
                max: 64,
                onChanged: (v) => setState(() => dayWidth = v),
              ),
            ),
          ],
        ),
        if (path['valid'] == true)
          Text(
            '${tr(context, 'Duration-only critical path', 'Đường găng chỉ theo thời lượng')}: ${path['minutes']} ${tr(context, 'minutes', 'phút')}',
          )
        else
          Text(
            tr(
              context,
              path['warning'] == 'Dependency dates overlap'
                  ? 'Critical path unavailable: dependency dates overlap.'
                  : 'Critical path unavailable: tasks need positive estimates (milestones may be zero).',
              path['warning'] == 'Dependency dates overlap'
                  ? 'Chưa tính được đường găng: ngày phụ thuộc chồng lấn.'
                  : 'Chưa tính được đường găng: task cần ước lượng dương (milestone có thể bằng 0).',
            ),
          ),
        ExpansionTile(
          title: Text(
            tr(context, 'Controls & assumptions', 'Thao tác và giả định'),
          ),
          children: [
            Text(
              tr(
                context,
                'Drag a bar to move both dates; drag its right handle to resize the end. Every change requires confirmation. Edit the task for precise times or DST choices.',
                'Kéo thanh để dời hai ngày; kéo tay nắm bên phải để đổi hạn. Mọi thay đổi cần xác nhận. Sửa task để chọn giờ/DST chính xác.',
              ),
            ),
            Text(
              tr(
                context,
                'Availability warnings use your calendar. Saved dates are never moved automatically. Missing dates are listed separately.',
                'Cảnh báo theo lịch bạn cấu hình; không tự đổi ngày đã lưu. Ngày thiếu được liệt kê riêng.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 160 + days * dayWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 160),
                    for (var i = 0; i < days; i++)
                      SizedBox(
                        width: dayWidth,
                        child: Text(
                          '${start.add(Duration(days: i)).day}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
                for (final t in dated)
                  SizedBox(
                    height:
                        48 *
                        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                          1,
                          3,
                        ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            t.str('title'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final a = calendarDate(
                                    deadlineDay(object(t.data['start']), name),
                                  ).difference(start).inDays,
                                  b = calendarDate(
                                    deadlineDay(object(t.data['due']), name),
                                  ).difference(start).inDays;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: a * dayWidth,
                                    top: 12,
                                    width: (b - a + 1) * dayWidth,
                                    height:
                                        24 *
                                        (MediaQuery.textScalerOf(
                                                  context,
                                                ).scale(14) /
                                                14)
                                            .clamp(1, 3),
                                    child: Tooltip(
                                      message: t.str('title'),
                                      child: _dateDrag(
                                        context,
                                        t,
                                        resize: false,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: categoryHue(
                                              s.maybe(
                                                'categories',
                                                t.data['category'],
                                              ),
                                            ).withValues(alpha: .25),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: (b - a + 1) * dayWidth < 56
                                              ? Center(
                                                  child:
                                                      t.str('kind') ==
                                                          'milestone'
                                                      ? const Icon(
                                                          Icons
                                                              .diamond_outlined,
                                                          size: 12,
                                                        )
                                                      : const SizedBox(),
                                                )
                                              : Row(
                                                  children: [
                                                    if (t.str('kind') ==
                                                        'milestone')
                                                      const Icon(
                                                        Icons.diamond_outlined,
                                                        size: 18,
                                                      ),
                                                    Expanded(
                                                      child: Text(
                                                        t.str('title'),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    _dateDrag(
                                                      context,
                                                      t,
                                                      resize: true,
                                                      child: Tooltip(
                                                        message: tr(
                                                          context,
                                                          'Resize deadline',
                                                          'Đổi độ dài hạn',
                                                        ),
                                                        child: const SizedBox(
                                                          width: 24,
                                                          child: Icon(
                                                            Icons.drag_handle,
                                                            size: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final t in tasks.where(
          (t) => t.data['start'] == null || t.data['due'] == null,
        ))
          Text(
            '${tr(context, 'Missing dates', 'Thiếu ngày')}: ${t.str('title')}',
          ),
        for (final d
            in s
                .rows('dependencies')
                .where(
                  (d) =>
                      s.get('tasks', d.str('before')).str('board') ==
                      widget.board,
                ))
          Text(
            '${s.get('tasks', d.str('before')).str('title')} → ${s.get('tasks', d.str('after')).str('title')}',
          ),
      ],
    );
  }

  Widget _dateDrag(
    BuildContext context,
    BoardRecord task, {
    required bool resize,
    required Widget child,
  }) {
    var delta = 0.0;
    return GestureDetector(
      dragStartBehavior: DragStartBehavior.down,
      behavior: HitTestBehavior.opaque,
      onTap: () => scope.run(context, () => editTask(context, scope, task.id)),
      onHorizontalDragStart: (_) => delta = 0,
      onHorizontalDragUpdate: (d) => delta += d.delta.dx,
      onHorizontalDragEnd: (_) {
        final shift = (delta / dayWidth).round();
        if (shift == 0) return;
        scope.run(context, () async {
          final before = scope.state, revision = before.revision;
          final preview = shiftTaskDates(
            before,
            task.id,
            shift,
            resizeEnd: resize,
            now: scope.clock(),
          ).get('tasks', task.id);
          if (!await confirmBoards(
            context,
            tr(context, 'Apply date change?', 'Áp dụng đổi ngày?'),
            '${task.str('title')}\n${deadlineSort(object(preview.data['start']))} → ${deadlineSort(object(preview.data['due']))}',
          ))
            return;
          await scope.controller.change((s) {
            if (s.revision != revision)
              throw const FormatException('Data changed during preview');
            return shiftTaskDates(
              s,
              task.id,
              shift,
              resizeEnd: resize,
              now: scope.clock(),
            );
          });
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr(context, 'Dates changed', 'Đã đổi ngày')),
              action: SnackBarAction(
                label: tr(context, 'Undo', 'Hoàn tác'),
                onPressed: () =>
                    scope.run(context, () => scope.controller.undo()),
              ),
            ),
          );
        });
      },
      child: child,
    );
  }

  Widget _priority(BuildContext context) {
    final s = scope.state,
        b = s.get('boards', widget.board),
        weights = object(b.data['priorityWeights'] ?? {}),
        tasks = queryTasks(
          s,
          board: widget.board,
        ).where((t) => !completed(s, t)).toList();
    final scores = {
      for (final t in tasks)
        t.id: smartPriority(s, t, scope.clock(), weights: weights),
    };
    tasks.sort(
      (a, b) => (scores[b.id]!['score'] as num).compareTo(
        scores[a.id]!['score'] as num,
      ),
    );
    return ListView(
      children: [
        Text(
          tr(
            context,
            'Deterministic scoring, not AI. You can override the result by pinning or changing priority.',
            'Chấm điểm theo quy tắc, không phải AI. Bạn có thể ghim hoặc đổi ưu tiên để điều chỉnh.',
          ),
        ),
        SwitchListTile(
          title: Text(
            tr(context, 'Enable smart suggestions', 'Bật gợi ý ưu tiên'),
          ),
          value: b.data['priorityEnabled'] != false,
          onChanged: (v) => scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put(
                'boards',
                s.get('boards', widget.board).copy({'priorityEnabled': v}),
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () => scope.run(
            context,
            () => boardForm(
              context,
              tr(context, 'Score weights', 'Trọng số điểm'),
              [
                for (final key in [
                  'priority',
                  'pin',
                  'blocked',
                  'overdue',
                  'soon',
                  'short',
                  'planned',
                  'category',
                ])
                  BoardField(
                    key,
                    key,
                    {
                      'priority': 'Ưu tiên',
                      'pin': 'Ghim',
                      'blocked': 'Bị chặn',
                      'overdue': 'Quá hạn',
                      'soon': 'Sắp hạn',
                      'short': 'Việc ngắn',
                      'planned': 'Dự kiến hôm nay',
                      'category': 'Trọng số nhóm',
                    }[key]!,
                    kind: 'number',
                  ),
              ],
              {
                'priority': '${weights['priority'] ?? 10}',
                'pin': '${weights['pin'] ?? 50}',
                'blocked': '${weights['blocked'] ?? 100}',
                'overdue': '${weights['overdue'] ?? 40}',
                'soon': '${weights['soon'] ?? 20}',
                'short': '${weights['short'] ?? 5}',
                'planned': '${weights['planned'] ?? 15}',
                'category': '${weights['category'] ?? 1}',
              },
              (v) async {
                final w = {for (final key in v.keys) key: double.parse(v[key])};
                if (tasks.isNotEmpty)
                  smartPriority(s, tasks.first, scope.clock(), weights: w);
                await scope.controller.change(
                  (s) => s.put('boards', b.copy({'priorityWeights': w})),
                );
              },
            ),
          ),
          child: Text(tr(context, 'Configure scoring', 'Cấu hình điểm')),
        ),
        if (b.data['priorityEnabled'] != false)
          for (final t in tasks.take(200))
            ListTile(
              title: Text(t.str('title')),
              subtitle: Text(
                (scores[t.id]!['reasons'] as List)
                    .cast<String>()
                    .map((r) => priorityReason(context, r))
                    .join(' · '),
              ),
              trailing: Text('${scores[t.id]!['score']}'),
            ),
      ],
    );
  }

  Widget _workload(BuildContext context) {
    final s = scope.state,
        b = s.get('boards', widget.board),
        capacity = b.data['capacity'] as int?,
        report = workloadReport(s, widget.board, dailyCapacity: capacity),
        rows = workloadBuckets(report, weekly: weeklyWorkload);
    final keys = rows.keys.toList()..sort();
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (value, en, vi) in [
              (false, 'Day', 'Ngày'),
              (true, 'Week starting Monday', 'Tuần từ thứ Hai'),
            ])
              ChoiceChip(
                label: Text(tr(context, en, vi)),
                selected: weeklyWorkload == value,
                onSelected: (_) => setState(() => weeklyWorkload = value),
              ),
          ],
        ),
        Text(
          tr(
            context,
            'Estimated minutes are assigned to the due day. Unknown estimates stay separate. Actual logs use saved focus sessions.',
            'Phút ước lượng gán vào ngày hạn. Ước lượng chưa rõ được tách riêng. Thời gian thực dùng phiên tập trung đã lưu.',
          ),
        ),
        TextButton(
          onPressed: () => scope.run(
            context,
            () => boardForm(
              context,
              tr(context, 'Daily capacity', 'Năng lực mỗi ngày'),
              [
                const BoardField(
                  'minutes',
                  'Minutes per day (empty = unknown)',
                  'Phút/ngày (trống = chưa rõ)',
                  optional: true,
                  kind: 'number',
                ),
              ],
              {'minutes': capacity?.toString() ?? ''},
              (v) async {
                final n = v['minutes'] == '' ? null : int.parse(v['minutes']);
                if (n != null && n <= 0)
                  throw const FormatException('Capacity positive');
                await scope.controller.change(
                  (s) => s.put('boards', b.copy({'capacity': n})),
                );
              },
            ),
          ),
          child: Text(
            capacity == null
                ? tr(context, 'Set your own capacity', 'Đặt năng lực của bạn')
                : '$capacity ${tr(context, 'min/day', 'phút/ngày')}',
          ),
        ),
        Text(
          '${report['unallocatedActualSeconds']} ${tr(context, 'saved seconds have no verifiable day allocation; active sessions are excluded', 'giây đã lưu chưa xác định được ngày; không tính phiên đang chạy')}',
        ),
        LayoutBuilder(
          builder: (context, box) {
            final columns =
                    (box.maxWidth /
                            (MediaQuery.textScalerOf(context).scale(14) > 20
                                ? 150
                                : 110))
                        .floor()
                        .clamp(1, 7),
                width = (box.maxWidth - (columns - 1) * 8) / columns;
            final maximum = keys.fold<int>(
              1,
              (m, key) =>
                  rows[key]!['minutes'] > m ? rows[key]!['minutes'] as int : m,
            );
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in keys)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      label:
                          '$key: ${rows[key]!['minutes']} ${tr(context, 'estimated minutes', 'phút dự kiến')}',
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          color: Theme.of(context).colorScheme.primary
                              .withValues(
                                alpha:
                                    .04 +
                                    .12 *
                                        (rows[key]!['minutes'] as int) /
                                        maximum,
                              ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(key),
                            Text(
                              '${rows[key]!['minutes']} ${tr(context, 'est. min', 'phút dự kiến')}',
                            ),
                            Text(
                              '${((rows[key]!['actualSeconds'] as int? ?? 0) / 60).toStringAsFixed(1)} ${tr(context, 'actual min', 'phút thực tế')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Text(
          tr(
            context,
            'Tint is relative to the largest estimate shown, not an invented capacity. Only your configured capacity determines overload.',
            'Màu đậm theo ước lượng lớn nhất đang hiển thị, không phải năng lực giả định. Chỉ dùng năng lực bạn đã đặt để xác định quá tải.',
          ),
        ),
        for (final key in keys)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(key),
            subtitle: Text(
              '${rows[key]!['minutes']} ${tr(context, 'estimated min', 'phút dự kiến')} · ${rows[key]!['unknown']} ${tr(context, 'unknown estimates', 'chưa rõ ước lượng')} · ${rows[key]!['actualSeconds'] ?? 0} ${tr(context, 'actual seconds', 'giây thực tế')}',
            ),
            trailing: rows[key]!['overloaded'] == true
                ? Text(
                    tr(
                      context,
                      weeklyWorkload
                          ? 'Contains overloaded days'
                          : 'Over capacity',
                      weeklyWorkload
                          ? 'Có ngày vượt năng lực'
                          : 'Vượt năng lực',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  )
                : null,
          ),
        const Divider(),
        for (final session
            in s
                .rows('sessions')
                .where(
                  (r) =>
                      s.get('tasks', r.str('task')).str('board') ==
                      widget.board,
                ))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.get('tasks', session.str('task')).str('title')),
            trailing: Text(
              '${session.number('elapsed')} ${tr(context, 'saved sec', 'giây đã lưu')}',
            ),
          ),
      ],
    );
  }

  Widget _fields(BuildContext context) => ListView(
    children: [
      TextButton.icon(
        onPressed: () => scope.run(context, () => _field(context)),
        icon: const Icon(Icons.add),
        label: Text(
          tr(context, 'Add field definition', 'Thêm định nghĩa trường'),
        ),
      ),
      for (final f
          in scope.state
              .rows('fields')
              .where((f) => f.str('board') == widget.board))
        ListTile(
          title: Text(f.str('title')),
          subtitle: Text(f.str('type')),
          onTap: () => scope.run(context, () => _field(context, old: f)),
        ),
    ],
  );
  Future<void> _field(BuildContext context, {BoardRecord? old}) => boardForm(
    context,
    tr(context, 'Custom field', 'Trường tùy chỉnh'),
    [
      const BoardField('title', 'Name', 'Tên'),
      BoardField(
        'type',
        'Type',
        'Kiểu',
        kind: 'select',
        options: {
          'text': tr(context, 'Text', 'Văn bản'),
          'number': tr(context, 'Decimal', 'Thập phân'),
          'date': tr(context, 'Date', 'Ngày'),
          'checkbox': tr(context, 'Checkbox', 'Đánh dấu'),
          'single': tr(context, 'Single select', 'Chọn một'),
          'multi': tr(context, 'Multi select', 'Chọn nhiều'),
          'url': 'URL',
        },
      ),
      const BoardField(
        'options',
        'Choices separated by commas',
        'Các lựa chọn ngăn dấu phẩy',
        optional: true,
      ),
      const BoardField(
        'default',
        'Default (multiple choices: comma separated; checkbox: true/false; empty = none)',
        'Mặc định (nhiều lựa chọn: ngăn dấu phẩy; đánh dấu: true/false; trống = không có)',
        optional: true,
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'type': old?.str('type') ?? 'text',
      'options': old?.strings('options').join(',') ?? '',
      'default': old?.data['default'] == null
          ? ''
          : old?.str('type') == 'multi'
          ? (old!.data['default'] as List).join(', ')
          : old!.data['default'].toString(),
    },
    (v) async {
      await scope.controller.change(
        (s) => s.put(
          'fields',
          BoardRecord({
            ...?old?.data,
            'id': old?.id ?? newId(),
            'board': widget.board,
            'title': v['title'],
            'type': v['type'],
            'default': v['default'] == ''
                ? null
                : v['type'] == 'multi'
                ? (v['default'] as String)
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .toList()
                : v['type'] == 'checkbox'
                ? switch (v['default']) {
                    'true' => true,
                    'false' => false,
                    _ => throw const FormatException(
                      'Checkbox default: true or false',
                    ),
                  }
                : v['default'],
            'options': (v['options'] as String)
                .split(',')
                .map((v) => v.trim())
                .where((v) => v.isNotEmpty)
                .toList(),
          }),
        ),
      );
    },
    footer: [
      Text(
        tr(
          context,
          'Changes are rejected if existing task values would become invalid.',
          'Từ chối thay đổi nếu làm giá trị task hiện có không hợp lệ.',
        ),
      ),
    ],
  );
  Widget _views(BuildContext context) => ListView(
    children: [
      TextButton.icon(
        onPressed: () => scope.run(context, () => _view(context)),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'Save a smart view', 'Lưu view thông minh')),
      ),
      for (final v
          in scope.state
              .rows('views')
              .where((v) => v.str('board') == widget.board))
        ExpansionTile(
          title: Text(v.str('title')),
          subtitle: Text(
            '${smartViewTasks(scope.state, v).length} ${tr(context, 'tasks', 'task')}',
          ),
          children: [
            TextButton(
              onPressed: () => scope.run(context, () => _view(context, old: v)),
              child: Text(tr(context, 'Edit saved view', 'Sửa view đã lưu')),
            ),
            ..._viewRows(context, v),
            TextButton(
              onPressed: () => scope.run(
                context,
                () => scope.controller.change((s) => s.remove('views', {v.id})),
              ),
              child: Text(tr(context, 'Delete view', 'Xóa view')),
            ),
          ],
        ),
    ],
  );
  List<Widget> _viewRows(BuildContext context, BoardRecord view) {
    final tasks = smartViewTasks(scope.state, view).take(100),
        groups = <String, List<BoardRecord>>{};
    if (view.str('group', 'flat') == 'flat')
      return [for (final t in tasks) TaskRow(scope: scope, task: t)];
    for (final t in tasks) {
      final key = switch (view.str('group')) {
        'category' =>
          scope.state.maybe('categories', t.data['category'])?.str('title') ??
              tr(context, 'Uncategorized', 'Chưa phân nhóm'),
        'status' => scope.state.get('statuses', t.str('status')).str('title'),
        _ =>
          t.data['due'] == null
              ? tr(context, 'No deadline', 'Chưa có hạn')
              : deadlineDay(
                  object(t.data['due']),
                  scope.state.get('boards', widget.board).str('zone'),
                ),
      };
      (groups[key] ??= []).add(t);
    }
    return [
      for (final e in groups.entries) ...[
        Text(e.key, style: Theme.of(context).textTheme.titleMedium),
        for (final t in e.value) TaskRow(scope: scope, task: t),
      ],
    ];
  }

  Future<void> _view(BuildContext context, {BoardRecord? old}) =>
      editSavedView(context, scope, widget.board, old: old);
  Widget _rules(BuildContext context) => ListView(
    children: [
      Text(
        tr(
          context,
          'Local rules run transactionally on matching edits while Pro is active. Actions never recursively trigger more rules. No background server.',
          'Quy tắc cục bộ chạy trong giao dịch khi sửa phù hợp và Pro đang hoạt động. Hành động không tự kích hoạt chuỗi quy tắc. Không server nền.',
        ),
      ),
      TextButton.icon(
        onPressed: () => scope.run(context, () => _rule(context)),
        icon: const Icon(Icons.add),
        label: Text(tr(context, 'New rule', 'Quy tắc mới')),
      ),
      TextButton.icon(
        onPressed: () => scope.run(
          context,
          () => scope.controller.change(
            (s) => reconcileOpenRules(s, scope.clock()),
          ),
        ),
        icon: const Icon(Icons.play_arrow_outlined),
        label: Text(
          tr(
            context,
            'Process next app-open batch (up to 100 tasks)',
            'Xử lý lượt mở app tiếp theo (tối đa 100 task)',
          ),
        ),
      ),
      for (final r
          in scope.state
              .rows('rules')
              .where((r) => r.str('board') == widget.board))
        SwitchListTile(
          title: Text(r.str('title')),
          subtitle: Text(
            '${ruleTriggers(context)[r.str('trigger')]}\n${(r.data['actions'] as List).map((a) => ruleActionLabel(context, scope.state, object(a))).join('; ')}',
          ),
          secondary: PopupMenuButton<String>(
            onSelected: (action) => scope.run(context, () async {
              if (action == 'edit') {
                await editAutomationRule(context, scope, widget.board, old: r);
                return;
              }
              if (!await confirmBoards(
                context,
                tr(context, 'Delete rule?', 'Xóa quy tắc?'),
                r.str('title'),
              ))
                return;
              await scope.controller.change((s) {
                final e = BoardsEdit(s);
                e.remove('rules', r.id);
                for (final x
                    in s.rows('executions').where((x) => x.str('rule') == r.id))
                  e.remove('executions', x.id);
                return e.finish();
              });
            }),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(tr(context, 'Edit & preview', 'Sửa và xem trước')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(tr(context, 'Delete', 'Xóa')),
              ),
            ],
          ),
          value: r.flag('enabled'),
          onChanged: (v) => scope.run(
            context,
            () => scope.controller.change(
              (s) => s.put('rules', r.copy({'enabled': v})),
            ),
          ),
        ),
      const Divider(),
      for (final r
          in scope.state
              .rows('executions')
              .where(
                (r) =>
                    scope.state.maybe('tasks', r.str('task'))?.str('board') ==
                    widget.board,
              )
              .take(100))
        ListTile(
          title: Text(scope.state.get('tasks', r.str('task')).str('title')),
          subtitle: Text(
            '${r.str('at')}${r.flag('delayed') ? ' · ${tr(context, 'App-open processing', 'Xử lý khi mở app')}' : ''}',
          ),
        ),
    ],
  );
  Future<void> _rule(BuildContext context) =>
      editAutomationRule(context, scope, widget.board);
}
