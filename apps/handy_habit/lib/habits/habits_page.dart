import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'dart:async';
import '../convenience/saved_filters.dart';
import 'preset_sheet.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../today/rows.dart';
import '../ui/capped.dart';
import 'habit_view.dart';

/// Every habit, by group, with today's bead on each. A wide screen opens
/// the chosen one beside the list.
class HabitsPage extends StatefulWidget {
  final HabitScope scope;
  final bool autofocus;
  const HabitsPage({super.key, required this.scope, this.autofocus = false});
  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  HabitScope get scope => widget.scope;
  String search = '', order = 'manual';
  final searchController = TextEditingController();
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  bool archived = false;
  String? selected;

  List<Habit> get shown {
    final q = foldAccents(search.trim());
    final list = scope.state.liveHabits
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
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          HandySpace.l,
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
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
                onPressed: () => addHabit(context, scope),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'New', 'Thêm')),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            controller: searchController,
            autofocus: widget.autofocus,
            key: const Key('habit-search'),
            decoration: InputDecoration(
              hintText: tr(context, 'Find a habit', 'Tìm thói quen'),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
            ),
            onChanged: (v) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 180),
                () => setState(() => search = v),
              );
            },
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
              IconButton(
                key: const Key('habits-batch'),
                tooltip: tr(context, 'Batch changes', 'Thay đổi hàng loạt'),
                onPressed: () => Navigator.pushNamed(context, '/habits/batch'),
                icon: const Icon(Icons.checklist),
              ),
            ],
          ),
          // Only a view that differs from the plain list can be saved;
          // saved ones always show.
          if (search.isNotEmpty ||
              archived ||
              order != 'manual' ||
              objects(
                scope.state.settings['savedFilters'] ?? [],
              ).any((f) => f['area'] == 'habits'))
            SavedFilters(
              scope: scope,
              area: 'habits',
              values: {
                'search': searchController.text,
                'archived': archived,
                'order': order,
              },
              onApply: (v) => setState(() {
                debounce?.cancel();
                search = v['search'] as String? ?? '';
                searchController.text = search;
                archived = v['archived'] == true;
                order = v['order'] as String? ?? 'manual';
              }),
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
                Capped(
                  count: groups[name]!.length,
                  max: 6,
                  name: 'habits-$name',
                  open:
                      selected != null &&
                      groups[name]!.any((h) => h.id == selected),
                  builder: (context, shown) => Column(
                    children: [
                      for (final h in groups[name]!.take(shown))
                        HabitRow(
                          key: ValueKey(h.id),
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
