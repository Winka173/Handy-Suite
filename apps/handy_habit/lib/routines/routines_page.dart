import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../today/rows.dart';
import '../ui/words.dart';
import 'routine_editor.dart';
import 'routine_view.dart';

/// Every routine with Start, ready-made ones to begin from, and the runs
/// of the last days. A wide screen opens the chosen one beside the list.
class RoutinesPage extends StatefulWidget {
  final HabitScope scope;
  const RoutinesPage({super.key, required this.scope});
  @override
  State<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends State<RoutinesPage> {
  HabitScope get scope => widget.scope;
  String? selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 1000;
      final s = scope.state;
      final routines = [...s.routines]
        ..sort(
          (a, b) => a.archived == b.archived
              ? a.time.compareTo(b.time)
              : (a.archived ? 1 : -1),
        );
      final open = wide
          ? scope.routine(selected) ?? routines.firstOrNull
          : null;
      final vi = isVi(context);
      final taken = {for (final r in s.routines) r.title};
      final templates = routineTemplates(
        vietnamese: vi,
      ).where((t) => !taken.contains(t.title)).toList();
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
                    tr(context, 'Routines', 'Quy trình'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              FilledButton.icon(
                key: const Key('routine-new'),
                onPressed: () async {
                  final id = await openRoutineEditor(context, scope);
                  if (id != null && context.mounted) {
                    wide
                        ? setState(() => selected = id)
                        : Navigator.pushNamed(context, '/routine/$id');
                  }
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'New', 'Thêm')),
              ),
            ],
          ),
          if (routines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: Text(
                tr(
                  context,
                  'A routine is a few steps in order, each with its own time. Start from one below, or make your own.',
                  'Quy trình là vài bước theo thứ tự, mỗi bước có thời gian riêng. Bắt đầu từ một mẫu dưới đây, hoặc tự tạo.',
                ),
              ),
            ),
          if (routines.isNotEmpty)
            HandySection(
              children: [
                for (final r in routines)
                  RoutineRow(
                    scope: scope,
                    routine: r,
                    selected: open?.id == r.id,
                    onOpen: () => wide
                        ? setState(() => selected = r.id)
                        : Navigator.pushNamed(context, '/routine/${r.id}'),
                  ),
              ],
            ),
          if (templates.isNotEmpty)
            HandySection(
              title: tr(context, 'Start from one of these', 'Bắt đầu từ mẫu'),
              children: [
                for (final t in templates)
                  ListTile(
                    key: Key('template-${t.title}'),
                    title: Text(t.title),
                    subtitle: Text(t.steps.map((x) => x.title).join(' · ')),
                    trailing: TextButton(
                      onPressed: () => scope.write(
                        context,
                        (s) => s.copy({
                          'routines': [
                            ...s.routines.map((x) => x.toJson()),
                            t.toJson(),
                          ],
                        }),
                        done: (c) => tr(
                          c,
                          '${t.title} added; change it as you like.',
                          'Đã thêm ${t.title}; sửa tùy ý.',
                        ),
                      ),
                      child: Text(tr(context, 'Use', 'Dùng')),
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
            child: RoutineView(
              key: ValueKey(open.id),
              scope: scope,
              routine: open,
            ),
          ),
        ],
      );
    },
  );
}
