import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'routine_editor.dart';
import 'run.dart';
import '../habits/habit_appearance.dart';

/// A routine on a page of its own (phones and web links).
class RoutinePage extends StatelessWidget {
  final HabitScope scope;
  final String id;
  const RoutinePage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final r = scope.routine(id);
      return Scaffold(
        appBar: AppBar(
          title: Text(r?.title ?? ''),
          actions: [if (r != null) RoutineMenu(scope: scope, routine: r)],
        ),
        body: r == null
            ? Center(
                child: HandyEmpty(
                  title: tr(
                    context,
                    'This routine is gone; its runs are kept.',
                    'Quy trình này không còn; các phiên vẫn giữ.',
                  ),
                ),
              )
            : RoutineView(scope: scope, routine: r, showTitle: false),
      );
    },
  );
}

/// The steps in order as one strip of minutes, then each step to edit,
/// move or remove; Start and the quick version at the top.
class RoutineView extends StatelessWidget {
  final HabitScope scope;
  final Routine routine;
  final bool showTitle;
  const RoutineView({
    super.key,
    required this.scope,
    required this.routine,
    this.showTitle = true,
  });

  Future<void> move(BuildContext context, int from, int to) =>
      scope.write(context, (s) {
        final latest = s.routines.firstWhere((v) => v.id == routine.id);
        final steps = latest.steps.toList();
        steps.insert(to.clamp(0, steps.length - 1), steps.removeAt(from));
        return replaceRoutine(
          s,
          latest.copy({
            'steps': [for (final x in steps) x.toJson()],
          }),
        );
      });

