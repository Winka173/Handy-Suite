import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/habit_appearance.dart';
import '../scope.dart';
import '../ui/words.dart';
import '../today/rows.dart';
import '../ui/capped.dart';
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
      final wide = size.maxWidth >= 1100;
      final s = scope.state;
      final routines = [...s.liveRoutines]
        ..sort(
          (a, b) => a.archived == b.archived
              ? a.time.compareTo(b.time)
              : (a.archived ? 1 : -1),
        );
      final open = wide
          ? scope.routine(selected) ?? routines.firstOrNull
          : null;
      final list = ListView(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          HandySpace.l,
          MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          104,
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
          // The starters the sentence above points to: open one to preview
          // and customise it before anything is saved.
          if (routines.isEmpty)
            HandySection(
              children: [
                for (final t in routineTemplateCatalog.take(4))
                  ListTile(
                    key: Key('routine-starter-${t.id}'),
                    leading: Icon(habitIcon(t.icon)),
                    title: Text(isVi(context) ? t.vi : t.en),
                    subtitle: Text(
                      tr(
                        context,
                        '${t.steps.length} steps · ${(t.seconds / 60).round()} min',
                        '${t.steps.length} bước · ${(t.seconds / 60).round()} phút',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pushNamed(context, '/templates/${t.id}'),
                  ),
              ],
            ),
          if (routines.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('routine-starters-all'),
                onPressed: () =>
                    Navigator.pushNamed(context, '/templates?kind=routine'),
                child: Text(
                  tr(
                    context,
                    'See all ${routineTemplateCatalog.length} routines',
                    'Xem cả ${routineTemplateCatalog.length} quy trình mẫu',
                  ),
                ),
              ),
            ),
          if (routines.isNotEmpty)
            HandySection(
              children: [
                Capped(
                  count: routines.length,
                  max: 4,
                  name: 'routines',
                  open:
                      selected != null && routines.any((r) => r.id == selected),
                  builder: (context, shown) => Column(
                    children: [
                      for (final r in routines.take(shown))
                        RoutineRow(
                          key: ValueKey(r.id),
                          scope: scope,
                          routine: r,
                          selected: open?.id == r.id,
                          onOpen: () => wide
                              ? setState(() => selected = r.id)
                              : Navigator.pushNamed(
                                  context,
                                  '/routine/${r.id}',
                                ),
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
