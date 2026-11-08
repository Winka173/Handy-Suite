import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../create/new_board.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/look.dart';

/// My boards: which board needs me today? A line from the data says what
/// is due, then every board with its cover and real figures.
class HomePage extends StatelessWidget {
  final BoardsScope scope;
  const HomePage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final c = scope.controller;
      final s = c.state;
      final p = BoardsPalette.of(context);
      final theme = Theme.of(context);
      final width = MediaQuery.sizeOf(context).width;
      final phone = width < 600;
      final bar = AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon.png', width: 28, height: 28),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Handy Boards',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        actions: [
          if (s != null && s.rows('boards').isNotEmpty)
            IconButton(
              key: const Key('home-search'),
              tooltip: tr(context, 'Search all cards', 'Tìm mọi thẻ'),
              onPressed: () => Navigator.pushNamed(context, '/search'),
              icon: const Icon(Icons.search),
            ),
          if (s != null && s.rows('boards').isNotEmpty)
            IconButton(
              key: const Key('home-my-work'),
              tooltip: tr(context, 'My Work (Pro)', 'Việc của tôi (Pro)'),
              onPressed: () => Navigator.pushNamed(context, '/my-work'),
              icon: const Icon(Icons.dashboard_outlined),
            ),
          IconButton(
            key: const Key('home-settings'),
            tooltip: tr(context, 'Settings', 'Cài đặt'),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          if (!phone && s != null && homeBoards(s).isNotEmpty) ...[
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('home-new-wide'),
              onPressed: () => newBoard(context, scope),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'New board', 'Bảng mới')),
            ),
          ],
          const SizedBox(width: 12),
        ],
      );
      if (s == null) {
        return Scaffold(
          appBar: bar,
          body: c.error == null
              ? const _Loading()
              : HandyEmpty(
                  title: tr(
                    context,
                    'Could not open your boards',
                    'Không mở được bảng',
                  ),
                  message: tr(
                    context,
                    'Nothing was changed or reset.',
                    'Không có gì bị đổi hay xoá.',
                  ),
                  action: FilledButton(
                    onPressed: c.load,
                    child: Text(tr(context, 'Try again', 'Thử lại')),
                  ),
                ),
        );
      }
      final boards = homeBoards(s);
      final now = scope.clock();
      if (boards.isEmpty)
        return Scaffold(
          appBar: bar,
          body: _FirstBoard(scope: scope),
        );
      final sums = {
        for (final b in boards) b.id: boardSummary(s, b.id, now: now),
      };
      final dueToday = sums.values.fold<int>(0, (n, v) => n + v.dueToday);
      final overdue = sums.values.fold<int>(0, (n, v) => n + v.overdue);
      final parts = <(String, bool)>[
        if (dueToday > 0)
          (
            tr(context, '$dueToday due today', '$dueToday thẻ đến hạn hôm nay'),
            false,
          ),
        if (overdue > 0)
          (tr(context, '$overdue overdue', '$overdue thẻ quá hạn'), true),
      ];
      final finding = parts.isEmpty
          ? Text(
              tr(
                context,
                'Nothing is due today.',
                'Hôm nay không có thẻ nào đến hạn.',
              ),
              key: const Key('home-finding'),
              style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
            )
          : Text.rich(
              key: const Key('home-finding'),
              TextSpan(
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0) const TextSpan(text: ' · '),
                    TextSpan(
                      text: parts[i].$1,
                      style: parts[i].$2 ? TextStyle(color: p.danger) : null,
                    ),
                  ],
                ],
              ),
              style: theme.textTheme.bodyLarge?.copyWith(color: p.ink),
            );
      final cols = width >= 1024 ? 3 : (width >= 600 ? 2 : 1);
      return Scaffold(
        appBar: bar,
        floatingActionButton: !phone
            ? null
            : MediaQuery.textScalerOf(context).scale(1) > 1.4 && width < 400
            // Very large text on a narrow phone: the label would not fit.
            ? FloatingActionButton(
                key: const Key('home-new'),
                tooltip: tr(context, 'New board', 'Bảng mới'),
                onPressed: () => newBoard(context, scope),
                child: const Icon(Icons.add),
              )
            : FloatingActionButton.extended(
                key: const Key('home-new'),
                onPressed: () => newBoard(context, scope),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'New board', 'Bảng mới')),
              ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 16 : 24,
                    8,
                    phone ? 16 : 24,
                    20,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            tr(context, 'Your boards', 'Bảng của bạn'),
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: 6),
                        finding,
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    phone ? 16 : 24,
                    0,
                    phone ? 16 : 24,
                    96,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: phone ? 236 : 250,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => BoardTile(
                        board: boards[i],
                        summary: sums[boards[i].id]!,
                        now: now,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/board/${boards[i].id}',
                        ),
                      ),
                      childCount: boards.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// A board on the home: its cover, name and real figures.
