import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
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
  final locked =
      old != null &&
      (s.events.any((e) => e.habit == old.id) ||
          s.routines.any((r) => r.steps.any((step) => step.habit == old.id)) ||
          s.sessions.any(
            (v) =>
                v.status == 'active' &&
                v.steps.any((step) => step.plan.habit == old.id),
          ));
  return HabitForm(
    title: old == null
        ? tr(context, 'New habit', 'Thói quen mới')
        : tr(context, 'Edit ${old.title}', 'Sửa ${old.title}'),
    fields: [
      const HabitField(
        'title',
        'Name',
        'Tên',
        helpEn: 'Small and concrete: Read 10 pages, Walk after lunch.',
        helpVi: 'Nhỏ và cụ thể: Đọc 10 trang, Đi bộ sau bữa trưa.',
      ),
      HabitField(
        'type',
        'It is counted as',
        'Ghi nhận theo',
        kind: FieldKind.choice,
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
        when: (v) => v['type'] == 'quantity',
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
        when: (v) => v['type'] != 'binary',
        helpEn: 'Up to three decimals; times must be whole.',
        helpVi: 'Tối đa ba số lẻ; số lần phải là số nguyên.',
      ),
      HabitField(
        'schedule',
        'How often',
        'Bao lâu một lần',
        kind: FieldKind.choice,
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
        when: (v) => v['schedule'] == 'weekdays',
      ),
      HabitField(
        'quota',
        'Days each week',
        'Số ngày mỗi tuần',
        kind: FieldKind.count,
        when: (v) => v['schedule'] == 'weekly',
        helpEn: '1 to 7, on any days you like.',
        helpVi: 'Từ 1 đến 7, vào ngày nào cũng được.',
      ),
      HabitField(
        'interval',
        'Every how many days',
        'Cách bao nhiêu ngày',
        kind: FieldKind.count,
        when: (v) => v['schedule'] == 'interval',
        helpEn: '1 to 366.',
        helpVi: 'Từ 1 đến 366.',
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
      'title':
          old?.title ??
          (preset == null ? '' : tr(context, preset.en, preset.vi)),
      'type': old?.type ?? preset?.type ?? 'binary',
      'unit':
          old?.unit ??
          (preset == null ? '' : tr(context, preset.unitEn, preset.unitVi)),
      'target': current?.target ?? preset?.stored ?? 1000,
      'schedule': current?.kind ?? preset?.schedule ?? 'daily',
      'weekdays':
          current?.weekdays ?? preset?.weekdays ?? const [1, 2, 3, 4, 5],
      'quota': '${current?.weeklyTarget ?? preset?.perWeek ?? 3}',
      'interval': '${current?.interval ?? 2}',
      'effective': effective,
      'end': old?.end ?? '',
      'category':
          old?.category ??
          (preset == null
              ? ''
              : tr(
                  context,
                  habitPresetGroups[preset.group]!.$1,
                  habitPresetGroups[preset.group]!.$2,
                )),
      'dayPart': (s.settings['habitDayParts'] as Map?)?[old?.id] ?? 'auto',
      'priority': '${old?.priority ?? 1}',
      'note': old?.note ?? '',
    },
    save: (v) async {
      final type = v['type'] as String, kind = v['schedule'] as String;
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
      final unit = type == 'duration' ? 'min' : (v['unit'] as String? ?? '');
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
        target: type == 'binary' ? 1000 : v['target'] as int,
        weekdays: kind == 'weekdays'
            ? List<int>.from(v['weekdays'] as List)
            : current?.weekdays ?? const [1, 2, 3, 4, 5],
        weeklyTarget: int.parse('${v['quota'] ?? 3}'),
        interval: int.parse('${v['interval'] ?? 2}'),
      );
      final next = Habit(
        id: old?.id ?? uid(),
        title: v['title'] as String,
        created: old?.created ?? from,
        schedules: [...?old?.schedules, schedule],
        note: v['note'] as String,
        type: type,
        unit: unit,
        category: v['category'] as String,
        priority: int.parse('${v['priority']}'),
        icon: old?.icon ?? 0xe876,
        color: old?.color ?? 0xffb42318,
        archived: old?.archived ?? false,
        archivedFrom: old?.archivedFrom,
        archivedPeriods: old?.archivedPeriods ?? [],
        end: end.isEmpty ? null : end,
      );
      await scope.controller.change(
        (s) => s.copy({
          'settings': {
            ...s.settings,
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
