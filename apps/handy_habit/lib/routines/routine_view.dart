import '../ui/row_menu.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'routine_editor.dart';
import 'run.dart';
import '../habits/habit_appearance.dart';
import '../ui/capped.dart';

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

/// A saved plan and its recent sessions; Edit opens the whole draft.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = routine;
    final runs = scope.state.sessions.where((s) => s.routine == r.id).toList()
      ..sort((a, b) => b.started.compareTo(a.started));
    final ready = !r.archived && r.steps.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(HandySpace.l),
      children: [
        Align(
          alignment: AlignmentDirectional.topCenter,
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
                      '${r.steps.length} ${r.steps.length == 1 ? 'step' : 'steps'}',
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
                      label: Text(
                        scope.activeSession?.routine == r.id
                            ? tr(context, 'Resume', 'Tiếp tục')
                            : tr(context, 'Start', 'Bắt đầu'),
                      ),
                    ),
                  ],
                ),
                LayoutBuilder(
                  builder: (context, box) {
                    final edit = TextButton.icon(
                      key: const Key('routine-edit-steps'),
                      onPressed: () => openRoutineEditor(context, scope, r),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(tr(context, 'Edit steps', 'Sửa các bước')),
                    );
                    final label = tr(context, 'Steps', 'Các bước');
                    return box.maxWidth /
                                MediaQuery.textScalerOf(context).scale(1) <
                            320
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HandyLabel(label),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: edit,
                              ),
                            ],
                          )
                        : HandyLabel(label, trailing: edit);
                  },
                ),
                if (r.steps.isEmpty)
                  HandyNotice(
                    tr(
                      context,
                      'Edit this routine to add its first step.',
                      'Sửa quy trình để thêm bước đầu tiên.',
                    ),
                  )
                else
                  Capped(
                    count: r.steps.length,
                    max: 6,
                    name: 'routine-steps',
                    builder: (context, shown) => Column(
                      children: [
                        for (final step in r.steps.take(shown))
                          ListTile(
                            title: Text(step.title),
                            subtitle: Text(
                              [
                                minutesText(context, step.seconds),
                                if (scope.habit(step.habit) case final h?)
                                  tr(
                                    context,
                                    'Counts for ${h.title}',
                                    'Tính cho ${h.title}',
                                  ),
                                if (!step.canSkip)
                                  tr(
                                    context,
                                    'Cannot skip',
                                    'Không thể bỏ qua',
                                  ),
                                if (step.note.isNotEmpty) step.note,
                              ].join(' · '),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (runs.isNotEmpty)
                  HandySection(
                    title: tr(context, 'Recent runs', 'Các lần chạy gần đây'),
                    children: [
                      Capped(
                        count: runs.length,
                        max: 4,
                        name: 'routine-runs',
                        builder: (context, shown) => Column(
                          children: [
                            for (final s in runs.take(shown))
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
    final route = ModalRoute.of(context);
    final done = await scope.write(
      context,
      (s) => trashEntity(s, 'routine', r.id, scope.clock()),
      done: (c) => tr(
        c,
        '${r.title} moved to Trash.',
        'Đã chuyển ${r.title} vào Thùng rác.',
      ),
    );
    if (done &&
        route?.settings.name == '/routine/${routine.id}' &&
        route?.isCurrent == true &&
        navigator.mounted &&
        navigator.canPop())
      navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) => HabitMenuButton(
    items: items(context),
    tooltip: tr(
      context,
      'More for ${routine.title}',
      'Thêm cho ${routine.title}',
    ),
  );

  List<HandyMenuItem> items(BuildContext context) {
    final r = routine;
    return [
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
        () => scope.write(context, (s) {
          if (r.advanced && !scope.pro(context)) {
            throw const FormatException(
              'Pro is needed to create advanced routines / Cần Pro để tạo quy trình nâng cao',
            );
          }
          return s.copy({
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
                  if (r.steps.isNotEmpty)
                    ...StepBlock(id: 'copy', title: r.title, steps: r.steps)
                        .insert(instance: uid(), markBlock: false)
                        .map((s) => s.toJson()),
                ],
              }).toJson(),
            ],
          });
        }, done: (c) => tr(c, 'Duplicated.', 'Đã nhân bản.')),
      ),
      HandyMenuItem(
        Icons.delete_outline,
        tr(context, 'Delete', 'Xóa'),
        () => _delete(context),
        destructive: true,
        key: const Key('routine-delete'),
      ),
    ];
  }
}