class BoardTile extends StatelessWidget {
  final BoardRecord board;
  final BoardSummary summary;
  final DateTime now;
  final VoidCallback onTap;
  const BoardTile({
    super.key,
    required this.board,
    required this.summary,
    required this.now,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final facts = [
      if (summary.categories > 0)
        tr(
          context,
          '${summary.categories} categories',
          '${summary.categories} nhóm',
        ),
      tr(
        context,
        '${summary.cards} ${summary.cards == 1 ? 'card' : 'cards'}',
        '${summary.cards} thẻ',
      ),
      tr(context, '${summary.done} done', '${summary.done} xong'),
    ].join(' · ');
    final changed = whenLabel(context, summary.updated, now);
    return Semantics(
      button: true,
      label: '${board.str('title')}. $facts',
      excludeSemantics: true,
      child: Material(
        // The board's own tone, from its cover.
        color: boardGround(context, board).page,
        borderRadius: BorderRadius.circular(BoardsRadii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('board-${board.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    boardCover(board),
                    if (board.flag('pinned'))
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: p.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.push_pin,
                            size: 16,
                            color: p.ink,
                            semanticLabel: tr(context, 'Pinned', 'Đã ghim'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.str('title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      facts,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                      ),
                    ),
                    if (summary.dueToday + summary.overdue > 0 ||
                        changed.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary.overdue > 0
                            ? tr(
                                context,
                                '${summary.overdue} overdue',
                                '${summary.overdue} thẻ quá hạn',
                              )
                            : summary.dueToday > 0
                            ? tr(
                                context,
                                '${summary.dueToday} due today',
                                '${summary.dueToday} thẻ đến hạn hôm nay',
                              )
                            : tr(context, 'Changed $changed', 'Sửa $changed'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: summary.overdue > 0 ? p.danger : p.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstBoard extends StatelessWidget {
  final BoardsScope scope;
  const _FirstBoard({required this.scope});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _BoardSketch(),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Make your first board', 'Tạo bảng đầu tiên'),
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'Columns for where work is, categories for what it is about. Everything stays on this device.',
                  'Cột cho biết việc đang ở đâu, nhóm cho biết việc thuộc về gì. Mọi thứ nằm trên máy này.',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('first-templates'),
                onPressed: () => Navigator.pushNamed(context, '/templates'),
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: Text(tr(context, 'Explore templates', 'Xem các mẫu')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('first-blank'),
                onPressed: () => createBlank(context, scope),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Start blank', 'Bắt đầu bảng trống')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small drawing of a board (three columns of cards with category
/// marks), made from the same parts as the real one.
class _BoardSketch extends StatelessWidget {
  const _BoardSketch();
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    Widget card(int hue, double h) => Container(
      height: h,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      child: Container(
        width: 26,
        height: 6,
        decoration: BoxDecoration(
          color: HandyPalette.of(context, hue).mark,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
    Widget column(List<(int, double)> cards) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [for (final c in cards) card(c.$1, c.$2)]),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            column([(0, 44), (1, 30), (2, 44)]),
            const SizedBox(width: 8),
            column([(3, 52), (0, 30)]),
            const SizedBox(width: 8),
            column([(1, 30)]),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 200, height: 28, color: p.raised),
          const SizedBox(height: 24),
          for (var i = 0; i < 2; i++)
            Container(
              height: 220,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(BoardsRadii.tile),
              ),
            ),
        ],
      ),
    );
  }
}
