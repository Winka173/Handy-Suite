import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../create/new_board.dart';
import '../design/theme.dart';
import '../scope.dart';

/// On a wide screen (a computer, a tablet on its side) the app's pages sit
/// beside one sidebar: the app's name, All boards, My Work, each board
/// with its colour and its open cards, New board, then Trash and Settings
/// at the foot. Narrower screens show the page alone.
class BoardsFrame extends StatelessWidget {
  static const minWidth = 1100.0;
  final BoardsScope scope;

  /// The route this page answers ('/', '/board/<id>', '/my-work', …).
  final String place;
  final Widget child;
  const BoardsFrame({
    super.key,
    required this.scope,
    required this.place,
    required this.child,
  });

  static bool wide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= minWidth;

  @override
  Widget build(BuildContext context) {
    if (!wide(context)) return child;
    final p = BoardsPalette.of(context);
    return ListenableBuilder(
      listenable: scope.controller,
      builder: (context, _) {
        // Folded away or shown; remembered in the app's preferences.
        final open = scope.state.preferences['sidebarCollapsed'] != true;
        void set(bool open) => scope.controller
            .change(
              (s) => s.copy(
                preferences: {...s.preferences, 'sidebarCollapsed': !open},
              ),
              history: false,
            )
            .catchError((_) {});
        return ColoredBox(
          color: p.canvas,
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HandySideRail(
                      open: !open,
                      child: SideReopen(onTap: () => set(true)),
                    ),
                    HandySidePanel(
                      width: 248,
                      open: open,
                      child: _Sidebar(
                        scope: scope,
                        place: place,
                        onCollapse: () => set(false),
                      ),
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  final BoardsScope scope;
  final String place;
  final VoidCallback? onCollapse;
  const _Sidebar({required this.scope, required this.place, this.onCollapse});

  void _go(BuildContext context, String to) {
    if (to == place) return;
    final nav = Navigator.of(context);
    if (to == '/') {
      nav.popUntil((r) => r.isFirst);
    } else {
      // One page over Home at a time, so Back always leads home.
      nav.pushNamedAndRemoveUntil(to, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final now = scope.clock();
      final boards = homeBoards(s);
      // Colours by the order boards were made: neighbours differ and a
      // board keeps its colour as others change.
      final made = [for (final b in s.rows('boards')) b.id];
      final work = myWork(s, now);
      Widget row({
        required String to,
        required Widget lead,
        required String label,
        int? count,
        Key? key,
        VoidCallback? onTap,
        Color? ink,
      }) {
        final on = to == place;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
          child: Material(
            // The open place on the plum band, white words.
            color: on ? p.band : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(10),
              onTap: onTap ?? () => _go(context, to),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Center(
                          child: IconTheme.merge(
                            data: IconThemeData(
                              color: on ? p.bandInk : p.muted,
                            ),
                            child: lead,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: on ? p.bandInk : ink ?? p.ink,
                            fontWeight: on ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (count != null)
                        Text(
                          '$count',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: on ? p.bandSub : p.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      Icon icon(IconData i) => Icon(i, size: 18);
      return SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 28,
                      height: 28,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Handy Boards',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onCollapse != null)
                    IconButton(
                      key: const Key('side-collapse'),
                      tooltip: tr(
                        context,
                        'Hide the sidebar',
                        'Thu gọn thanh bên',
                      ),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      onPressed: onCollapse,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: const Key('boards-sidebar'),
                padding: EdgeInsets.zero,
                children: [
                  row(
                    to: '/',
                    key: const Key('side-home'),
                    lead: icon(Icons.home_outlined),
                    label: tr(context, 'All boards', 'Tất cả bảng'),
                  ),
                  row(
                    to: '/my-work',
                    key: const Key('side-my-work'),
                    lead: icon(Icons.check),
                    label: tr(context, 'My Work', 'Việc của tôi'),
                    count: work.today.length + work.behind.length,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 16, 8),
                    child: Text(
                      tr(context, 'Boards', 'Bảng'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ),
                  for (final b in boards)
                    Builder(
                      builder: (context) {
                        final sum = boardSummary(s, b.id, now: now);
                        return row(
                          to: '/board/${b.id}',
                          key: Key('side-board-${b.id}'),
                          lead: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              // The board's own identity colour.
                              color: HandyPalette.of(
                                context,
                                made.indexOf(b.id),
                              ).mark,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          label: b.str('title'),
                          count: sum.cards - sum.done,
                        );
                      },
                    ),
                  row(
                    to: '',
                    key: const Key('side-new-board'),
                    lead: Icon(Icons.add, size: 18, color: p.primary),
                    label: tr(context, 'New board', 'Bảng mới'),
                    ink: p.primary,
                    onTap: () => newBoard(context, scope),
                  ),
                ],
              ),
            ),
            row(
              to: '/trash',
              key: const Key('side-trash'),
              lead: icon(Icons.delete_outline),
              label: tr(context, 'Trash', 'Thùng rác'),
            ),
            row(
              to: '/settings',
              key: const Key('side-settings'),
              lead: icon(Icons.settings_outlined),
              label: tr(context, 'Settings', 'Cài đặt'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

/// Shown while the sidebar is folded away: brings it back.
class SideReopen extends StatelessWidget {
  final VoidCallback onTap;
  const SideReopen({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('side-open'),
    tooltip: tr(context, 'Show the sidebar', 'Hiện thanh bên'),
    icon: const Icon(Icons.keyboard_double_arrow_right),
    onPressed: onTap,
  );
}
