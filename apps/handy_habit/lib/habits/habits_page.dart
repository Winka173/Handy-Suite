import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../today/rows.dart';
import 'habit_editor.dart';
import 'habit_view.dart';

/// Every habit, by group, with today's bead on each. A wide screen opens
/// the chosen one beside the list.
class HabitsPage extends StatefulWidget {
  final HabitScope scope;
  const HabitsPage({super.key, required this.scope});
  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  HabitScope get scope => widget.scope;
  String search = '', order = 'manual';
  bool archived = false;
  String? selected;

  List<Habit> get shown {
    final q = foldAccents(search.trim());
    final list = scope.state.habits
        .where(
          (h) =>
              h.archived == archived &&
              foldAccents('${h.title} ${h.note} ${h.category}').contains(q),
        )
        .toList();
    switch (order) {
      case 'title':
        list.sort(
          (a, b) => foldAccents(a.title).compareTo(foldAccents(b.title)),
        );
      case 'priority':
        list.sort((a, b) => b.priority.compareTo(a.priority));
      case 'created':
        list.sort((a, b) => b.created.compareTo(a.created));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 1000;
      final habits = shown;
      final index = scope.index;
      final open = wide ? scope.habit(selected) ?? habits.firstOrNull : null;
      final groups = <String, List<Habit>>{};
      for (final h in habits) {
        groups.putIfAbsent(h.category, () => []).add(h);
      }
      final names = groups.keys.toList()
        ..sort((a, b) => a.isEmpty ? 1 : (b.isEmpty ? -1 : a.compareTo(b)));
      final list = ListView(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.l,
          HandySpace.l,
          HandySpace.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    tr(context, 'Habits', 'Thói quen'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('habit-new'),
                onPressed: () => openHabitEditor(context, scope),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'New', 'Thêm')),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            key: const Key('habit-search'),
            decoration: InputDecoration(
              hintText: tr(context, 'Find a habit', 'Tìm thói quen'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) => setState(() => search = v),
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const Key('habit-archived'),
                label: Text(tr(context, 'Archived', 'Đã lưu trữ')),
                selected: archived,
                onSelected: (v) => setState(() => archived = v),
              ),
              PopupMenuButton<String>(
                key: const Key('habit-order'),
                tooltip: tr(context, 'Order', 'Sắp xếp'),
                initialValue: order,
                onSelected: (v) => setState(() => order = v),
                itemBuilder: (context) => [
                  for (final (k, en, vi) in const [
                    ('manual', 'Your order', 'Thứ tự của bạn'),
                    ('title', 'By name', 'Theo tên'),
                    ('priority', 'By priority', 'Theo ưu tiên'),
                    ('created', 'Newest first', 'Mới nhất trước'),
                  ])
                    PopupMenuItem(value: k, child: Text(tr(context, en, vi))),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 16),
                  label: Text(switch (order) {
                    'title' => tr(context, 'By name', 'Theo tên'),
                    'priority' => tr(context, 'By priority', 'Theo ưu tiên'),
                    'created' => tr(context, 'Newest first', 'Mới nhất trước'),
                    _ => tr(context, 'Your order', 'Thứ tự của bạn'),
                  }),
                ),
              ),
            ],
          ),
          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.xl),
              child: HandyEmpty(
                title: search.isNotEmpty
                    ? tr(context, 'No habit matches', 'Không có thói quen khớp')
                    : archived
                    ? tr(context, 'Nothing archived', 'Chưa lưu trữ gì')
                    : tr(context, 'No habits yet', 'Chưa có thói quen'),
              ),
            ),
          for (final name in names)
            HandySection(
              title: name.isEmpty
                  ? (names.length == 1
                        ? null
                        : tr(context, 'No group', 'Không nhóm'))
                  : name,
              children: [
                for (final h in groups[name]!)
                  HabitRow(
                    scope: scope,
                    habit: h,
                    index: index,
                    selected: open?.id == h.id,
                    onOpen: () => wide
                        ? setState(() => selected = h.id)
                        : Navigator.pushNamed(context, '/habit/${h.id}'),
                  ),
              ],
            ),
        ],
      );
      if (open == null) return list;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 460, child: list),
          const VerticalDivider(width: 1),
          Expanded(
            child: HabitView(key: ValueKey(open.id), scope: scope, habit: open),
          ),
        ],
      );
    },
  );
}
