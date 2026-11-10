import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../today/check_in.dart';
import '../ui/words.dart';
import 'habit_editor.dart';
import 'month_grid.dart';

/// A habit on a page of its own (phones and web links).
class HabitPage extends StatelessWidget {
  final HabitScope scope;
  final String id;
  const HabitPage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final h = scope.habit(id);
      return Scaffold(
        appBar: AppBar(
          title: Text(h?.title ?? ''),
          actions: [if (h != null) HabitMenu(scope: scope, habit: h)],
        ),
        body: h == null
            ? Center(
                child: HandyEmpty(
                  title: tr(
                    context,
                    'This habit is gone',
                    'Thói quen này không còn',
                  ),
                ),
              )
            : HabitView(scope: scope, habit: h, showTitle: false),
      );
    },
  );
}

/// How a habit has gone: its run of days, a month of beads (tap a day to
/// fill it in), the schedules it has had and what was recorded.
class HabitView extends StatelessWidget {
  final HabitScope scope;
  final Habit habit;
  final bool showTitle;
  const HabitView({
    super.key,
    required this.scope,
    required this.habit,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final h = habit, s = scope.state, today = scope.today;
    final index = scope.index;
    final m = metrics(h, today, s.weekStart, index);
    final current = scheduleOn(h, today) ?? h.schedules.last;
    // The next planned day that is not paused.
    String? next = nextDueDate(h, today);
    for (var i = 0; next != null && index.paused(h.id, next) && i < 400; i++)
      next = nextDueDate(h, addDays(next, 1));
    final events = s.events.where((e) => e.habit == h.id).toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final unit = m.unit == 'weeks'
        ? tr(context, 'weeks', 'tuần')
        : tr(context, 'days', 'ngày');
    Widget figureCell(String label, String value, {Key? key}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
          Text(
            value,
            key: key,
            style: theme.textTheme.titleLarge?.copyWith(fontFeatures: tabular),
          ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [
        Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: HandySpace.content),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTitle)
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            h.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      HabitMenu(scope: scope, habit: h),
                    ],
                  ),
                Text(
                  [
                    scheduleText(context, current),
                    if (h.type != 'binary')
                      '${figure(context, current.target)} ${unitOf(context, h)}',
                    if (h.category.isNotEmpty) h.category,
                    if (h.archived) tr(context, 'archived', 'đã lưu trữ'),
                  ].join(' · '),
                  style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
                ),
                if (h.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: HandySpace.s),
                    child: Text(h.note),
                  ),
                const SizedBox(height: HandySpace.l),
                Row(
                  children: [
                    figureCell(
                      tr(context, 'Running now', 'Chuỗi hiện tại'),
                      '${m.current} $unit',
                      key: const Key('habit-current'),
                    ),
                    figureCell(
                      tr(context, 'Longest', 'Dài nhất'),
                      '${m.longest} $unit',
                    ),
                    figureCell(
                      tr(context, 'Done', 'Đã làm'),
                      tr(
                        context,
                        '${m.completed} of ${m.eligible}',
                        '${m.completed}/${m.eligible}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: HandySpace.xs),
                Text(
                  tr(
                    context,
                    'Counted over planned $unit that have closed; skipped and paused days and today, if not done yet, are left out.',
                    'Tính trên số $unit có lịch đã qua; bỏ ngày bỏ qua, ngày nghỉ và hôm nay nếu chưa làm.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
                HandySection(
                  title: tr(context, 'Month', 'Tháng'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(HandySpace.s),
                      child: MonthGrid(
                        habit: h,
                        today: today,
                        weekStart: s.weekStart,
                        backfill: s.backfill,
                        index: index,
                        onDay: (d) => editDay(context, scope, h, d),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: Text(
                        tr(
                          context,
                          'Tap a day in the last ${s.backfill} days to fill it in.${next == null ? '' : ' Next planned: ${dayText(context, next, today).toLowerCase()}.'}',
                          'Chạm một ngày trong ${s.backfill} ngày gần nhất để ghi bù.${next == null ? '' : ' Lần có lịch tới: ${dayText(context, next, today).toLowerCase()}.'}',
                        ),
                        style: TextStyle(color: c.muted),
                      ),
                    ),
                  ],
                ),
                if (s.pauses.any(
                  (p) => p.everything || p.habits.contains(h.id),
                ))
                  HandySection(
                    title: tr(context, 'Pauses', 'Kỳ nghỉ'),
                    children: [PauseList(scope: scope, habit: h.id)],
                  ),
                HandySection(
                  title: tr(context, 'Schedules', 'Các lịch đã dùng'),
                  children: [
                    for (final v in h.schedules.reversed)
                      ListTile(
                        title: Text(
                          [
                            scheduleText(context, v),
                            if (h.type != 'binary')
                              '${figure(context, v.target)} ${unitOf(context, h)}',
                          ].join(' · '),
                        ),
                        subtitle: Text(
                          tr(
                            context,
                            'from ${formatDay(context, v.from)}',
                            'từ ${formatDay(context, v.from)}',
                          ),
                        ),
                      ),
                  ],
                ),
                HandySection(
                  title: tr(context, 'Recorded', 'Đã ghi'),
                  children: [
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(HandySpace.l),
                        child: Text(
                          tr(
                            context,
                            'Nothing recorded yet.',
                            'Chưa ghi lần nào.',
                          ),
                        ),
                      ),
                    for (final e in events.take(30))
                      ListTile(
                        title: Text(
                          e.skipped
                              ? statusLabel(context, 'skipped')
                              : h.type == 'binary'
                              ? tr(context, 'Done', 'Đã xong')
                              : '${figure(context, e.value)} ${unitOf(context, h)}',
                        ),
                        subtitle: Text(
                          [
                            dayText(context, e.day, today),
                            if (e.source == 'routine')
                              tr(context, 'from a routine', 'từ quy trình'),
                            if (e.note.isNotEmpty) e.note,
                          ].join(' · '),
                        ),
                      ),
                    if (events.length > 30)
                      Padding(
                        padding: const EdgeInsets.all(HandySpace.l),
                        child: Text(
                          tr(
                            context,
                            '${events.length - 30} older entries are in the exports.',
                            'Còn ${events.length - 30} lần cũ hơn trong file xuất.',
                          ),
                          style: TextStyle(color: c.muted),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Edit, archive, duplicate, move, delete.
class HabitMenu extends StatelessWidget {
  final HabitScope scope;
  final Habit habit;
  const HabitMenu({super.key, required this.scope, required this.habit});

  HabitState _move(HabitState s, int delta) {
    final list = s.habits.toList(),
        old = list.indexWhere((v) => v.id == habit.id),
        next = (old + delta).clamp(0, list.length - 1);
    list.insert(next, list.removeAt(old));
    return s.copy({'habits': list.map((e) => e.toJson()).toList()});
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${habit.title}?', 'Xóa ${habit.title}?'),
      message: tr(
        context,
        'It stays in Trash for 30 days with its records and links. Then its records are removed and routine links are cleared.',
        'Giữ trong Thùng rác 30 ngày cùng các lần ghi và liên kết. Sau đó xóa các lần ghi và bỏ liên kết quy trình.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final h = habit;
    final done = await scope.write(
      context,
      (s) => trashEntity(s, 'habit', h.id, scope.clock()),
      done: (c) => tr(
        c,
        '${h.title} moved to Trash.',
        'Đã chuyển ${h.title} vào Thùng rác.',
      ),
    );
    if (done && navigator.canPop()) navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final h = habit, today = scope.today;
    return HandyMenuButton(
      items: [
        HandyMenuItem(
          Icons.edit_outlined,
          tr(context, 'Edit', 'Sửa'),
          () => openHabitEditor(context, scope, h),
          key: const Key('habit-edit'),
        ),
        HandyMenuItem(
          h.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          h.archived
              ? tr(context, 'Bring back', 'Dùng lại')
              : tr(context, 'Archive', 'Lưu trữ'),
          () => scope.write(
            context,
            (s) => s.copy({
              'habits': [
                for (final x in s.habits)
                  x.id == h.id
                      ? archiveHabit(x, today, !x.archived).toJson()
                      : x.toJson(),
              ],
            }),
            done: (c) => h.archived
                ? tr(c, '${h.title} is back.', 'Đã dùng lại ${h.title}.')
                : tr(
                    c,
                    '${h.title} archived from tomorrow; its history stays.',
                    'Lưu trữ ${h.title} từ ngày mai; lịch sử vẫn giữ.',
                  ),
          ),
          key: const Key('habit-archive'),
        ),
        if (!h.archived)
          HandyMenuItem(
            Icons.pause_circle_outline,
            tr(context, 'Pause this habit', 'Nghỉ thói quen này'),
            () => openPauseEditor(context, scope, habit: h.id),
            key: const Key('habit-pause'),
          ),
        HandyMenuItem(
          Icons.copy_outlined,
          tr(
            context,
            'Duplicate without history',
            'Nhân bản không kèm lịch sử',
          ),
          () => scope.write(context, (s) {
            final schedule = scheduleOn(h, today) ?? h.schedules.last;
            return s.copy({
              'habits': [
                ...s.habits.map((e) => e.toJson()),
                h.copy({
                  'id': uid(),
                  'title': tr(
                    context,
                    '${h.title} (copy)',
                    '${h.title} (bản sao)',
                  ),
                  'created': today,
                  'end': null,
                  'archived': false,
                  'archivedFrom': null,
                  'archivedPeriods': [],
                  'schedules': [
                    {...schedule.toJson(), 'id': uid(), 'from': today},
                  ],
                }).toJson(),
              ],
            });
          }, done: (c) => tr(c, 'Duplicated.', 'Đã nhân bản.')),
          key: const Key('habit-duplicate'),
        ),
        HandyMenuItem(
          Icons.arrow_upward,
          tr(context, 'Move up', 'Lên trên'),
          () => scope.write(context, (s) => _move(s, -1)),
        ),
        HandyMenuItem(
          Icons.arrow_downward,
          tr(context, 'Move down', 'Xuống dưới'),
          () => scope.write(context, (s) => _move(s, 1)),
        ),
        HandyMenuItem(
          Icons.delete_outline,
          tr(context, 'Delete', 'Xóa'),
          () => _delete(context),
          destructive: true,
          key: const Key('habit-delete'),
        ),
      ],
    );
  }
}
