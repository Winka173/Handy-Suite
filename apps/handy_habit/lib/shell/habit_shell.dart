import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/preset_sheet.dart';
import '../habits/habit_editor.dart';
import '../insights/insights_page.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../routines/routines_page.dart';
import '../today/today_page.dart';
import '../ui/words.dart';
import '../design/palette.dart';

/// The three daily jobs. Legacy internal area IDs stay stable for notices.
class HabitShell extends StatelessWidget {
  final HabitScope scope;
  final int area;
  const HabitShell({super.key, required this.scope, this.area = 0});

  void go(BuildContext context, String path) {
    if (ModalRoute.of(context)?.settings.name == path) return;
    if (ModalRoute.of(context)?.isFirst == true) {
      Navigator.pushNamed(context, path);
    } else {
      Navigator.pushReplacementNamed(context, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (scope.state.settings['onboarded'] != true)
      return Onboarding(scope: scope);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final open = scope.state.settings['sidebarCollapsed'] != true;
    final areas = [
      (0, Icons.today_outlined, tr(context, 'Today', 'Hôm nay'), '/today'),
      (
        2,
        Icons.format_list_numbered,
        tr(context, 'Routines', 'Quy trình'),
        '/routines',
      ),
      (
        3,
        Icons.insights_outlined,
        tr(context, 'Progress', 'Tiến bộ'),
        '/progress',
      ),
    ];
    void setSide(bool open) => scope.write(
      context,
      (s) => s.copy({
        'settings': {...s.settings, 'sidebarCollapsed': !open},
      }),
      remember: false,
    );
    Widget foot(String key, IconData icon, String label, String path) =>
        ListTile(
          key: Key(key),
          leading: Icon(icon, size: 20),
          title: Text(label),
          onTap: () => Navigator.pushNamed(context, path),
        );
    final page = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: wide
            ? Text(areas.firstWhere((a) => a.$1 == area).$3)
            : const Text('Handy Habit'),
        actions: [
          if (!wide)
            IconButton(
              key: const Key('open-settings'),
              tooltip: tr(context, 'Settings', 'Cài đặt'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          PopupMenuButton<String>(
            key: const Key('habit-add'),
            tooltip: tr(context, 'Add', 'Thêm'),
            icon: const Icon(Icons.add),
            onSelected: (v) => switch (v) {
              'habit' => addHabit(context, scope),
              'pause' => openPauseEditor(context, scope),
              _ => Navigator.pushNamed(context, '/routine/new'),
            },
            itemBuilder: (context) => [
              for (final v
                  in area == 2
                      ? ['routine', 'habit', 'pause']
                      : ['habit', 'routine', 'pause'])
                PopupMenuItem(
                  key: Key('add-$v'),
                  value: v,
                  child: Text(switch (v) {
                    'habit' => tr(context, 'New habit', 'Thói quen mới'),
                    'routine' => tr(context, 'New routine', 'Quy trình m?i'),
                    _ => tr(context, 'Pause', 'Kỳ nghỉ'),
                  }),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: HandySwap(
          child: KeyedSubtree(
            key: ValueKey(area),
            child: switch (area) {
              2 => RoutinesPage(scope: scope),
              3 => InsightsPage(scope: scope),
              _ => TodayPage(scope: scope),
            },
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              key: const Key('habit-nav'),
              selectedIndex: areas.indexWhere((a) => a.$1 == area),
              onDestinationSelected: (i) => go(context, areas[i].$4),
              destinations: [
                for (final a in areas)
                  NavigationDestination(
                    key: Key('nav-${a.$1}'),
                    icon: Icon(a.$2),
                    label: a.$3,
                  ),
              ],
            ),
    );
    if (!wide) return page;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandySideRail(
            open: !open,
            child: IconButton(
              key: const Key('side-open'),
              tooltip: tr(context, 'Show the sidebar', 'Hiện thanh bên'),
              icon: const Icon(Icons.keyboard_double_arrow_right),
              onPressed: () => setSide(true),
            ),
          ),
          HandySidePanel(
            width: 224,
            open: open,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                right: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 20),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Handy Habit',
                              maxLines: 2,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: HabitPalette.of(context).anchor,
                                  ),
                            ),
                          ),
                          IconButton(
                            key: const Key('side-collapse'),
                            tooltip: tr(
                              context,
                              'Hide the sidebar',
                              'Thu gọn thanh bên',
                            ),
                            icon: const Icon(Icons.keyboard_double_arrow_left),
                            onPressed: () => setSide(false),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final a in areas)
                            ListTile(
                              key: Key('area-${a.$1}'),
                              leading: Icon(a.$2, size: 20),
                              title: Text(a.$3),
                              selected: a.$1 == area,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.onSurface,
                              selectedTileColor: HabitPalette.of(
                                context,
                              ).raised,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              onTap: () => go(context, a.$4),
                            ),
                        ],
                      ),
                    ),
                    foot(
                      'side-help',
                      Icons.help_outline,
                      tr(context, 'Help', 'Trợ giúp'),
                      '/help',
                    ),
                    foot(
                      'open-settings',
                      Icons.settings_outlined,
                      tr(context, 'Settings', 'Cài đặt'),
                      '/settings',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: page),
        ],
      ),
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