  Future<void> remove(BuildContext context, RoutineStep step) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Remove ${step.title}?', 'Bỏ bước ${step.title}?'),
      message: tr(
        context,
        'Past runs keep it.',
        'Các phiên đã chạy vẫn giữ bước này.',
      ),
      confirmLabel: tr(context, 'Remove', 'Bỏ'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.write(context, (s) {
      final latest = s.routines.firstWhere((v) => v.id == routine.id);
      return replaceRoutine(
        s,
        latest.copy({
          'steps': [
            for (final x in latest.steps)
              if (x.id != step.id) x.toJson(),
          ],
        }),
      );
    }, done: (c) => tr(c, 'Step removed.', 'Đã bỏ bước.'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = routine;
    final runs = scope.state.sessions
        .where((s) => s.routine == r.id)
        .toList()
        .reversed
        .take(8)
        .toList();
    final ready = !r.archived && r.steps.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [
        Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: HandySpace.content),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showTitle)
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            r.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                      RoutineMenu(scope: scope, routine: r),
                    ],
                  ),
                Text(
                  [
                    if (r.weekdays.isNotEmpty)
                      '${weekdaysText(context, r.weekdays)}, ${r.time}'
                    else
                      weekdaysText(context, r.weekdays),
                    minutesText(context, r.planned),
                    tr(
                      context,
                      '${r.steps.length} steps',
                      '${r.steps.length} bước',
                    ),
                    if (r.archived) tr(context, 'archived', 'đã lưu trữ'),
                  ].join(' · '),
                  style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
                ),
                if (r.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: HandySpace.s),
                    child: Text(r.note),
                  ),
                const SizedBox(height: HandySpace.l),
                DurationStrip(steps: r.steps, color: c.accent),
                const SizedBox(height: HandySpace.l),
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    FilledButton.icon(
                      key: const Key('routine-start'),
                      onPressed: ready
                          ? () => startRoutine(context, scope, r)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(tr(context, 'Start', 'Bắt đầu')),
                    ),
                  ],
                ),
                HandyLabel(
                  tr(context, 'Steps', 'Các bước'),
                  trailing: TextButton.icon(
                    key: const Key('step-add'),
                    onPressed: () => openStepEditor(context, scope, r),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr(context, 'Add step', 'Thêm bước')),
                  ),
                ),
                if (r.steps.isEmpty)
                  HandyNotice(
                    tr(
                      context,
                      'Add the first step to start this routine.',
                      'Thêm bước đầu tiên để bắt đầu quy trình.',
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: r.steps.length,
                      onReorderItem: (from, to) => move(context, from, to),
                      itemBuilder: (context, i) => _StepRow(
                        key: ValueKey(r.steps[i].id),
                        scope: scope,
                        routine: r,
                        index: i,
                        onMove: (to) => move(context, i, to),
                        onRemove: () => remove(context, r.steps[i]),
                      ),
                    ),
                  ),
                if (runs.isNotEmpty)
                  HandySection(
                    title: tr(context, 'Recent runs', 'Các lần chạy gần đây'),
                    children: [
                      for (final s in runs)
                        ListTile(
                          key: Key('run-${s.id}'),
                          title: Text(formatDay(context, s.day)),
                          subtitle: Text(statusLabel(context, s.status)),
                          trailing: Text(
                            '${clockText(s.elapsed)} / ${clockText(s.planned)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFeatures: tabular,
                            ),
                          ),
                          onTap: () => s.status == 'active'
                              ? openSession(context, scope, s.id)
                              : Navigator.pushNamed(
                                  context,
                                  '/session/${s.id}',
                                ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final HabitScope scope;
  final Routine routine;
  final int index;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  const _StepRow({
    super.key,
    required this.scope,
    required this.routine,
    required this.index,
    required this.onMove,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final step = routine.steps[index];
    final h = scope.habit(step.habit);
    final meta = [
      minutesText(context, step.seconds),
      if (step.seconds > 0 && step.minimum < step.seconds)
        tr(
          context,
          'at least ${minutesText(context, step.minimum)}',
          'tối thiểu ${minutesText(context, step.minimum)}',
        ),
      if (!step.required) tr(context, 'may be left out', 'có thể bỏ khi gấp'),
      if (h != null)
        tr(context, 'counts for ${h.title}', 'tính cho ${h.title}'),
    ].join(' · ');
    return InkWell(
      key: Key('step-${step.id}'),
      onTap: () => openStepEditor(context, scope, routine, step),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HandySpace.s, 8, 0, 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(HandySpace.s),
                child: Icon(
                  Icons.drag_indicator,
                  color: c.muted,
                  semanticLabel: tr(
                    context,
                    'Drag to reorder',
                    'Kéo để đổi thứ tự',
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: theme.textTheme.bodyLarge),
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.arrow_upward,
                  tr(context, 'Move up', 'Lên trên'),
                  index == 0 ? null : () => onMove(index - 1),
                ),
                HandyMenuItem(
                  Icons.arrow_downward,
                  tr(context, 'Move down', 'Xuống dưới'),
                  index == routine.steps.length - 1
                      ? null
                      : () => onMove(index + 1),
                ),
                HandyMenuItem(
                  Icons.delete_outline,
                  tr(context, 'Remove step', 'Bỏ bước'),
                  onRemove,
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Edit, archive, duplicate, delete.
class RoutineMenu extends StatelessWidget {
  final HabitScope scope;
  final Routine routine;
  const RoutineMenu({super.key, required this.scope, required this.routine});

  Future<void> _delete(BuildContext context) async {
    final r = routine;
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${r.title}?', 'Xóa ${r.title}?'),
      message: tr(
        context,
        'It stays in Trash for 30 days. Past runs stay in history.',
        'Giữ trong Thùng rác 30 ngày. Các phiên đã chạy vẫn giữ trong lịch sử.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final done = await scope.write(
      context,
      (s) => trashEntity(s, 'routine', r.id, scope.clock()),
      done: (c) => tr(
        c,
        '${r.title} moved to Trash.',
        'Đã chuyển ${r.title} vào Thùng rác.',
      ),
    );
    if (done && navigator.canPop()) navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final r = routine;
    return HandyMenuButton(
      items: [
        HandyMenuItem(
          Icons.palette_outlined,
          tr(context, 'Appearance', 'Diện mạo'),
          () async {
            final chosen = await pickHabitAppearance(
              context,
              title: r.title,
              initialIcon: r.icon,
              initialColor: r.color,
            );
            if (chosen == null ||
                !context.mounted ||
                (chosen.icon == r.icon && chosen.color == r.color))
              return;
            await scope.write(context, (s) {
              final latest = s.routines.where((v) => v.id == r.id).firstOrNull;
              if (!identical(latest, r))
                throw StateError('Routine changed; reopen its appearance');
              return replaceRoutine(
                s,
                r.copy({'icon': chosen.icon, 'color': chosen.color}),
              );
            }, done: (ctx) => tr(ctx, 'Appearance saved.', 'Đã lưu diện mạo.'));
          },
          key: const Key('routine-appearance'),
        ),
        HandyMenuItem(
          Icons.edit_outlined,
          tr(context, 'Edit', 'Sửa'),
          () => openRoutineEditor(context, scope, r),
          key: const Key('routine-edit'),
        ),
        HandyMenuItem(
          r.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          r.archived
              ? tr(context, 'Bring back', 'Dùng lại')
              : tr(context, 'Archive', 'Lưu trữ'),
          () => scope.write(
            context,
            (s) => replaceRoutine(s, r.copy({'archived': !r.archived})),
          ),
        ),
        HandyMenuItem(
          Icons.copy_outlined,
          tr(context, 'Duplicate', 'Nhân bản'),
          () => scope.write(
            context,
            (s) => s.copy({
              'routines': [
                ...s.routines.map((x) => x.toJson()),
                r.copy({
                  'id': uid(),
                  'title': tr(
                    context,
                    '${r.title} (copy)',
                    '${r.title} (bản sao)',
                  ),
                  'archived': false,
                  'steps': [
                    for (final st in r.steps) st.copy({'id': uid()}).toJson(),
                  ],
                }).toJson(),
              ],
            }),
            done: (c) => tr(c, 'Duplicated.', 'Đã nhân bản.'),
          ),
        ),
        HandyMenuItem(
          Icons.delete_outline,
          tr(context, 'Delete', 'Xóa'),
          () => _delete(context),
          destructive: true,
          key: const Key('routine-delete'),
        ),
      ],
    );
  }
}
