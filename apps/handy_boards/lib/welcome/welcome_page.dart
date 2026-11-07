import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/category_strip.dart';
import '../board/kanban_view.dart';
import '../create/templates.dart' show isVi;
import '../design/theme.dart';
import '../scope.dart';

/// The first run, played on a real board that is never saved: choose how
/// to start, add a card and move it across, then see that a category stays
/// with its card in every column. Replayable from Settings › Help.
class WelcomePage extends StatefulWidget {
  final BoardsScope scope;

  /// Called with the board to make: 'blank', 'study' or null (skip).
  final Future<void> Function(String? start) onDone;
  const WelcomePage({super.key, required this.scope, required this.onDone});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

enum _Step { start, add, move, category, done }

class _WelcomePageState extends State<WelcomePage> {
  static const _board = '00000000-0000-4000-8000-00000000c0de';
  _Step step = _Step.start;
  String start = 'study';
  BoardsState? sample;
  String? card, category;
  final text = TextEditingController();
  final kanban = GlobalKey<KanbanViewState>();
  bool finishing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (sample != null) return;
    final vi = isVi(context);
    text.text = vi ? 'Làm bài tập chương 4' : 'Do the chapter 4 exercises';
    // The study board with only a few cards, so the steps stay readable.
    var s = createKanbanBoard(
      BoardsState(),
      title: vi ? 'Học kỳ 1' : 'Semester 1',
      preset: presetById('study'),
      vi: vi,
      now: widget.scope.clock(),
      boardId: _board,
    );
    final keep = topTasks(s).take(3).map((t) => t.id).toSet();
    final drop = topTasks(
      s,
    ).where((t) => !keep.contains(t.id)).map((t) => t.id).toSet();
    if (drop.isNotEmpty)
      s = permanentlyDelete(trashTasks(s, drop), drop, confirmed: true);
    sample = s;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  List<BoardRecord> get _columns => columnsOf(sample!, _board);

  void _add() {
    final title = text.text.trim();
    if (title.isEmpty) return;
    final s = sample!;
    final maths = categoriesOf(s, _board).first.id;
    final t = newTask(
      s,
      _board,
      title,
      category: maths,
    ).copy({'status': _columns.first.id, 'order': -1});
    setState(() {
      sample = saveTask(s, t, now: widget.scope.clock());
      card = t.id;
      step = _Step.move;
    });
  }

  Future<void> _move(String id, String column, int index) async {
    setState(
      () => sample = moveCard(sample!, id, column: column, index: index),
    );
    if (id != card) return;
    final columns = _columns;
    if (step == _Step.move && column == columns[1].id) {
      setState(() => step = _Step.category);
    } else if (step == _Step.category && column == columns.last.id) {
      setState(() => step = _Step.done);
    }
  }

