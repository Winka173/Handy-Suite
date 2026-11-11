import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../habits/habit_appearance.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'share_routine.dart';

/// New routine, the same quick way as a new habit: a name, or one of four
/// starters, opens the editor filled in; All templates opens the gallery.
Future<bool> addRoutine(BuildContext context, HabitScope scope) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _QuickRoutine(),
  );
  if (picked == null || !context.mounted) return false;
  if (picked == 'import') return importSharedRoutine(context, scope);
  if (picked == 'templates')
    return await Navigator.pushNamed<bool>(
          context,
          '/templates?kind=routine',
        ) ==
        true;
  final draft = picked is RoutineTemplateInfo
      ? picked.instantiate(vietnamese: isVi(context))
      : Routine(id: uid(), title: '$picked');
  return await Navigator.pushNamed<String>(
        context,
        '/routine/new',
        arguments: draft,
      ) !=
      null;
}

class _QuickRoutine extends StatefulWidget {
  const _QuickRoutine();
  @override
  State<_QuickRoutine> createState() => _QuickRoutineState();
}

class _QuickRoutineState extends State<_QuickRoutine> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _named() {
    final title = name.text.trim();
    if (title.isNotEmpty) Navigator.pop(context, title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final vi = isVi(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('quick-routine'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'New routine', 'Quy trình mới'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.anchor,
              ),
            ),
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            key: const Key('quick-routine-name'),
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _named(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr(
                context,
                'A few steps in order: Morning, Wind down…',
                'Vài bước theo thứ tự: Buổi sáng, Trước khi ngủ…',
              ),
              suffixIcon: name.text.trim().isEmpty
                  ? null
                  : IconButton(
                      key: const Key('quick-routine-next'),
                      tooltip: tr(context, 'Next', 'Tiếp'),
                      onPressed: _named,
                      icon: Icon(Icons.arrow_forward, color: p.vermilion),
                    ),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          Text(
            tr(context, 'Or start from one of these', 'Hoặc bắt đầu từ'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: HandySpace.s),
          for (final t in routineTemplateCatalog.take(4))
            ListTile(
              key: Key('quick-routine-${t.id}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(habitIcon(t.icon), color: p.vermilion),
              title: Text(vi ? t.vi : t.en),
              subtitle: Text(
                tr(
                  context,
                  '${t.steps.length} steps · ${(t.seconds / 60).round()} min',
                  '${t.steps.length} bước · ${(t.seconds / 60).round()} phút',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, t),
            ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: const Key('quick-routine-import'),
                onPressed: () => Navigator.pop(context, 'import'),
                icon: const Icon(Icons.file_open_outlined, size: 18),
                label: Text(
                  tr(
                    context,
                    'Import a shared routine',
                    'Nhập quy trình được chia sẻ',
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('quick-routine-templates'),
              onPressed: () => Navigator.pop(context, 'templates'),
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(
                tr(
                  context,
                  'All ${routineTemplateCatalog.length} routines',
                  'Cả ${routineTemplateCatalog.length} quy trình mẫu',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
