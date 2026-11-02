import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import 'board_views.dart';
import 'task_detail.dart';
import '../ui/form.dart';

class TodayPage extends StatefulWidget {
  final BoardsScope scope;
  final String? board;
  const TodayPage({super.key, required this.scope, this.board});
  @override
  State<TodayPage> createState() => _TodayState();
}

class _TodayState extends State<TodayPage> {
  int horizon = 7;
  @override
  Widget build(BuildContext context) {
    final s = widget.scope.state,
        now = widget.scope.clock(),
        name = widget.board == null
            ? 'Asia/Ho_Chi_Minh'
            : s.get('boards', widget.board!).str('zone'),
        today = localDay(now, name),
        end = DateTime.parse(
          today,
        ).add(Duration(days: horizon)).toIso8601String().substring(0, 10);
    final tasks = queryTasks(
          s,
          board: widget.board,
          sort: 'due',
          filter: {'parentOnly': true},
        ).where((t) => !completed(s, t)).toList(),
        groups = <String, List<BoardRecord>>{
          'overdue': [],
          'today': [],
          'upcoming': [],
          'pinned': [],
          'blocked': [],
          'planned': [],
        };
    for (final t in tasks) {
      if (t.flag('pinned')) groups['pinned']!.add(t);
      if (blocked(s, t)) groups['blocked']!.add(t);
      if (t.data['start'] != null &&
          deadlineDay(object(t.data['start']), name) == today)
        groups['planned']!.add(t);
      if (t.data['due'] == null) continue;
      final date = deadlineDay(object(t.data['due']), name);
      if (date.compareTo(today) < 0 ||
          object(t.data['due'])['kind'] == 'time' &&
              DateTime.parse(object(t.data['due'])['at']).isBefore(now)) {
        groups['overdue']!.add(t);
      } else if (date == today) {
        groups['today']!.add(t);
      } else if (date.compareTo(end) <= 0) {
        groups['upcoming']!.add(t);
      }
    }
    final radar = deadlineRadar(s, now, board: widget.board);
    const kinds = [
      ('overdue', 'Overdue', 'Quá hạn'),
      ('today', 'Today', 'Hôm nay'),
      ('planned', 'Planned today', 'Dự kiến hôm nay'),
      ('upcoming', 'Coming up', 'Sắp tới'),
      ('pinned', 'Pinned', 'Đã ghim'),
      ('blocked', 'Blocked', 'Bị chặn'),
    ];
    final theme = Theme.of(context);
    final muted = HandyColors.of(context).muted;
    final overdue = groups['overdue']!.length,
        dueToday = groups['today']!.length;
    final upcoming = groups['upcoming']!.length;
    // The screen's one finding, said before any list.
    final finding = overdue > 0
        ? tr(
            context,
            '$overdue overdue, $dueToday due today.',
            '$overdue việc quá hạn, $dueToday việc đến hạn hôm nay.',
          )
        : dueToday > 0
        ? tr(context, '$dueToday due today.', '$dueToday việc đến hạn hôm nay.')
        : upcoming > 0
        ? tr(
            context,
            'Nothing due today; $upcoming in the next $horizon days.',
            'Hôm nay trống; $upcoming việc trong $horizon ngày tới.',
          )
        : tr(
            context,
            'Nothing due in the next $horizon days.',
            'Không có việc nào đến hạn trong $horizon ngày tới.',
          );
    final empty = [
      for (final (key, en, vi) in kinds)
        if (groups[key]!.isEmpty) tr(context, en, vi).toLowerCase(),
    ];
    return ListView(
      children: [
        // Editorial: the day is the headline, at regular weight; the shell
        // already names the board.
        Semantics(
          header: true,
          child: Text(
            tr(context, 'Today', 'Hôm nay'),
            key: const Key('today-title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: MediaQuery.sizeOf(context).width < 400 ? 32 : 40,
              fontWeight: FontWeight.w400,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        Text(
          finding,
          key: const Key('today-finding'),
          style: theme.textTheme.titleMedium,
        ),
        Text(
          '$today · $name',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: HandySpace.l),
        Wrap(
          spacing: 8,
          children: [
            for (final n in [1, 3, 7, 30])
              ChoiceChip(
                label: Text('$n ${tr(context, 'days', 'ngày')}'),
                selected: horizon == n,
                onSelected: (_) => setState(() => horizon = n),
              ),
          ],
        ),
        for (final (key, en, vi) in kinds)
          if (groups[key]!.isNotEmpty)
            HandySection(
              title: '${tr(context, en, vi)} · ${groups[key]!.length}',
              children: [
                for (final t in groups[key]!.take(200))
                  TaskRow(scope: widget.scope, task: t),
                if (groups[key]!.length > 200)
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.l),
                    child: Text(
                      tr(
                        context,
                        'First 200 tasks shown. Narrow the board filter.',
                        'Hiện 200 task đầu. Hãy lọc theo bảng.',
                      ),
                    ),
                  ),
              ],
            ),
        // Empty kinds are one line, not a heading each over "nothing".
        if (empty.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.xl),
            child: Text(
              '${tr(context, 'Nothing', 'Không có việc')}: ${empty.join(', ')}.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
        HandyLabel(
          tr(context, 'Deadlines and reminders', 'Hạn chót và nhắc việc'),
        ),
        HandyGroup(
          children: [
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: HandySpace.l,
              ),
              title: Text(
                tr(context, 'Exact Deadline Radar', 'Radar hạn chót theo giờ'),
              ),
              children: [
                Text(
                  tr(
                    context,
                    'All-day work is due at the end of that day in its board timezone. Risk means blocked with a deadline within seven days; it is not a prediction.',
                    'Việc cả ngày đến hạn cuối ngày theo múi giờ bảng. Rủi ro nghĩa là đang bị chặn và hạn trong bảy ngày, không phải dự đoán.',
                  ),
                ),
                for (final (key, en, vi) in [
                  ('overdue', 'Overdue', 'Quá hạn'),
                  ('24h', 'Within 24 hours', 'Trong 24 giờ'),
                  ('3d', '24 hours to 3 days', '24 giờ đến 3 ngày'),
                  ('7d', '3 to 7 days', '3 đến 7 ngày'),
                  (
                    'atRisk',
                    'Blocked, due within 7 days',
                    'Bị chặn, hạn trong 7 ngày',
                  ),
                ])
                  Builder(
                    builder: (context) {
                      final ids = ((object(radar['groups']))[key] as List)
                          .cast<String>();
                      return ExpansionTile(
                        title: Text('${tr(context, en, vi)} · ${ids.length}'),
                        children: [
                          for (final id in ids.take(100))
                            TaskRow(
                              scope: widget.scope,
                              task: s.get('tasks', id),
                            ),
                          if (ids.length > 100)
                            Text(
                              tr(
                                context,
                                'First 100 shown; use board filters for a narrower view.',
                                'Hiện 100 task đầu; lọc bảng để xem phạm vi nhỏ hơn.',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: HandySpace.l,
              ),
              title: Text(
                tr(
                  context,
                  'Recurring rules / recovery',
                  'Quy tắc lặp / khôi phục',
                ),
              ),
              children: [
                Text(
                  tr(
                    context,
                    'The app reconciles up to 20 rules on launch/resume, seven days ahead. No work runs while the OS closes the app. Large backlogs or DST errors require review.',
                    'App đối chiếu tối đa 20 quy tắc khi mở/trở lại, trước bảy ngày. Không chạy khi OS đóng app. Tồn đọng lớn hoặc lỗi DST cần kiểm tra.',
                  ),
                ),
                for (final rule
                    in s
                        .rows('recurrence')
                        .where(
                          (r) =>
                              widget.board == null ||
                              r.str('board') == widget.board,
                        ))
                  ListTile(
                    title: Text(s.get('tasks', rule.str('task')).str('title')),
                    subtitle: Text(
                      rule.flag('reviewRequired')
                          ? '${tr(context, 'Review required', 'Cần kiểm tra')}: ${rule.str('lastError')}'
                          : '${tr(context, 'Generated through', 'Đã tạo đến')}: ${rule.str('generatedThrough', '—')}',
                    ),
                    onTap: () =>
                        showTask(context, widget.scope, rule.str('task')),
                  ),
                TextButton(
                  onPressed: () => widget.scope.run(
                    context,
                    () => widget.scope.controller.change(
                      (s) => reconcileRecurrences(s, now),
                      history: false,
                    ),
                  ),
                  child: Text(
                    tr(
                      context,
                      'Process next library batch',
                      'Xử lý lô tiếp theo trong thư viện',
                    ),
                  ),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
              childrenPadding: const EdgeInsets.symmetric(
                horizontal: HandySpace.l,
              ),
              title: Text(
                tr(
                  context,
                  'In-app Reminder Center',
                  'Trung tâm nhắc trong app',
                ),
              ),
              children: [
                for (final r
                    in s
                        .rows('reminders')
                        .where((r) => activeTask(s.get('tasks', r.str('task'))))
                        .take(100))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.get('tasks', r.str('task')).str('title')),
                    subtitle: Text('${r.str('at')} / ${r.str('zone')}'),
                    onTap: () => showTask(context, widget.scope, r.str('task')),
                  ),
                if (s.rows('reminders').isEmpty)
                  Text(
                    tr(context, 'No saved reminders', 'Chưa có nhắc đã lưu'),
                  ),
                Text(
                  tr(
                    context,
                    'System delivery is best effort. Edited, completed or removed tasks are reconciled while the app opens/saves.',
                    'Thông báo hệ thống theo khả năng OS. Nhắc được đối chiếu khi mở/lưu app sau khi sửa, hoàn tất hoặc xóa task.',
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: HandySpace.xxl),
      ],
    );
  }
}

class BoardsCalendar extends StatefulWidget {
  final BoardsScope scope;
  final String? board;
  const BoardsCalendar({super.key, required this.scope, this.board});
  @override
  State<BoardsCalendar> createState() => _CalendarState();
}

class _CalendarState extends State<BoardsCalendar> {
  String mode = 'month';
  bool showClasses = true;
  late DateTime month = DateTime(
    widget.scope.clock().year,
    widget.scope.clock().month,
  );
  late String selected = widget.scope.clock().toIso8601String().substring(
    0,
    10,
  );
  @override
  Widget build(BuildContext context) {
    final s = widget.scope.state,
        name = widget.board == null
            ? 'Asia/Ho_Chi_Minh'
            : s.get('boards', widget.board!).str('zone'),
        byDay = <String, List<BoardRecord>>{};
    for (final t in topTasks(s, board: widget.board))
      if (t.data['due'] != null)
        (byDay[deadlineDay(object(t.data['due']), name)] ??= []).add(t);
    final days = DateTime(month.year, month.month + 1, 0).day,
        offset = month.weekday - 1;
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (id, en, vi) in [
              ('month', 'Month', 'Tháng'),
              ('week', 'Week', 'Tuần'),
              ('day', 'Day', 'Ngày'),
            ])
              ChoiceChip(
                label: Text(tr(context, en, vi)),
                selected: mode == id,
                onSelected: (_) => setState(() => mode = id),
              ),
          ],
        ),
        if (s
            .rows('subjects')
            .any((r) => widget.board == null || r.str('board') == widget.board))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr(
                context,
                'Show optional class schedule',
                'Hiện lịch học tùy chọn',
              ),
            ),
            value: showClasses,
            onChanged: (v) => setState(() => showClasses = v),
          ),
        if (mode == 'month')
          Row(
            children: [
              IconButton(
                tooltip: tr(context, 'Previous month', 'Tháng trước'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: tr(context, 'Next month', 'Tháng sau'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (mode == 'month')
          Row(
            children: [
              for (final label
                  in Localizations.localeOf(context).languageCode == 'vi'
                      ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                      : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
                Expanded(child: Text(label, textAlign: TextAlign.center)),
            ],
          ),
        if (mode == 'month')
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent:
                  56 * MediaQuery.textScalerOf(context).scale(14) / 14,
            ),
            itemCount: ((days + offset + 6) ~/ 7) * 7,
            itemBuilder: (context, i) {
              final n = i - offset + 1;
              if (n < 1 || n > days) return const SizedBox();
              final date = DateTime(
                    month.year,
                    month.month,
                    n,
                  ).toIso8601String().substring(0, 10),
                  count = byDay[date]?.length ?? 0;
              return Semantics(
                label: '$date, $count ${tr(context, 'tasks', 'task')}',
                selected: date == selected,
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (d) =>
                      s.maybe('tasks', d.data)?.data['due'] != null,
                  onAcceptWithDetails: (d) =>
                      _reschedule(context, d.data, date),
                  builder: (context, candidates, rejected) => TextButton(
                    onPressed: () => setState(() => selected = date),
                    style: TextButton.styleFrom(
                      backgroundColor: candidates.isNotEmpty
                          ? Theme.of(context).colorScheme.tertiaryContainer
                          : date == selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      padding: EdgeInsets.zero,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$n'),
                        if (count > 0)
                          Text(
                            '$count',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        if (mode != 'month') ...[
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  selected = calendarDate(selected)
                      .subtract(Duration(days: mode == 'week' ? 7 : 1))
                      .toIso8601String()
                      .substring(0, 10);
                  month = DateTime.parse(selected);
                }),
                icon: const Icon(Icons.chevron_left),
                label: Text(tr(context, 'Earlier', 'Trước')),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  selected = calendarDate(selected)
                      .add(Duration(days: mode == 'week' ? 7 : 1))
                      .toIso8601String()
                      .substring(0, 10);
                  month = DateTime.parse(selected);
                }),
                icon: const Icon(Icons.chevron_right),
                label: Text(tr(context, 'Later', 'Sau')),
              ),
            ],
          ),
          for (var i = 0; i < (mode == 'week' ? 7 : 1); i++)
            Builder(
              builder: (context) {
                final date = calendarDate(selected)
                        .subtract(
                          Duration(
                            days: mode == 'week'
                                ? calendarDate(selected).weekday - 1
                                : 0,
                          ),
                        )
                        .add(Duration(days: i))
                        .toIso8601String()
                        .substring(0, 10),
                    rows = byDay[date] ?? <BoardRecord>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(date, style: Theme.of(context).textTheme.titleMedium),
                    if (rows.isEmpty)
                      Text(tr(context, 'No tasks due', 'Chưa có task đến hạn')),
                    ..._classRows(context, date),
                    for (final t in rows) _draggable(context, t),
                    const Divider(),
                  ],
                );
              },
            ),
        ],
        if (mode == 'month') const Divider(height: 32),
        if (mode == 'month') ...[
          Text(selected, style: Theme.of(context).textTheme.titleMedium),
          if (byDay[selected]?.isNotEmpty != true)
            Text(
              tr(
                context,
                'No tasks due on this date',
                'Chưa có task đến hạn ngày này',
              ),
            ),
          ..._classRows(context, selected),
          for (final t in byDay[selected] ?? <BoardRecord>[])
            _draggable(context, t),
        ],
        const SizedBox(height: 16),
        Text(
          tr(
            context,
            'All-day dates keep their calendar day. Timed deadlines are displayed in the board timezone. Open a task to reschedule; Undo is available.',
            'Ngày cả ngày giữ nguyên ngày lịch. Hạn có giờ hiển thị theo múi giờ bảng. Mở task để đổi hạn; có thể Hoàn tác.',
          ),
        ),
      ],
    );
  }

  List<Widget> _classRows(BuildContext context, String date) {
    if (!showClasses) return [];
    final s = widget.scope.state, weekday = calendarDate(date).weekday;
    final classes =
        s
            .rows('classes')
            .where(
              (r) =>
                  r.number('weekday') == weekday &&
                  (widget.board == null || r.str('board') == widget.board),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.number('startMinute').compareTo(b.number('startMinute')),
          );
    String clock(int n) =>
        '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
    return [
      for (final c in classes)
        ListTile(
          leading: Icon(
            Icons.school_outlined,
            color: categoryHue(s.get('categories', c.str('category'))),
          ),
          title: Text(c.str('title')),
          subtitle: Text(
            '${s.get('categories', c.str('category')).str('title')} · ${clock(c.number('startMinute'))}–${clock(c.number('endMinute'))} · ${c.str('zone')}',
          ),
        ),
    ];
  }

  Widget _draggable(BuildContext context, BoardRecord t) =>
      LongPressDraggable<String>(
        data: t.id,
        feedback: Material(
          elevation: 2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(t.str('title')),
            ),
          ),
        ),
        child: TaskRow(scope: widget.scope, task: t),
      );
  Future<void> _reschedule(BuildContext context, String id, String day) =>
      widget.scope.run(context, () async {
        final task = widget.scope.state.get('tasks', id);
        if (!await confirmBoards(
          context,
          tr(context, 'Reschedule task?', 'Đổi hạn task?'),
          '${task.str('title')} \n$day',
        ))
          return;
        await widget.scope.controller.change(
          (s) => rescheduleTask(s, id, day, now: widget.scope.clock()),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'Deadline changed', 'Đã đổi hạn')),
            action: SnackBarAction(
              label: tr(context, 'Undo', 'Hoàn tác'),
              onPressed: () => widget.scope.run(
                context,
                () => widget.scope.controller.undo(),
              ),
            ),
          ),
        );
      });
}

