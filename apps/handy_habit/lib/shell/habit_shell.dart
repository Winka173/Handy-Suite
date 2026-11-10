import 'package:handy_ui/kit.dart';
import '../habits/preset_sheet.dart';
import '../insights/insights_page.dart';
import '../pauses/pauses.dart';
import '../scope.dart';
import '../routines/routines_page.dart';
import '../today/today_page.dart';
import '../design/palette.dart';
import '../welcome/welcome_page.dart';

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
    if (scope.state.settings['onboarded'] != true &&
        scope.state.habits.isEmpty &&
        scope.state.routines.isEmpty &&
        scope.state.events.isEmpty &&
        scope.state.sessions.isEmpty &&
        scope.state.trash.isEmpty &&
        scope.state.pauses.isEmpty)
      return HabitWelcomePage(
        onDone: () async {
          await scope.controller.change(
            (s) => s.copy({
              'settings': {...s.settings, 'onboarded': true},
            }),
            remember: false,
          );
        },
      );
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
          PopupMenuButton<String>(
            key: const Key('habit-add'),
            tooltip: tr(context, 'Add', 'Thêm'),
            icon: const Icon(Icons.add),
            onSelected: (v) => switch (v) {
              'habit' => addHabit(context, scope),
              'pause' => openPauseEditor(context, scope),
              _ => Navigator.pushNamed(context, '/templates?kind=routine'),
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
                    'routine' => tr(context, 'New routine', 'Quy trình mới'),
                    _ => tr(context, 'Pause', 'Kỳ nghỉ'),
                  }),
                ),
            ],
          ),
          if (!wide)
            IconButton(
              key: const Key('open-settings'),
              tooltip: tr(context, 'Settings', 'Cài đặt'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
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
