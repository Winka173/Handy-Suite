import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/capped.dart';
import '../pro/entitlements.dart';

class HabitRulesPage extends StatelessWidget {
  final HabitScope scope;
  const HabitRulesPage({super.key, required this.scope});
  String historyLine(BuildContext c, HabitOperation op) {
    final value = op.after!['value'] as Map;
    final names = (value['habits'] as List? ?? []).join(', ');
    final effect = value['kind'] == 'routine'
        ? '$names +1'
        : value['from'] == null
        ? ''
        : tr(
            c,
            'Pause $names: ${formatDay(c, value['from'] as String)} through ${formatDay(c, value['until'] as String)}',
            'Nghỉ $names: ${formatDay(c, value['from'] as String)} đến ${formatDay(c, value['until'] as String)}',
          );
    final status = scope.state.operations.any((x) => x.undoOf == op.id)
        ? tr(c, 'Undone', 'Đã hoàn tác')
        : tr(c, 'Applied', 'Đã áp dụng');
    return '${formatDay(c, value['day'] as String)} · $status\n$effect';
  }

  String describe(BuildContext c, ConvenienceRule r) {
    final routine =
        scope.routine(r.source)?.title ??
        tr(c, 'Removed routine', 'Quy trình đã xóa');
    final habit =
        scope.habit(r.target)?.title ??
        tr(c, 'Removed habit', 'Thói quen đã xóa');
    return r.kind == 'routine'
        ? tr(
            c,
            'When I finish $routine, check in $habit +1',
            'Khi xong $routine, ghi $habit +1',
          )
        : tr(
            c,
            'Pause ${r.source}: ${formatDay(c, r.from!)} through ${formatDay(c, r.until!)}',
            'Nghỉ nhóm ${r.source}: ${formatDay(c, r.from!)} đến ${formatDay(c, r.until!)}',
          );
  }

