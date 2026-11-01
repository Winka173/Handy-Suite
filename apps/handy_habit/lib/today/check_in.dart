import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/words.dart';

/// One tap on today's bead. Done-or-not and counts record at once (never
/// past the target); minutes and amounts ask how much; a full bead opens
/// the day instead.
Future<void> checkIn(BuildContext context, HabitScope scope, Habit h) async {
  final today = scope.today, index = scope.index;
  final target = scheduleOn(h, today)?.target ?? 1000;
  final value = index.value(h.id, today);
  if (value >= target || index.skip(h.id, today)) {
    await editDay(context, scope, h, today);
    return;
  }
  if (h.type == 'duration' || h.type == 'quantity') {
    await addAmount(context, scope, h);
    return;
  }
  await record1(context, scope, h, 1000);
}

/// Records [value] (thousandths) for today, once.
Future<bool> record1(
  BuildContext context,
  HabitScope scope,
  Habit h,
  int value,
) {
  final today = scope.today;
  return scope.write(
    context,
    (s) => record(
      s,
      HabitEvent(id: uid(), habit: h.id, day: today, value: value),
      today: today,
    ),
    done: (c) {
      final target = scheduleOn(h, today)?.target ?? 1000;
      final now = HabitIndex(scope.state.events).value(h.id, today);
      return h.type == 'binary'
          ? tr(c, '${h.title}: done.', '${h.title}: đã xong.')
          : '${h.title}: ${progressText(c, h, now, target)}';
    },
  );
}

/// Minutes or an amount: the rest of the target in one tap, or a number.
Future<void> addAmount(BuildContext context, HabitScope scope, Habit h) async {
  final today = scope.today;
  final target = scheduleOn(h, today)?.target ?? 1000;
  final left = target - scope.index.value(h.id, today);
  final unit = unitOf(context, h);
  final chosen = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          0,
          HandySpace.l,
          HandySpace.l,
        ),
        child: _AmountPicker(habit: h, left: left, unit: unit),
      ),
    ),
  );
  if (chosen != null && chosen > 0 && context.mounted)
    await record1(context, scope, h, chosen);
}

class _AmountPicker extends StatefulWidget {
  final Habit habit;
  final int left;
  final String unit;
  const _AmountPicker({
    required this.habit,
    required this.left,
    required this.unit,
  });
  @override
  State<_AmountPicker> createState() => _AmountPickerState();
}

class _AmountPickerState extends State<_AmountPicker> {
  final custom = TextEditingController();
  String error = '';
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  void submit() {
    try {
      Navigator.pop(context, quantity(custom.text.trim().replaceAll(',', '.')));
    } catch (_) {
      setState(() => error = tr(context, 'Not a number', 'Không phải số'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final half = (widget.left / 2).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.habit.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            FilledButton(
              key: const Key('amount-rest'),
              onPressed: () => Navigator.pop(context, widget.left),
              child: Text(
                tr(
                  context,
                  'All of it: ${figure(context, widget.left)} ${widget.unit}',
                  'Đủ mục tiêu: ${figure(context, widget.left)} ${widget.unit}',
                ),
              ),
            ),
            if (half > 0 && half < widget.left)
              OutlinedButton(
                key: const Key('amount-half'),
                onPressed: () => Navigator.pop(context, half),
                child: Text('${figure(context, half)} ${widget.unit}'),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        Text(
          tr(context, 'Or how much', 'Hoặc nhập số'),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: HandySpace.s),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('amount-custom'),
                controller: custom,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: widget.unit,
                  errorText: error.isEmpty ? null : error,
                ),
                onSubmitted: (_) => submit(),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            OutlinedButton(
              key: const Key('amount-add'),
              onPressed: submit,
              child: Text(tr(context, 'Add', 'Cộng')),
            ),
          ],
        ),
      ],
    );
  }
}

/// The whole of one day: its total, a skip with a reason, a note. Progress
/// that came from a routine stays; only what was typed by hand changes.
Future<void> editDay(
  BuildContext context,
  HabitScope scope,
  Habit h,
  String d,
) async {
  final index = scope.index;
  final binary = h.type == 'binary';
  final note = scope.state.events
      .where((e) => e.habit == h.id && e.day == d && e.source == 'manual')
      .map((e) => e.note)
      .where((n) => n.isNotEmpty)
      .lastOrNull;
  final saved = await showHabitForm(
    context,
    title: '${h.title} · ${dayText(context, d, scope.today)}',
    fields: [
      HabitField(
        'state',
        'This day',
        'Ngày này',
        kind: FieldKind.choice,
        options: {
          'done': binary
              ? tr(context, 'Done', 'Đã xong')
              : tr(context, 'Some done', 'Có làm'),
          'none': tr(context, 'Not done', 'Chưa làm'),
          'skip': tr(context, 'Skipped, with a reason', 'Bỏ qua có lý do'),
        },
        helpEn: 'A skipped day does not count as done or missed.',
        helpVi: 'Ngày bỏ qua không tính là xong, cũng không tính là lỡ.',
      ),
      if (!binary)
        HabitField(
          'total',
          'Total for the day',
          'Tổng của ngày',
          kind: FieldKind.amount,
          when: (v) => v['state'] == 'done',
          helpEn: 'In ${unitOf(context, h)}; up to three decimals.',
          helpVi: 'Theo ${unitOf(context, h)}; tối đa ba số lẻ.',
        ),
      const HabitField(
        'note',
        'Note',
        'Ghi chú',
        kind: FieldKind.note,
        required: false,
      ),
    ],
    initial: {
      'state': index.skip(h.id, d)
          ? 'skip'
          : index.value(h.id, d) > 0
          ? 'done'
          : 'none',
      'total': index.value(h.id, d) > 0
          ? index.value(h.id, d)
          : scheduleOn(h, d)?.target,
      'note': note ?? '',
    },
    save: (v) async {
      final state = v['state'] as String;
      final total = switch (state) {
        'done' => binary ? 1000 : v['total'] as int,
        _ => 0,
      };
      await scope.controller.change(
        (s) => setManualTotal(
          s,
          h.id,
          d,
          total,
          today: scope.today,
          note: v['note'] as String,
          skipped: state == 'skip',
        ),
      );
    },
  );
  if (saved && context.mounted)
    scope.announce(
      context,
      tr(context, '${h.title}: day saved.', '${h.title}: đã lưu ngày.'),
    );
}