  Future<void> _finish(String? start) async {
    if (finishing) return;
    setState(() => finishing = true);
    try {
      await widget.onDone(start);
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final s = sample!;
    final columns = _columns;
    final cat = card == null
        ? null
        : s.maybe(
            'categories',
            s.get('tasks', card!).data['category'] as String?,
          );
    final (String title, String line, List<Widget> controls) = switch (step) {
      _Step.start => (
        tr(
          context,
          'A board for how you work',
          'Một bảng theo cách bạn làm việc',
        ),
        tr(
          context,
          'Columns say where work is. Categories say what it is about, and stay with each card. Nothing leaves this device.',
          'Cột cho biết việc đang ở đâu. Nhóm cho biết việc thuộc về gì, và đi theo từng thẻ. Không gì rời khỏi máy này.',
        ),
        [
          SegmentedButton<String>(
            key: const Key('welcome-start'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'study',
                label: Text(tr(context, 'Study board', 'Bảng học tập')),
              ),
              ButtonSegment(
                value: 'blank',
                label: Text(tr(context, 'Blank board', 'Bảng trống')),
              ),
            ],
            selected: {start},
            onSelectionChanged: (v) => setState(() => start = v.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('welcome-next'),
            onPressed: () => setState(() => step = _Step.add),
            child: Text(
              tr(context, 'Show me in 30 seconds', 'Xem nhanh trong 30 giây'),
            ),
          ),
          TextButton(
            key: const Key('welcome-skip'),
            onPressed: () => _finish(null),
            child: Text(tr(context, 'Skip', 'Bỏ qua')),
          ),
        ],
      ),
      _Step.add => (
        tr(context, 'Add a card', 'Thêm một thẻ'),
        tr(
          context,
          'A card is one piece of work. It starts in the first column.',
          'Mỗi thẻ là một việc. Thẻ mới nằm ở cột đầu tiên.',
        ),
        [
          TextField(
            key: const Key('welcome-card'),
            controller: text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                key: const Key('welcome-add'),
                tooltip: tr(context, 'Add', 'Thêm'),
                onPressed: _add,
                icon: const Icon(Icons.arrow_upward),
              ),
            ),
          ),
        ],
      ),
      _Step.move => (
        tr(
          context,
          'Move it to ${columns[1].str('title')}',
          'Chuyển thẻ sang ${columns[1].str('title')}',
        ),
        tr(
          context,
          'Hold the card, then drag it to the next column. Or let us move it.',
          'Giữ thẻ rồi kéo sang cột bên cạnh. Hoặc để app chuyển giúp.',
        ),
        [
          OutlinedButton.icon(
            key: const Key('welcome-move'),
            onPressed: () {
              _move(card!, columns[1].id, 0);
              kanban.currentState?.reveal(1);
            },
            icon: const Icon(Icons.arrow_forward),
            label: Text(tr(context, 'Move it for me', 'Chuyển giúp tôi')),
          ),
        ],
      ),
      _Step.category => (
        tr(context, 'Its category goes with it', 'Nhóm đi theo thẻ'),
        tr(
          context,
          'Your card is in ${cat?.str('title') ?? ''}. Tap ${cat?.str('title') ?? ''} above to see only those cards, then finish the card: move it to ${columns.last.str('title')}.',
          'Thẻ của bạn thuộc nhóm ${cat?.str('title') ?? ''}. Chạm ${cat?.str('title') ?? ''} ở trên để chỉ xem thẻ nhóm này, rồi hoàn thành thẻ: chuyển sang ${columns.last.str('title')}.',
        ),
        [
          OutlinedButton.icon(
            key: const Key('welcome-finish-card'),
            onPressed: () {
              _move(card!, columns.last.id, 0);
              kanban.currentState?.reveal(columns.length - 1);
            },
            icon: const Icon(Icons.check),
            label: Text(tr(context, 'Finish it for me', 'Hoàn thành giúp tôi')),
          ),
        ],
      ),
      _Step.done => (
        tr(
          context,
          'Still in ${cat?.str('title') ?? ''}',
          'Vẫn thuộc ${cat?.str('title') ?? ''}',
        ),
        tr(
          context,
          'Finished, and still counted in its category. That is the whole idea.',
          'Đã xong, và vẫn được tính trong nhóm của nó. Ý tưởng chỉ có vậy.',
        ),
        [
          FilledButton(
            key: const Key('welcome-done'),
            onPressed: finishing ? null : () => _finish(start),
            child: Text(
              start == 'study'
                  ? tr(
                      context,
                      'Make my study board',
                      'Tạo bảng học tập của tôi',
                    )
                  : tr(context, 'Make my board', 'Tạo bảng của tôi'),
            ),
          ),
        ],
      ),
    };
    // The board shows from the first step, read-only until the tour starts,
    // so the first screen already says what the app is.
    final live = step != _Step.start;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 28,
                              height: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Handy Boards',
                            style: theme.textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (step != _Step.start)
                            SizedBox(
                              width: 72,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: step.index / 4,
                                  minHeight: 4,
                                  semanticsLabel: tr(
                                    context,
                                    'Tour progress',
                                    'Tiến độ hướng dẫn',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      HandySwap(
                        child: Column(
                          key: ValueKey(step),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              liveRegion: true,
                              child: Text(
                                title,
                                style: theme.textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              line,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: p.muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...controls,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...[
              CategoryStrip(
                state: s,
                board: _board,
                selected: category,
                onSelect: (v) => setState(() => category = live ? v : null),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: KanbanView(
                  key: kanban,
                  state: s,
                  board: _board,
                  now: widget.scope.clock(),
                  filter: KanbanFilter(category: category),
                  actions: live
                      ? KanbanActions(
                          move: _move,
                          tick: (id, v) => setState(
                            () => sample = toggleChecklist(sample!, id, v),
                          ),
                        )
                      : const KanbanActions(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
