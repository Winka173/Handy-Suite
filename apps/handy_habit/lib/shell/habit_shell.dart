import 'package:flutter/services.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/habit_editor.dart';
import '../habits/habits_page.dart';
import '../insights/insights_page.dart';
import '../pauses/pauses.dart';
import '../routines/routine_editor.dart';
import '../routines/routines_page.dart';
import '../scope.dart';
import '../today/today_page.dart';
import '../ui/words.dart';

/// The four areas: a bottom bar on phones, a switch in the top bar on wide
/// screens; Add (Ctrl N) is always in the top bar.
class HabitShell extends StatefulWidget {
  final HabitScope scope;
  const HabitShell({super.key, required this.scope});
  @override
  State<HabitShell> createState() => _HabitShellState();
}

class _HabitShellState extends State<HabitShell> {
  HabitScope get scope => widget.scope;

  @override
  void initState() {
    super.initState();
    scope.area.addListener(_changed);
  }

  @override
  void dispose() {
    scope.area.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> addRoutine() async {
    final id = await openRoutineEditor(context, scope);
    if (id != null && mounted)
      await Navigator.pushNamed(context, '/routine/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (scope.state.settings['onboarded'] != true)
      return Onboarding(scope: scope);
    final wide = MediaQuery.sizeOf(context).width >= HandySpace.wide;
    final area = scope.area.value;
    final areas = [
      (Icons.today_outlined, Icons.today, tr(context, 'Today', 'Hôm nay')),
      (
        Icons.check_circle_outline,
        Icons.check_circle,
        tr(context, 'Habits', 'Thói quen'),
      ),
      (
        Icons.format_list_numbered,
        Icons.format_list_numbered,
        tr(context, 'Routines', 'Quy trình'),
      ),
      (
        Icons.insights_outlined,
        Icons.insights,
        tr(context, 'Insights', 'Thống kê'),
      ),
    ];
    final scaffold = Scaffold(
      appBar: HandyTopBar(
        mark: Icons.check_circle,
        name: 'Handy Habit',
        nameIsTitle: false,
        areas: wide
            ? SegmentedButton<int>(
                key: const Key('habit-areas'),
                showSelectedIcon: false,
                segments: [
                  for (final (i, a) in areas.indexed)
                    ButtonSegment(
                      value: i,
                      label: Text(a.$3, key: Key('area-$i')),
                    ),
                ],
                selected: {area},
                onSelectionChanged: (v) => scope.area.value = v.single,
              )
            : null,
        actions: [
          PopupMenuButton<String>(
            key: const Key('habit-add'),
            tooltip: tr(context, 'Add', 'Thêm'),
            position: PopupMenuPosition.under,
            onSelected: (v) => switch (v) {
              'habit' => openHabitEditor(context, scope),
              'pause' => openPauseEditor(context, scope),
              _ => addRoutine(),
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('add-habit'),
                value: 'habit',
                child: Text(tr(context, 'New habit', 'Thói quen mới')),
              ),
              PopupMenuItem(
                key: const Key('add-routine'),
                value: 'routine',
                child: Text(tr(context, 'New routine', 'Quy trình mới')),
              ),
              PopupMenuItem(
                key: const Key('add-pause'),
                value: 'pause',
                child: Text(tr(context, 'Pause', 'Kỳ nghỉ')),
              ),
            ],
            // A 48px target on phones; a labelled chip on wide screens.
            child: wide
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HandySpace.s,
                    ),
                    child: Chip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(tr(context, 'Add', 'Thêm')),
                    ),
                  )
                : const SizedBox.square(dimension: 48, child: Icon(Icons.add)),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: area,
          children: [
            TodayPage(scope: scope),
            HabitsPage(scope: scope),
            RoutinesPage(scope: scope),
            InsightsPage(scope: scope),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              key: const Key('habit-nav'),
              selectedIndex: area,
              onDestinationSelected: (i) => scope.area.value = i,
              destinations: [
                for (final (i, a) in areas.indexed)
                  NavigationDestination(
                    key: Key('nav-$i'),
                    icon: Icon(a.$1),
                    selectedIcon: Icon(a.$2),
                    label: a.$3,
                  ),
              ],
            ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            openHabitEditor(context, scope),
        for (var i = 0; i < 4; i++)
          SingleActivator(
            [
              LogicalKeyboardKey.digit1,
              LogicalKeyboardKey.digit2,
              LogicalKeyboardKey.digit3,
              LogicalKeyboardKey.digit4,
            ][i],
            control: true,
          ): () =>
              scope.area.value = i,
      },
      child: Focus(autofocus: true, child: scaffold),
    );
  }
}

/// The first open: one small habit to start, ready-made examples, or a
/// blank day. Nothing else, and no ads, until a choice is made.
class Onboarding extends StatelessWidget {
  final HabitScope scope;
  const Onboarding({super.key, required this.scope});

  Future<bool> _start(BuildContext context, {bool examples = false}) {
    final today = scope.today, vi = isVi(context);
    final read = tr(context, 'Read', 'Đọc sách'),
        pages = tr(context, 'pages', 'trang');
    return scope.write(
      context,
      (s) => s.copy({
        if (examples) ...{
          'habits': [
            ...s.habits.map((e) => e.toJson()),
            Habit(
              id: uid(),
              title: read,
              created: today,
              type: 'quantity',
              unit: pages,
              schedules: [Schedule(id: uid(), from: today, target: 10000)],
            ).toJson(),
          ],
          'routines': [
            ...s.routines.map((e) => e.toJson()),
            routineTemplates(vietnamese: vi).first.toJson(),
          ],
        },
        'settings': {...s.settings, 'onboarded': true},
      }),
      remember: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HandySpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HandyMark(Icons.check_circle, size: 48),
                  ),
                  const SizedBox(height: HandySpace.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      tr(context, 'Start small.', 'Bắt đầu từ việc nhỏ.'),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: HandySpace.m),
                  Text(
                    tr(
                      context,
                      'Mark what you do each day with one tap, and run your routines step by step. Everything stays on this device; no account.',
                      'Đánh dấu việc mỗi ngày bằng một chạm, và chạy quy trình từng bước. Mọi thứ ở trên máy này; không cần tài khoản.',
                    ),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: HandySpace.xl),
                  FilledButton(
                    key: const Key('onboard-create'),
                    onPressed: () async {
                      if (await _start(context) && context.mounted)
                        await openHabitEditor(context, scope);
                    },
                    child: Text(
                      tr(
                        context,
                        'Make my first habit',
                        'Tạo thói quen đầu tiên',
                      ),
                    ),
                  ),
                  const SizedBox(height: HandySpace.s),
                  OutlinedButton(
                    key: const Key('onboard-examples'),
                    onPressed: () => _start(context, examples: true),
                    child: Text(
                      tr(
                        context,
                        'Show me examples I can change',
                        'Thêm ví dụ để sửa',
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('onboard-skip'),
                    onPressed: () => _start(context),
                    child: Text(
                      tr(context, 'Start with a blank day', 'Bắt đầu trống'),
                    ),
                  ),
                  const SizedBox(height: HandySpace.l),
                  Text(
                    tr(
                      context,
                      'Reminders are optional and asked for later.',
                      'Nhắc là tùy chọn, sẽ hỏi sau.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
