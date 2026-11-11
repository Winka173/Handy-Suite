import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../settings/settings_page.dart' show habitAllowNotifications;
import '../ui/form.dart';
import '../ui/words.dart';

/// Creates a habit, or gives an existing one a new schedule from a day
/// that has not passed. Its history keeps the old schedule; the kind of
/// tracking and the unit stay once anything has been recorded.
Future<bool> openHabitEditor(
  BuildContext context,
  HabitScope scope, [
  Habit? old,
  HabitPreset? preset,
]) async =>
    await Navigator.pushNamed<bool>(
      context,
      old == null ? '/habit/new' : '/habit/${old.id}/edit',
      arguments: preset,
    ) ==
    true;

Widget buildHabitEditor(
  BuildContext context,
  HabitScope scope, [
  Habit? old,
  HabitPreset? preset,
  String? name,
]) {
  final s = scope.state, today = scope.today;
  final current = old == null
      ? null
      : (scheduleOn(old, today) ?? old.schedules.last);
  var effective = old == null
      ? today
      : (old.schedules.last.from.compareTo(today) >= 0
            ? addDays(old.schedules.last.from, 1)
            : today);
  if (old != null && current!.kind == 'weekly')
    while (date(effective).weekday != s.weekStart) {
      effective = addDays(effective, 1);
    }
  final negativeGoal = old == null
      ? null
      : negativeGoalOn(old, today) ?? old.negativeGoals.lastOrNull;
  var negativeEffective = effective;
  if (negativeGoal?.window == 'week') {
    while (date(negativeEffective).weekday != negativeGoal!.weekStart)
      negativeEffective = addDays(negativeEffective, 1);
  }
  final locked =
      old != null &&
      (s.events.any((e) => e.habit == old.id) ||
          s.routines.any((r) => r.steps.any((step) => step.habit == old.id)) ||
          s.sessions.any(
            (v) =>
                v.status == 'active' &&
                v.steps.any((step) => step.plan.habit == old.id),
          ));
  // The habit's own reminder (the first one, when there are several).
  final reminder = old == null
      ? null
      : objects(s.settings['reminders'] ?? [])
            .map(Reminder.fromJson)
            .where((r) => r.type == 'habit' && r.target == old.id)
            .firstOrNull;
  return HabitForm(
    title: old == null
        ? tr(context, 'New habit', 'Thói quen mới')
        : tr(context, 'Edit ${old.title}', 'Sửa ${old.title}'),
    fields: [
      HabitField(
        'direction',
        'Your intention',
        'Điều bạn muốn',
        kind: FieldKind.choice,
        options: {
          if (!locked || !old.isNegative)
            'build': tr(context, 'Build a habit', 'Xây dựng thói quen'),
          if (!locked || old.isNegative)
            'reduce': tr(context, 'Break a habit', 'Giảm thói quen'),
        },
        helpEn: locked
            ? 'Fixed once recorded or linked to a routine.'
            : 'Build something useful, or reduce something you want less of.',
        helpVi: locked
            ? 'Không đổi khi đã ghi nhận hoặc liên kết quy trình.'
            : 'Xây điều hữu ích, hoặc giảm điều bạn muốn bớt.',
      ),
      const HabitField(
        'title',
        'Name',
        'Tên',
        helpEn: 'Small and concrete: Read 10 pages, Walk after lunch.',
        helpVi: 'Nhỏ và cụ thể: Đọc 10 trang, Đi bộ sau bữa trưa.',
      ),
      const HabitField(
        'look',
        'Icon and colour',
        'Biểu tượng và màu',
        kind: FieldKind.look,
        required: false,
      ),
      HabitField(
        'ceilingMode',
        'Limit',
        'Giới hạn',
        kind: FieldKind.choice,
        when: (v) => v['direction'] == 'reduce',
        options: {
          'zero': tr(context, 'None at all', 'Không lần nào'),
          'limit': tr(context, 'At most', 'Tối đa'),
        },
      ),
      HabitField(
        'ceiling',
        'At most N incidents',
        'Tối đa bao nhiêu lần',
        kind: FieldKind.count,
        when: (v) => v['direction'] == 'reduce' && v['ceilingMode'] == 'limit',
        helpEn: 'A whole number, including zero. For example, 3 sugary drinks.',
        helpVi: 'Số nguyên, có thể là 0. Ví dụ: 3 lần uống nước ngọt.',
      ),
      HabitField(
        'window',
        'Per',
        'Trong mỗi',
        kind: FieldKind.choice,
        when: (v) => v['direction'] == 'reduce',
        options: {
          'day': tr(context, 'Day', 'Ngày'),
          'week': tr(context, 'Week', 'Tuần'),
        },
        helpEn:
            'When the week ends, count the incidents you recorded; blank days mean none. With a daily limit, a blank day stays unknown.',
        helpVi:
            'Khi hết tuần, tính những lần bạn đã ghi; ngày trống hiểu là không có. Với giới hạn ngày, ngày trống vẫn chưa rõ.',
      ),
      HabitField(
        'type',
        'It is counted as',
        'Ghi nhận theo',
        kind: FieldKind.choice,
        when: (v) => v['direction'] != 'reduce',
        options: {
          for (final t in ['binary', 'count', 'duration', 'quantity'])
            if (!locked || t == old.type) t: typeLabel(context, t),
        },
        helpEn: locked ? 'Fixed once something is recorded.' : null,
        helpVi: locked ? 'Không đổi được khi đã có ghi nhận.' : null,
      ),
      HabitField(
        'unit',
        'Unit',
        'Đơn vị',
        when: (v) => v['direction'] != 'reduce' && v['type'] == 'quantity',
        helpEn: locked
            ? 'Fixed once something is recorded.'
            : 'pages, glasses, km…',
        helpVi: locked
            ? 'Không đổi được khi đã có ghi nhận.'
            : 'trang, ly, km…',
      ),
      HabitField(
        'target',
        'Each day, at least',
        'Mỗi ngày tối thiểu',
        kind: FieldKind.amount,
        when: (v) => v['direction'] != 'reduce' && v['type'] != 'binary',
      ),
      HabitField(
        'schedule',
        'How often',
        'Bao lâu một lần',
        kind: FieldKind.choice,
        when: (v) => v['direction'] != 'reduce',
        advancedOptions: const {'weekly', 'interval'},
        options: {
          'daily': tr(context, 'Every day', 'Mỗi ngày'),
          'weekdays': tr(context, 'On some days', 'Vào vài thứ'),
          'weekly': tr(context, 'Days a week', 'Số ngày mỗi tuần'),
          'interval': tr(context, 'Every few days', 'Cách vài ngày'),
        },
      ),
      HabitField(
        'weekdays',
        'On',
        'Vào',
        kind: FieldKind.weekdays,
        when: (v) => v['direction'] != 'reduce' && v['schedule'] == 'weekdays',
      ),
      HabitField(
        'quota',
        'Days each week',
        'Số ngày mỗi tuần',
        kind: FieldKind.count,
        when: (v) => v['direction'] != 'reduce' && v['schedule'] == 'weekly',
        helpEn: '1 to 7, on any days you like.',
        helpVi: 'Từ 1 đến 7, vào ngày nào cũng được.',
      ),
      HabitField(
        'interval',
        'Every how many days',
        'Cách bao nhiêu ngày',
        kind: FieldKind.count,
        when: (v) => v['direction'] != 'reduce' && v['schedule'] == 'interval',
        helpEn: '1 to 366.',
        helpVi: 'Từ 1 đến 366.',
      ),
      HabitField(
        'remind',
        'Remind me',
        'Nhắc tôi',
        kind: FieldKind.toggle,
        helpEn: scope.reminders.supported
            ? 'A notice at the time you choose, on the days it is planned.'
            : 'This platform shows the next reminder on Today instead.',
        helpVi: scope.reminders.supported
            ? 'Một thông báo vào giờ bạn chọn, những ngày có lịch.'
            : 'Nền tảng này hiện lần nhắc tiếp theo ở Hôm nay.',
      ),
      HabitField(
        'remindAt',
        'At',
        'Lúc',
        kind: FieldKind.time,
        when: (v) => v['remind'] == true,
      ),
      HabitField(
        'effective',
        old == null ? 'Starts' : 'New schedule from',
        old == null ? 'Bắt đầu' : 'Lịch mới áp dụng từ',
        kind: FieldKind.date,
        advanced: old == null,
        helpEn: old == null ? null : 'Past days keep the schedule they had.',
        helpVi: old == null ? null : 'Những ngày đã qua giữ lịch cũ.',
      ),
      const HabitField(
        'end',
        'Ends',
        'Kết thúc',
        advanced: true,
        kind: FieldKind.date,
        required: false,
      ),
      const HabitField(
        'category',
        'Group',
        'Nhóm',
        advanced: true,
        required: false,
        helpEn: 'Health, Study… Habits are listed by group.',
        helpVi: 'Sức khỏe, Học tập… Thói quen được xếp theo nhóm.',
      ),
      HabitField(
        'dayPart',
        'Time of day',
        'Buổi trong ngày',
        advanced: true,
        kind: FieldKind.choice,
        options: {
          'auto': tr(
            context,
            'From reminders / routines',
            'Theo nhắc / quy trình',
          ),
          'morning': tr(context, 'Morning', 'Buổi sáng'),
          'afternoon': tr(context, 'Afternoon', 'Buổi chiều'),
          'evening': tr(context, 'Evening', 'Buổi tối'),
          'anytime': tr(context, 'Any time', 'Bất kỳ lúc nào'),
        },
      ),
      const HabitField(
        'priority',
        'Priority',
        'Ưu tiên',
        advanced: true,
        kind: FieldKind.count,
        helpEn: '0 to 9; higher comes first on Today.',
        helpVi: 'Từ 0 đến 9; cao hơn đứng trước ở Hôm nay.',
      ),
      const HabitField(
        'note',
        'Note',
        'Ghi chú',
        advanced: true,
        kind: FieldKind.note,
        required: false,
      ),
    ],
    initial: {
      'direction': old?.direction ?? preset?.direction ?? 'build',
      'ceilingMode': (negativeGoal?.limit ?? preset?.limit ?? 0) == 0
          ? 'zero'
          : 'limit',
      'ceiling':
          '${negativeGoal == null ? preset?.limit ?? 3 : negativeGoal.limit ~/ 1000}',
      'window': negativeGoal?.window ?? preset?.window ?? 'day',
      'title':
          old?.title ??
          (preset == null ? name ?? '' : tr(context, preset.en, preset.vi)),
      'type': old?.type ?? preset?.type ?? 'binary',
      'unit':
          old?.unit ??
          (preset == null ? '' : tr(context, preset.unitEn, preset.unitVi)),
      'target':
          current?.target ??
          preset?.stored ??
          s.settings['defaultGoal'] ??
          1000,
      'schedule':
          current?.kind ??
          preset?.schedule ??
          s.settings['defaultSchedule'] ??
          'daily',
      'weekdays':
          current?.weekdays ?? preset?.weekdays ?? const [1, 2, 3, 4, 5],
      'quota': '${current?.weeklyTarget ?? preset?.perWeek ?? 3}',
      'interval': '${current?.interval ?? 2}',
      'effective': old?.isNegative == true ? negativeEffective : effective,
      'end': old?.end ?? '',
      'category':
          old?.category ??
          (preset == null
              ? ''
              : tr(
                  context,
                  templateCollections[preset.collection]!.en,
                  templateCollections[preset.collection]!.vi,
                )),
      'dayPart': (s.settings['habitDayParts'] as Map?)?[old?.id] ?? 'auto',
      'priority': '${old?.priority ?? 1}',
      'note': old?.note ?? '',
      'look': {
        'icon': old?.icon ?? preset?.icon ?? 0xe876,
        'color': old?.color ?? preset?.color ?? 0xffb42318,
      },
      'remind': reminder != null,
      'remindAt': reminder?.time ?? '08:00',
    },
    save: (v) async {
      final negative = v['direction'] == 'reduce';
      final type = negative ? 'count' : v['type'] as String,
          kind = negative ? 'daily' : v['schedule'] as String;
      if (locked && v['direction'] != old.direction)
        throw const FormatException('Keep the intention / Giữ điều bạn muốn');
      final from = v['effective'] as String, end = v['end'] as String;
      if (old != null &&
          (from.compareTo(today) < 0 ||
              from.compareTo(old.schedules.last.from) <= 0))
        throw const FormatException(
          'Choose a day that has not passed / Hãy chọn một ngày chưa qua',
        );
      if ((kind == 'weekly' || current?.kind == 'weekly') &&
          old != null &&
          date(from).weekday != s.weekStart)
        throw FormatException(
          'Start a weekly schedule on ${weekdayLong(context, s.weekStart)} / Lịch theo tuần bắt đầu vào ${weekdayLong(context, s.weekStart)}',
        );
      final unit = negative
          ? ''
          : type == 'duration'
          ? 'min'
          : (v['unit'] as String? ?? '');
      if (type == 'quantity' && unit.isEmpty)
        throw const FormatException('Name the unit / Hãy đặt tên đơn vị');
      if (locked && (type != old.type || unit != old.unit))
        throw const FormatException(
          'Keep the kind and unit, or duplicate the habit / Giữ loại và đơn vị, hoặc nhân bản thói quen',
        );
      if (end.isNotEmpty && end.compareTo(today) < 0 && end != old?.end)
        throw const FormatException(
          'The end cannot be in the past / Ngày kết thúc không thể ở quá khứ',
        );
      final schedule = Schedule(
        id: uid(),
        from: from,
        kind: kind,
        weekStart: s.weekStart,
        target: negative || type == 'binary' ? 1000 : v['target'] as int,
        weekdays: kind == 'weekdays'
            ? List<int>.from(v['weekdays'] as List)
            : current?.weekdays ?? const [1, 2, 3, 4, 5],
        weeklyTarget: int.parse('${v['quota'] ?? 3}'),
        interval: int.parse('${v['interval'] ?? 2}'),
      );
      if (negative &&
          v['ceilingMode'] == 'limit' &&
          ((v['ceiling'] as int) < 0 ||
              (v['ceiling'] as int) > maxValue ~/ 1000))
        throw const FormatException(
          'Use a non-negative whole limit / Dùng giới hạn là số nguyên không âm',
        );
      final next = Habit(
        id: old?.id ?? uid(),
        title: v['title'] as String,
        created: old?.created ?? from,
        schedules: [...?old?.schedules, schedule],
        note: v['note'] as String,
        type: type,
        direction: negative ? 'reduce' : 'build',
        negativeGoals: negative
            ? [
                ...?old?.negativeGoals,
                NegativeGoal(
                  id: uid(),
                  from: old != null && !old.isNegative ? old.created : from,
                  window: v['window'] as String,
                  limit: v['ceilingMode'] == 'zero'
                      ? 0
                      : int.parse('${v['ceiling']}') * 1000,
                  weekStart: s.weekStart,
                ),
              ]
            : [],
        unit: unit,
        category: v['category'] as String,
        priority: int.parse('${v['priority']}'),
        icon: (v['look'] as Map?)?['icon'] as int? ?? old?.icon ?? 0xe876,
        color:
            (v['look'] as Map?)?['color'] as int? ?? old?.color ?? 0xffb42318,
        archived: old?.archived ?? false,
        archivedFrom: old?.archivedFrom,
        archivedPeriods: old?.archivedPeriods ?? [],
        end: end.isEmpty ? null : end,
      );
      final remind = v['remind'] == true;
      final notify = remind && s.settings['notifications'] != true
          ? await habitAllowNotifications(context, scope)
          : s.settings['notifications'] == true;
      final rule = remind
          ? Reminder(
              id: reminder?.id ?? uid(),
              target: next.id,
              type: 'habit',
              time: v['remindAt'] as String,
              weekdays: reminder?.weekdays ?? const [1, 2, 3, 4, 5, 6, 7],
            )
          : null;
      await scope.controller.change(
        (s) => s.copy({
          'settings': {
            ...s.settings,
            if (remind) 'notifications': notify,
            'reminders': [
              for (final x in objects(s.settings['reminders'] ?? []))
                if (x['id'] != reminder?.id) x,
              ?rule?.toJson(),
            ],
            'habitDayParts': <String, dynamic>{
              ...Map<String, dynamic>.from(
                s.settings['habitDayParts'] as Map? ?? {},
              ),
              next.id: v['dayPart'],
            },
          },
          'habits': [
            for (final h in s.habits)
              if (h.id != next.id) h.toJson(),
            next.toJson(),
          ],
        }),
      );
      if (context.mounted)
        scope.announce(
          context,
          old == null
              ? tr(context, 'Habit added.', 'Đã thêm thói quen.')
              : tr(context, 'Habit saved.', 'Đã lưu thói quen.'),
        );
    },
  );
}