class InsightsPage extends StatelessWidget {
  final BoardsScope scope;
  final String? board;
  const InsightsPage({super.key, required this.scope, this.board});
  @override
  Widget build(BuildContext context) {
    final s = scope.state,
        tasks = topTasks(s, board: board).toList(),
        stats = summary(s, tasks, now: scope.clock()),
        categories = s
            .rows('categories')
            .where((c) => board == null || c.str('board') == board);
    return ListView(
      children: [
        Text(
          tr(context, 'Progress you can explain', 'Tiến độ có cơ sở'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          '${stats['done']} / ${stats['total']} ${tr(context, 'top-level tasks complete', 'task cấp đầu hoàn tất')}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          tr(
            context,
            'Archived, trash and subtasks are excluded from this denominator.',
            'Mẫu số không gồm task lưu trữ, thùng rác và task con.',
          ),
        ),
        Text('${stats['overdue']} ${tr(context, 'overdue', 'quá hạn')}'),
        Text(
          '${stats['doneEstimate']} / ${stats['estimate']} ${tr(context, 'estimated minutes completed', 'phút ước lượng đã hoàn tất')}',
        ),
        Text(
          '${stats['unknownEstimates']} ${tr(context, 'tasks have unknown estimates', 'task chưa có ước lượng')}',
        ),
        const Divider(height: 32),
        for (final c in categories) ...[
          Builder(
            builder: (context) {
              final group = tasks
                      .where((t) => t.str('category') == c.id)
                      .toList(),
                  p = summary(s, group, now: scope.clock());
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${c.str('title')} · ${p['done']}/${p['total']}'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: p['total'] == 0 ? 0 : p['done'] / p['total'],
                    color: categoryHue(c),
                    minHeight: 4,
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ],
        ExpansionTile(
          title: Text(
            tr(
              context,
              'Retained completion history · 14 days',
              'Lịch sử hoàn tất còn lưu · 14 ngày',
            ),
          ),
          children: [
            Text(
              tr(
                context,
                'Counts completion transitions of existing top-level tasks in the selected board. Reopening then completing again counts again. Deleted/expired history cannot be reconstructed. All-board dates use UTC; a board uses its timezone.',
                'Đếm lần chuyển sang hoàn tất của task cấp đầu còn tồn tại trong bảng. Mở lại rồi hoàn tất sẽ đếm thêm. Không thể dựng lại lịch sử đã xóa/hết hạn. Tất cả bảng dùng UTC; mỗi bảng dùng múi giờ của bảng.',
              ),
            ),
            for (final entry in completionHistory(
              s,
              scope.clock(),
              board: board,
            ).entries)
              ListTile(
                title: Text(entry.key),
                trailing: Text('${entry.value}'),
              ),
          ],
        ),
        Text(
          tr(context, 'Status distribution', 'Phân bố trạng thái'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final status
            in s
                .rows('statuses')
                .where((r) => board == null || r.str('board') == board))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(status.str('title')),
            trailing: Text(
              '${tasks.where((t) => t.str('status') == status.id).length}',
            ),
          ),
      ],
    );
  }
}