  Future<void> add(BuildContext c) async {
    if (!scope.pro(c)) {
      await openHabitPro(c, HabitProFeature.convenience);
      return;
    }
    final routines = {
      for (final r in scope.state.liveRoutines.where((r) => !r.archived))
        r.id: r.title,
    };
    final habits = {
      for (final h in scope.state.liveHabits.where(
        (h) => !h.archived && !h.isNegative && h.type == 'count',
      ))
        h.id: h.title,
    };
    final collections = {
      for (final h in scope.state.liveHabits.where(
        (h) => h.category.isNotEmpty && !h.archived,
      ))
        h.category: h.category,
    };
    final routineAvailable = routines.isNotEmpty && habits.isNotEmpty;
    if (!routineAvailable && collections.isEmpty) {
      showHandyMessage(
        c,
        tr(
          c,
          'Add a routine and a count habit, or a collection first.',
          'Hãy thêm quy trình và thói quen đếm, hoặc tạo nhóm trước.',
        ),
      );
      return;
    }
    await showHabitForm(
      c,
      title: tr(c, 'Add a rule', 'Thêm quy tắc'),
      fields: [
        const HabitField('name', 'Rule name', 'Tên quy tắc'),
        HabitField(
          'kind',
          'When',
          'Khi',
          kind: FieldKind.choice,
          options: {
            if (routineAvailable)
              'routine': tr(c, 'A routine finishes', 'Hoàn thành quy trình'),
            if (collections.isNotEmpty)
              'holiday': tr(c, 'During my holiday', 'Trong kỳ nghỉ'),
          },
        ),
        HabitField(
          'routine',
          'Routine',
          'Quy trình',
          kind: FieldKind.choice,
          options: routines,
          when: (v) => v['kind'] == 'routine',
        ),
        HabitField(
          'target',
          'Check in +1',
          'Ghi nhận +1',
          kind: FieldKind.choice,
          options: habits,
          when: (v) => v['kind'] == 'routine',
        ),
        HabitField(
          'collection',
          'Pause collection',
          'Nhóm nghỉ',
          kind: FieldKind.choice,
          options: collections,
          when: (v) => v['kind'] == 'holiday',
        ),
        HabitField(
          'from',
          'First day off',
          'Ngày nghỉ đầu',
          kind: FieldKind.date,
          when: (v) => v['kind'] == 'holiday',
        ),
        HabitField(
          'until',
          'Last day off',
          'Ngày nghỉ cuối',
          kind: FieldKind.date,
          when: (v) => v['kind'] == 'holiday',
        ),
      ],
      initial: {
        'name': '',
        'kind': routineAvailable ? 'routine' : 'holiday',
        'routine': routines.keys.firstOrNull,
        'target': habits.keys.firstOrNull,
        'collection': collections.keys.firstOrNull,
        'from': scope.today,
        'until': scope.today,
      },
      saveLabel: tr(c, 'Enable rule', 'Bật quy tắc'),
      save: (v) async {
        if (!scope.pro(c)) throw StateError('Pro required');
        final r = ConvenienceRule(
          id: uid(),
          name: (v['name'] as String).trim(),
          kind: v['kind'] as String,
          source:
              (v[v['kind'] == 'routine' ? 'routine' : 'collection']) as String,
          target: v['target'] as String? ?? '',
          from: v['from'] as String,
          until: v['until'] as String,
        );
        await scope.controller.change(
          (s) => s.copy({
            'settings': {
              ...s.settings,
              'convenienceRules': [
                ...convenienceRules(s).map((r) => r.toJson()),
                r.toJson(),
              ],
            },
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext c) {
    final rules = convenienceRules(scope.state),
        history = convenienceHistory(scope.state).reversed.toList();
    return HandyPage(
      title: tr(c, 'Local rules', 'Quy tắc cục bộ'),
      children: [
        Text(
          tr(
            c,
            'Only while Habit is open. Each rule runs once per routine session or holiday. No chains.',
            'Chỉ khi mở Habit. Mỗi quy tắc chạy một lần mỗi phiên hoặc kỳ nghỉ. Không chạy dây chuyền.',
          ),
        ),
        if (!scope.pro(c))
          const HabitProBadge(feature: HabitProFeature.convenience),
        FilledButton.icon(
          key: const Key('rule-add'),
          onPressed: () => add(c),
          icon: const Icon(Icons.add),
          label: Text(tr(c, 'Add a rule', 'Thêm quy tắc')),
        ),
        if (rules.isEmpty)
          HandyEmpty(
            title: tr(
              c,
              'No automatic changes yet',
              'Chưa có thay đổi tự động',
            ),
            message: tr(
              c,
              'Choose exactly when and what Habit may change.',
              'Chọn rõ khi nào và Habit được thay đổi gì.',
            ),
          ),
        for (final r in rules)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                key: Key('rule-${r.id}'),
                title: Text(r.name),
                subtitle: Text(describe(c, r)),
                value: r.enabled,
                onChanged: (v) async {
                  if (v && !scope.pro(c)) {
                    await openHabitPro(c, HabitProFeature.convenience);
                    return;
                  }
                  await scope.write(
                    c,
                    (s) => s.copy({
                      'settings': {
                        ...s.settings,
                        'convenienceRules': [
                          for (final row in convenienceRules(s))
                            {...row.toJson(), if (row.id == r.id) 'enabled': v},
                        ],
                      },
                    }),
                  );
                },
              ),
              if (!scope.pro(c) && r.enabled)
                Text(
                  tr(
                    c,
                    'Paused until Pro is available. You can still turn it off.',
                    'Tạm dừng khi chưa có Pro. Bạn vẫn có thể tắt.',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 24),
        Text(
          tr(c, 'Automatic change history', 'Lịch sử thay đổi tự động'),
          style: Theme.of(c).textTheme.titleMedium,
        ),
        if (history.isEmpty)
          Text(
            tr(
              c,
              'Automatic changes will appear here with the rule name.',
              'Thay đổi tự động sẽ hiện ở đây kèm tên quy tắc.',
            ),
          ),
        Capped(
          count: history.length,
          max: 20,
          name: 'rule-history',
          builder: (c, shown) => Column(
            children: [
              for (final (op, name) in history.take(shown))
                ListTile(
                  title: Text(name),
                  subtitle: Text(historyLine(c, op)),
                  trailing: scope.state.operations.any((x) => x.undoOf == op.id)
                      ? null
                      : TextButton(
                          key: Key('rule-undo-${op.id}'),
                          onPressed: () async {
                            try {
                              await scope.controller.change(
                                (s) => undoChange(
                                  s,
                                  op.batch,
                                  actor: scope.controller.actor,
                                ),
                                remember: false,
                                recorded: true,
                              );
                            } catch (_) {
                              if (c.mounted)
                                showHandyMessage(
                                  c,
                                  tr(
                                    c,
                                    'Newer changes prevent this Undo.',
                                    'Thay đổi mới hơn ngăn hoàn tác này.',
                                  ),
                                );
                            }
                          },
                          child: Text(tr(c, 'Undo', 'Hoàn tác')),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
