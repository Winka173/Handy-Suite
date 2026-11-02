import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';

/// Adds or changes a pause: from, until (both picked on a calendar), for
/// every habit or the chosen ones, and an optional reason. [habit] starts
/// a new pause for that one habit.
Future<bool> openPauseEditor(
  BuildContext context,
  HabitScope scope, {
  Pause? old,
  String? habit,
}) {
  final s = scope.state, today = scope.today;
  final habits = {
    for (final h in s.habits.where((h) => !h.archived || h.id == habit))
      h.id: h.title,
    // A habit archived since keeps its place in an old pause.
    for (final id in old?.habits ?? const <String>[])
      id: scope.habit(id)?.title ?? id,
  };
  final chosen = old?.habits ?? (habit == null ? const <String>[] : [habit]);
  return showHabitForm(
    context,
    title: old == null
        ? tr(context, 'New pause', 'Kỳ nghỉ mới')
        : tr(context, 'Pause', 'Kỳ nghỉ'),
    saveLabel: tr(context, 'Save pause', 'Lưu kỳ nghỉ'),
    fields: [
      HabitField('from', 'From', 'Từ ngày', kind: FieldKind.date),
      HabitField(
        'until',
        'Until the end of',
        'Đến hết ngày',
        kind: FieldKind.date,
        helpEn:
            'Paused days are not missed and keep your runs. A day you do anyway still counts. No reminders meanwhile.',
        helpVi:
            'Ngày nghỉ không tính là lỡ và không làm đứt chuỗi. Ngày vẫn làm thì vẫn tính. Không nhắc trong thời gian này.',
      ),
      if (habits.isNotEmpty)
        HabitField(
          'scope',
          'For',
          'Cho',
          kind: FieldKind.choice,
          options: {
            'all': tr(context, 'Every habit', 'Mọi thói quen'),
            'some': tr(context, 'Chosen habits', 'Thói quen đã chọn'),
          },
        ),
      if (habits.isNotEmpty)
        HabitField(
          'habits',
          'Habits',
          'Thói quen',
          kind: FieldKind.many,
          options: habits,
          when: (v) => v['scope'] == 'some',
        ),
      const HabitField(
        'reason',
        'Reason',
        'Lý do',
        required: false,
        helpEn: 'Optional, for you: "Trip to Đà Lạt".',
        helpVi: 'Tùy chọn, cho riêng bạn: "Đi Đà Lạt".',
      ),
    ],
    initial: {
      'from': old?.from ?? today,
      'until': old?.until ?? addDays(today, 6),
      'scope': chosen.isEmpty ? 'all' : 'some',
      'habits': chosen,
      'reason': old?.reason ?? '',
    },
    save: (v) async {
      final from = v['from'] as String, until = v['until'] as String;
      if (until.compareTo(from) < 0)
        throw const FormatException(
          'The end is before the start / Ngày kết thúc trước ngày bắt đầu',
        );
      if (date(until).difference(date(from)).inDays + 1 > maxPauseDays)
        throw const FormatException('At most 366 days / Tối đa 366 ngày');
      final pause = Pause(
        id: old?.id ?? uid(),
        from: from,
        until: until,
        reason: (v['reason'] as String? ?? '').trim(),
        habits: v['scope'] == 'some'
            ? List<String>.from(v['habits'] as List? ?? [])
            : const [],
      );
      await scope.controller.change(
        (s) => putPause(s, pause, today: scope.today),
      );
    },
  );
}

/// "every habit", or the names of the chosen ones.
String pauseWho(BuildContext context, HabitScope scope, Pause p) => p.everything
    ? tr(context, 'Every habit', 'Mọi thói quen')
    : p.habits
          .map((h) => scope.habit(h)?.title ?? tr(context, 'deleted', 'đã xóa'))
          .join(', ');

/// "12/11 – 20/11", or one day.
String pauseRange(BuildContext context, Pause p) => p.from == p.until
    ? formatDay(context, p.from)
    : '${formatDay(context, p.from)} – ${formatDay(context, p.until)}';

/// Ends [p] early: today counts again. Says so, with Undo.
Future<bool> endPauseNow(BuildContext context, HabitScope scope, Pause p) =>
    scope.write(
      context,
      (s) => endPause(s, p.id, today: scope.today),
      done: (c) => tr(
        c,
        'Pause ended. Today counts again.',
        'Đã kết thúc kỳ nghỉ. Hôm nay tính lại như thường.',
      ),
    );

/// The pauses, newest first, each with its range, who it covers and its
/// reason; tap to change, the menu ends or deletes. [habit] keeps only
/// the ones that cover that habit.
class PauseList extends StatelessWidget {
  final HabitScope scope;
  final String? habit;
  const PauseList({super.key, required this.scope, this.habit});

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final today = scope.today;
    final pauses =
        scope.state.pauses
            .where(
              (p) => habit == null || p.everything || p.habits.contains(habit),
            )
            .toList()
          ..sort((a, b) => b.from.compareTo(a.from));
    if (pauses.isEmpty)
      return Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: Text(
          tr(
            context,
            'No pauses. Before a trip or a sick week, add one so those days are not missed.',
            'Chưa có kỳ nghỉ. Trước chuyến đi hay tuần ốm, thêm một kỳ để những ngày đó không bị tính là lỡ.',
          ),
          style: TextStyle(color: c.muted),
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in pauses)
          ListTile(
            key: Key('pause-${p.id}'),
            title: Text(pauseRange(context, p)),
            subtitle: Text(
              [
                switch (p.phase(today)) {
                  'current' => tr(context, 'now', 'đang nghỉ'),
                  'upcoming' => tr(context, 'coming', 'sắp tới'),
                  _ => tr(context, 'over', 'đã qua'),
                },
                if (habit == null || !p.everything)
                  pauseWho(context, scope, p)
                else
                  tr(context, 'every habit', 'mọi thói quen'),
                if (p.reason.isNotEmpty) p.reason,
              ].join(' · '),
            ),
            onTap: () => openPauseEditor(context, scope, old: p),
            trailing: HandyMenuButton(
              items: [
                if (p.phase(today) != 'past')
                  HandyMenuItem(
                    Icons.stop_circle_outlined,
                    p.phase(today) == 'current'
                        ? tr(context, 'End early', 'Kết thúc sớm')
                        : tr(context, 'Call off', 'Hủy kỳ nghỉ'),
                    () => endPauseNow(context, scope, p),
                    key: Key('pause-end-${p.id}'),
                  ),
                HandyMenuItem(
                  Icons.delete_outline,
                  tr(context, 'Delete', 'Xóa'),
                  () => scope.write(
                    context,
                    (s) => deletePause(s, p.id),
                    done: (c) => tr(
                      c,
                      'Pause deleted; its days count as before.',
                      'Đã xóa kỳ nghỉ; các ngày đó tính như cũ.',
                    ),
                  ),
                  destructive: true,
                  key: Key('pause-delete-${p.id}'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
