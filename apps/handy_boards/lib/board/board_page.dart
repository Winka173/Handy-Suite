import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../card/card_sheet.dart';
import '../card/cover_picker.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'board_menus.dart';
import 'categories_sheet.dart';
import 'category_strip.dart';
import 'kanban_view.dart';
import 'key_dates.dart';
import 'look_picker.dart';
import 'time_view.dart';

/// Shows [message] with an Undo that steps the controller back once.
void showUndo(BuildContext context, BoardsScope scope, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: tr(context, 'Undo', 'Hoàn tác'),
        onPressed: () => scope.controller.undo(),
      ),
    ),
  );
}

/// One board: its name, the category strip and the Kanban.
class BoardPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const BoardPage({super.key, required this.scope, required this.board});
  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  /// The category in focus (an id, [CategoryStrip.uncategorisedKey], or
  /// null). Focus only highlights; [only] is the separate, explicit filter.
  String? focus;
  bool only = false;
  bool searching = false, dueSoon = false, showStrip = true;

  /// While choosing a look: the one being tried (shown, not saved).
  String? previewLook;
  final query = TextEditingController();
  // The short page's own scroll, so a column scrolled to its end hands
  // the rest of the swipe to the page.
  final page = ScrollController();
  // One per layout: a board is never moved between the tall and the
  // short page (rotating rebuilds it).
  final kanban = GlobalKey<KanbanViewState>();
  final kanbanShort = GlobalKey<KanbanViewState>();
  BoardsScope get scope => widget.scope;

  @override
  void dispose() {
    query.dispose();
    page.dispose();
    super.dispose();
  }

  KanbanFilter get filter => KanbanFilter(
    category: !only || focus == null || focus == CategoryStrip.uncategorisedKey
        ? null
        : focus,
    uncategorised: only && focus == CategoryStrip.uncategorisedKey,
    query: query.text,
    dueSoon: dueSoon,
    focus: only ? null : focus,
  );

  Future<void> _move(String card, String column, int index) async {
    final s = scope.state;
    final from = s.get('tasks', card).str('status');
    final repeated = s.get('tasks', card).data['repeatedAs'];
    await scope.run(
      context,
      () => scope.controller.change(
        (s) =>
            moveCard(s, card, column: column, index: index, now: scope.clock()),
      ),
    );
    if (!mounted || from == column) return;
    final to = scope.state.get('statuses', column).str('title');
    final next = scope.state.maybe('tasks', card)?.data['repeatedAs'];
    showUndo(
      context,
      scope,
      next != null && next != repeated
          ? tr(
              context,
              'Moved to $to · the next one is waiting',
              'Đã chuyển sang $to · lần tiếp theo đã có',
            )
          : tr(context, 'Moved to $to', 'Đã chuyển sang $to'),
    );
  }

  /// The board's view and time span are remembered per board, outside
  /// the undo history.
  Future<void> _look({String? view, TimeRange? span}) => scope.run(
    context,
    () => scope.controller.change(
      (s) => setBoardLook(s, widget.board, view: view, span: span?.toJson()),
      history: false,
    ),
  );

  Future<void> _setDue(String card, DateTime? day) async {
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => setDueDay(s, card, day, now: scope.clock()),
      ),
    );
    if (!mounted) return;
    final when = day == null ? '' : dueLabel(context, day, scope.clock());
    final date = day == null ? '' : '${day.day}/${day.month}';
    final label = when == date ? date : '$when $date';
    showUndo(
      context,
      scope,
      day == null
          ? tr(context, 'Due date taken off', 'Đã bỏ hạn')
          : tr(context, 'Due $label', 'Hạn: $label'),
    );
  }

  Future<void> _add(String column, String title) => scope.run(
    context,
    () => scope.controller.change((s) {
      // A card added while a category is in focus belongs to it.
      final cat = focus == null || focus == CategoryStrip.uncategorisedKey
          ? null
          : focus;
      final card = newTask(
        s,
        widget.board,
        title,
        category: cat,
      ).copy({'status': column, 'order': cardsIn(s, column).length});
      return saveTask(s, card, now: scope.clock());
    }),
  );

  Future<void> _tick(String subtask, bool done) => scope.run(
    context,
    () => scope.controller.change(
      (s) => finishWhenSubtasksDone(
        toggleChecklist(s, subtask, done, now: scope.clock()),
        s.get('checklist', subtask).str('task'),
        now: scope.clock(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.controller.state;
      final b = s?.maybe('boards', widget.board);
      if (s == null || b == null) {
        return Scaffold(
          appBar: AppBar(),
          body: HandyEmpty(
            title: tr(context, 'This board is gone', 'Bảng này không còn'),
            message: tr(
              context,
              'It was deleted or moved.',
              'Bảng đã bị xoá hoặc chuyển đi.',
            ),
          ),
        );
      }
      return _page(context, s, b);
    },
  );

  Widget _page(BuildContext context, BoardsState s, BoardRecord b) {
    final theme = Theme.of(context);
    final now = scope.clock();
    final sum = boardSummary(s, widget.board, now: now);
    final detailed = b.str('presentation') == 'detailed';
    final hasCategories = categoryProgress(s, widget.board).isNotEmpty;
    final p = BoardsPalette.of(context);
    final ground = boardGround(context, b, look: previewLook);
    final timeView = b.str('view') == 'time';
    final pinned = timePinned(b);
    final milestones = milestonesOf(b);
    // A narrow phone or very large text keeps the board's height: the
    // Board | Time switch moves into the buttons on the cover.
    final roomy =
        MediaQuery.sizeOf(context).width >= 360 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final title = Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              b.str('title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              context,
              '${sum.cards} ${sum.cards == 1 ? 'card' : 'cards'} · ${sum.done} done',
              '${sum.cards} thẻ · ${sum.done} xong',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
          // Key dates need room; a narrow phone with large text keeps the
          // board's height and finds them in the board menu.
          if (milestones.isNotEmpty && roomy) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in milestones)
                  KeyDateChip(
                    label: m.label,
                    day: m.day,
                    now: now,
                    onTap: () => editMilestones(context, scope, widget.board),
                  ),
              ],
            ),
          ],
          if (roomy && pinned) ...[
            const SizedBox(height: 10),
            // Where things are (columns) or when they are due (time).
            SegmentedButton<String>(
              key: const Key('board-view'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: 'board',
                  icon: const Icon(Icons.view_week_outlined, size: 18),
                  label: Text(tr(context, 'Board', 'Bảng')),
                ),
                ButtonSegment(
                  value: 'time',
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(tr(context, 'Time', 'Thời gian')),
                ),
              ],
              selected: {timeView ? 'time' : 'board'},
              onSelectionChanged: (v) => _look(view: v.first),
            ),
          ],
        ],
      ),
    );
    final actions = <Widget>[
      if (!roomy || !pinned)
        IconButton(
          key: const Key('board-view-toggle'),
          tooltip: timeView
              ? tr(context, 'Show the board', 'Xem bảng')
              : tr(context, 'Show by time', 'Xem theo thời gian'),
          onPressed: () => _look(view: timeView ? 'board' : 'time'),
          icon: Icon(timeView ? Icons.view_week_outlined : Icons.date_range),
        ),
      IconButton(
        key: const Key('board-search'),
        tooltip: tr(context, 'Search cards', 'Tìm thẻ'),
        onPressed: () => setState(() {
          searching = !searching;
          if (!searching) query.clear();
        }),
        icon: Icon(searching ? Icons.search_off : Icons.search),
      ),
      // A narrow phone keeps the title room; the strip stays on.
      if (hasCategories && MediaQuery.sizeOf(context).width >= 360)
        IconButton(
          key: const Key('board-categories'),
          tooltip: showStrip
              ? tr(context, 'Hide categories', 'Ẩn nhóm')
              : tr(context, 'Show categories', 'Hiện nhóm'),
          isSelected: showStrip,
          onPressed: () => setState(() => showStrip = !showStrip),
          icon: const Icon(Icons.space_dashboard_outlined),
          selectedIcon: const Icon(Icons.space_dashboard),
        ),
      IconButton(
        key: const Key('board-more'),
        tooltip: tr(context, 'Board options', 'Tuỳ chọn bảng'),
        onPressed: () => boardMenu(
          context,
          scope,
          widget.board,
          onLook: () => setState(
            () => previewLook = s
                .get('boards', widget.board)
                .str('appearance', 'default'),
          ),
        ),
        icon: const Icon(Icons.more_vert),
      ),
    ];
    final due = FilterChip(
      key: const Key('filter-due-soon'),
      selected: dueSoon,
      visualDensity: VisualDensity.compact,
      label: Text(tr(context, 'Due in 3 days', 'Hạn trong 3 ngày')),
      onSelected: (v) => setState(() => dueSoon = v),
    );
    final stripShown = showStrip && hasCategories;
    final chips = <Widget>[
      if (focus != null)
        InputChip(
          label: Text(
            categoryName(
              context,
              focus == CategoryStrip.uncategorisedKey
                  ? null
                  : s.maybe('categories', focus),
            ),
          ),
          onDeleted: () => setState(() {
            focus = null;
            only = false;
          }),
          deleteButtonTooltipMessage: tr(
            context,
            'Show all categories',
            'Hiện mọi nhóm',
          ),
        ),
    ];
    final focusName = focus == null
        ? null
        : categoryName(
            context,
            focus == CategoryStrip.uncategorisedKey
                ? null
                : s.maybe('categories', focus),
          );
    // The board's cover across the top, its buttons on round white
    // backs so they read on any picture.
    Widget round(Widget button) => Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: p.surface.withValues(alpha: .92),
        shape: const CircleBorder(),
        child: button,
      ),
    );
    final band = SizedBox(
      height: (wide ? 140 : 96) + MediaQuery.paddingOf(context).top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          boardCover(b),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  round(
                    IconButton(
                      key: const Key('board-back'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const Spacer(),
                  for (final a in actions) round(a),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // A tall screen keeps the board under a fixed header. A short one
    // (a phone on its side, a small phone, a tablet in landscape) scrolls
    // the header away under a pinned bar of buttons, so the board always
    // gets nearly the whole height; so does very large text. Decided by
    // the screen, not by the space left, so the keyboard never flips it.
    final short =
        MediaQuery.sizeOf(context).height < 720 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    // What sits above the board: its name, search, categories, focus.
    final top = <Widget>[
      title,
      if (searching)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const Key('board-search-field'),
            controller: query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'Search this board', 'Tìm trong bảng này'),
            ),
          ),
        ),
      if (showStrip) ...[
        CategoryStrip(
          state: s,
          board: widget.board,
          selected: focus,
          onSelect: (v) => setState(() {
            focus = v;
            if (v == null) only = false;
          }),
          onEdit: () => editCategories(context, scope, widget.board),
          trailing: [due],
        ),
        const SizedBox(height: 8),
      ],
      if (focusName != null)
        FocusBar(
          name: focusName,
          only: only,
          onOnly: () => setState(() => only = !only),
          onClear: () => setState(() {
            focus = null;
            only = false;
          }),
        ),
      if (!stripShown)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in [...chips, due])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: c),
                ),
            ],
          ),
        ),
    ];
    final board = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: timeView
          ? TimeView(
              state: s,
              board: widget.board,
              now: now,
              filter: filter,
              range: TimeRange.read(b.data['span']),
              onRange: (span) => _look(span: span),
              scope: scope,
              open: (card) => openCard(context, scope, card.id),
              setDue: _setDue,
            )
          : KanbanView(
              key: short ? kanbanShort : kanban,
              state: s,
              board: widget.board,
              now: now,
              detailed: detailed,
              columnColor: ground.column,
              filter: filter,
              actions: KanbanActions(
                open: (card) => openCard(context, scope, card.id),
                move: _move,
                add: _add,
                tick: _tick,
                cardMenu: (card) =>
                    cardMenu(context, scope, card.id, onMoved: _move),
                columnMenu: (column) => columnMenu(context, scope, column.id),
                addColumn: () => addColumnDialog(context, scope, widget.board),
              ),
            ),
    );
    final body = LayoutBuilder(
      builder: (context, box) {
        if (!short) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              band,
              ...top,
              Expanded(
                child: LayoutBuilder(
                  // Never squeezed below a usable column (the keyboard, a
                  // tall look picker): then it scrolls instead. One shape
                  // either way, so the board is never moved to a new parent.
                  builder: (context, rest) => SingleChildScrollView(
                    physics: rest.maxHeight >= 260
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: SizedBox(
                      height: rest.maxHeight.clamp(260.0, double.infinity),
                      child: board,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final bar = kToolbarHeight + MediaQuery.paddingOf(context).top;
        return NotificationListener<OverscrollNotification>(
          // A column at its top or bottom passes the swipe on to the page,
          // so the header comes back with the same thumb movement.
          onNotification: (n) {
            if (n.depth == 0 ||
                n.metrics.axis != Axis.vertical ||
                !page.hasClients) {
              return false;
            }
            final p = page.position;
            final to = (p.pixels + n.overscroll).clamp(
              p.minScrollExtent,
              p.maxScrollExtent,
            );
            if (to != p.pixels) p.jumpTo(to);
            return false;
          },
          child: CustomScrollView(
            key: const Key('board-scroll'),
            controller: page,
            slivers: [
              SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: false,
                toolbarHeight: kToolbarHeight,
                expandedHeight: wide ? 140 : 96,
                backgroundColor: ground.page,
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(background: boardCover(b)),
                leadingWidth: 64,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: round(
                    IconButton(
                      key: const Key('board-back'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                actions: [
                  for (final a in actions) round(a),
                  const SizedBox(width: 4),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: top,
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: (box.maxHeight - bar).clamp(300.0, double.infinity),
                  child: board,
                ),
              ),
            ],
          ),
        );
      },
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            setState(() => searching = true),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            scope.controller.undo(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            scope.controller.redo(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: ground.page,
          body: body,
          bottomNavigationBar: previewLook == null
              ? null
              : LookPicker(
                  current: previewLook!,
                  onPick: (id) => setState(() => previewLook = id),
                  onCancel: () => setState(() => previewLook = null),
                  onApply: () async {
                    final id = previewLook!;
                    if (lookById(id).pro &&
                        !await requirePro(context, ProFeature.looks))
                      return;
                    if (!mounted) return;
                    await scope.run(
                      this.context,
                      () => scope.controller.change(
                        (s) => setBoardLook(
                          s,
                          widget.board,
                          appearance: id == 'default' ? null : id,
                        ),
                      ),
                    );
                    if (mounted) setState(() => previewLook = null);
                  },
                ),
        ),
      ),
    );
  }
}

/// Opens the cover picker for the board and keeps the choice.
Future<void> pickBoardCover(
  BuildContext context,
  BoardsScope scope,
  String board,
) async {
  final b = scope.state.get('boards', board);
  final picked = await pickCover(
    context,
    scope,
    current: b.data['cover'] as String?,
    artOnly: true,
    preview: (cover) => SizedBox(height: 120, child: cover ?? boardCover(b)),
  );
  if (picked == null || !context.mounted) return;
  if (picked.art != null &&
      coverById(picked.art)?.pro == true &&
      !await requirePro(context, ProFeature.covers))
    return;
  if (!context.mounted) return;
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => setBoardLook(s, board, cover: picked.art),
    ),
  );
}
