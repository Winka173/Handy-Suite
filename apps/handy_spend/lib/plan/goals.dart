import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';

/// Money set aside for something; Free to spend leaves it alone.
class GoalsSection extends StatelessWidget {
  final SpendScope scope;
  const GoalsSection({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final goals = scope.state.goals;
    return HandySection(
      title: tr(context, 'Set aside', 'Để dành'),
      trailing: TextButton.icon(
        key: const Key('goal-add'),
        onPressed: () => openGoalEditor(context, scope),
        icon: const Icon(Icons.add, size: 18),
        label: Text(tr(context, 'Add', 'Thêm')),
      ),
      children: [
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'Put money aside for a trip or a repair; it is kept out of Free to spend.',
                'Để riêng tiền cho chuyến đi hay sửa xe; phần này không tính vào Có thể chi.',
              ),
            ),
          ),
        for (final g in goals) _GoalRow(scope: scope, goal: g),
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  final SpendScope scope;
  final Goal goal;
  const _GoalRow({required this.scope, required this.goal});

  Future<void> release(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Stop setting aside for ${goal.name}?',
        'Thôi để dành cho ${goal.name}?',
      ),
      message: tr(
        context,
        'The money goes back to Free to spend. No entry is deleted.',
        'Số tiền quay về Có thể chi. Không xóa giao dịch nào.',
      ),
      confirmLabel: tr(context, 'Stop', 'Thôi để dành'),
    );
    if (!ok || !context.mounted) return;
    await scope.write(
      context,
      () => scope.controller.change(
        (s) => s.copy({
          'goals': [
            for (final x in s.goals)
              if (x.id != goal.id) x.toJson(),
          ],
        }),
        'delete_goal',
      ),
      done: (c) =>
          tr(c, '${goal.name} released.', 'Đã thôi để dành ${goal.name}.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final g = goal;
    final cur = scope.account(g.account).currency;
    final ratio = g.target <= BigInt.zero
        ? 0.0
        : (g.reserved.toDouble() / g.target.toDouble()).clamp(0.0, 1.0);
    return InkWell(
      key: Key('goal-${g.id}'),
      onTap: () => openGoalEditor(context, scope, g),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HandySpace.l, 10, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(g.name),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          Container(color: c.raised),
                          FractionallySizedBox(
                            widthFactor: ratio,
                            child: Container(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      context,
                      '${moneyText(context, scope, g.reserved, cur)} of ${moneyText(context, scope, g.target, cur)} · by ${dayLabel(context, scope, g.due)} · ${scope.account(g.account).name}',
                      '${moneyText(context, scope, g.reserved, cur)} / ${moneyText(context, scope, g.target, cur)} · trước ${dayLabel(context, scope, g.due)} · ${scope.account(g.account).name}',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.edit_outlined,
                  tr(context, 'Edit', 'Sửa'),
                  () => openGoalEditor(context, scope, g),
                ),
                HandyMenuItem(
                  Icons.remove_circle_outline,
                  tr(context, 'Stop setting aside', 'Thôi để dành'),
                  () => release(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> openGoalEditor(BuildContext context, SpendScope scope, [Goal? g]) {
  if (scope.openAccounts.isEmpty) return Future.value(false);
  return showSpendForm(
    context,
    scope,
    title: g == null ? tr(context, 'Set money aside', 'Để dành tiền') : g.name,
    fields: [
      const SpendField(
        'name',
        'For',
        'Để dành cho',
        helpEn: 'A trip, a new phone, the car insurance.',
        helpVi: 'Chuyến đi, điện thoại mới, bảo hiểm xe.',
      ),
      SpendField(
        'account',
        'Kept in',
        'Giữ trong',
        kind: FieldKind.choice,
        options: {for (final a in scope.openAccounts) a.id: a.name},
      ),
      SpendField(
        'target',
        'Goal',
        'Mục tiêu',
        kind: FieldKind.money,
        currency: (v) => scope.account(v['account'] as String).currency,
      ),
      SpendField(
        'reserved',
        'Set aside so far',
        'Đã để dành',
        kind: FieldKind.money,
        currency: (v) => scope.account(v['account'] as String).currency,
        helpEn: 'Already in the account; this records no new entry.',
        helpVi: 'Tiền đã có trong tài khoản; không ghi thêm giao dịch.',
      ),
      const SpendField('due', 'By', 'Trước ngày', kind: FieldKind.date),
    ],
    initial: {
      'name': g?.name ?? '',
      'account': g?.account ?? scope.openAccounts.first.id,
      'target': g?.target,
      'reserved': g?.reserved ?? BigInt.zero,
      'due': g?.due ?? scope.end,
    },
    save: (v) async {
      final next = Goal(
        id: g?.id ?? newId(),
        name: v['name'] as String,
        account: v['account'] as String,
        due: v['due'] as String,
        target: v['target'] as BigInt,
        reserved: v['reserved'] as BigInt,
      );
      await scope.controller.change(
        (s) => s.copy({
          'goals': [
            for (final x in s.goals)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_goal',
      );
    },
  );
}
