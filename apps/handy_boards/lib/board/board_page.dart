import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../card/card_templates_ui.dart';
import '../card/card_sheet.dart';
import '../card/cover_picker.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'saved_filters.dart';
import 'board_menus.dart';
import 'categories_sheet.dart';
import 'category_strip.dart';
import 'kanban_view.dart';
import 'key_dates.dart';
import 'look_picker.dart';
import 'timeline_sheet.dart';
import 'week_bar.dart';

/// Shows [message] with an Undo that steps the controller back once.
void showUndo(BuildContext context, BoardsScope scope, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      // Undo stays a few seconds, then goes; it never sits over the board.
      persist: false,
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
  /// The categories picked (ids, [CategoryStrip.uncategorisedKey] for
  /// Uncategorised): the board shows only their cards; empty shows all.
  Set<String> focus = {};
  bool searching = false, dueSoon = false, showStrip = true;

  /// On a timeline, the period shown; it opens on the current one, and
  /// again whenever the board's unit changes.
  TimeWindow? window;
  String? windowUnit;

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

  /// The saved filter in use (Pro), or null.
  String? savedFilter;

  Set<String>? get _only {
    final s = scope.state;
    final view = savedFilter == null ? null : s.maybe('views', savedFilter!);
    if (view == null) return null;
    return {
      for (final t in topTasks(s, board: widget.board))
        if (filterMatches(s, view, t)) t.id,
    };
  }

  Future<void> _filters() async {
    if (!await requirePro(context, ProFeature.savedFilters) || !mounted) return;
    final picked = await savedFiltersSheet(
      context,
      scope,
      widget.board,
      savedFilter,
    );
    if (picked == null || !mounted) return;
    setState(() => savedFilter = picked.isEmpty ? null : picked);
  }

  KanbanFilter get filter => KanbanFilter(
    categories: focus,
    query: query.text,
    dueSoon: dueSoon,
    only: _only,
    window: window,
  );

  /// The category filter alone (for the lines about unfinished work).
  bool _inFocus(BoardRecord t) =>
      KanbanFilter(categories: focus, only: _only).shows(t, scope.clock());

  void _toggle(String key) => setState(
    () => focus = focus.contains(key)
        ? ({...focus}..remove(key))
        : {...focus, key},
  );

  /// Brings [ids] to today, so they sit in the current period; one Undo.
  Future<void> _carry(List<String> ids, String unit) async {
    if (ids.isEmpty) return;
    final now = scope.clock();
    await scope.run(
      context,
      () => scope.controller.change(
        (s) => scheduleCards(s, ids, now, reason: 'move to now', now: now),
      ),
    );
    if (!mounted) return;
    showUndo(
      context,
      scope,
      tr(
        context,
        ids.length == 1
            ? 'Brought ${toThisPeriod(context, unit)}'
            : '${ids.length} brought ${toThisPeriod(context, unit)}',
        'Đã đem ${ids.length} việc ${toThisPeriod(context, unit)}',
      ),
    );
  }

  /// A card of a period gone by opens read-only, with its two actions.
  void _openPast(BoardRecord card, String unit) => openCard(
    context,
    scope,
    card.id,
    readOnly: true,
    banner: (sheet) {
      final s = scope.state, t = s.maybe('tasks', card.id);
      if (t == null) return const SizedBox.shrink();
      final open = !completed(s, t);
      final p = BoardsPalette.of(sheet);
      return Container(
        key: const Key('card-past-banner'),
        color: p.raised,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                sheet,
                'From a period gone by: read only.',
                'Thuộc kỳ đã qua: chỉ xem.',
              ),
              style: Theme.of(sheet).textTheme.bodyMedium,
            ),
            if (open) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    key: const Key('past-done'),
                    onPressed: () async {
                      final done = columnsOf(s, t.str('board')).lastWhere(
                        (c) => c.flag('done'),
                        orElse: () => columnsOf(s, t.str('board')).last,
                      );
                      await _move(t.id, done.id, 0);
                    },
                    child: Text(tr(sheet, 'Mark finished', 'Đánh dấu xong')),
                  ),
                  FilledButton(
                    key: const Key('past-carry'),
                    onPressed: () async {
                      Navigator.pop(sheet);
                      await _carry([t.id], unit);
                    },
                    child: Text(
                      tr(
                        sheet,
                        'Bring ${toThisPeriod(sheet, unit)}',
                        'Đem ${toThisPeriod(sheet, unit)}',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
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

  Future<void> _add(String column, String title) => scope.run(
    context,
    () => scope.controller.change((s) {
      // A card added while categories are picked belongs to the first one
      // picked, so it stays in sight.
      final cat = focus
          .where((k) => k != CategoryStrip.uncategorisedKey)
          .firstOrNull;
      // On a timeline, a card added to a later period is planned for its
      // first day; one added now sits in today's period by its own date.
      final w = window, today = calendarDay(scope.clock());
      final later = w != null && w.first.isAfter(today);
      final card = newTask(s, widget.board, title, category: cat).copy({
        'status': column,
        'order': cardsIn(s, column).length,
        if (later) 'scheduled': isoDay(w.first),
      });
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
    final unit = boardTimeline(b);
    if (unit != windowUnit) {
      windowUnit = unit;
      window = unit == null ? null : timelineWindow(unit, now);
    }
    final kind = unit == null || window == null
        ? null
        : periodKind(unit, window!, now);
    final past = kind == PeriodKind.past;
    final milestones = milestonesOf(b);
    // A narrow phone or very large text keeps the board's height: the
    // key dates move into the board menu.
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
        ],
      ),
    );
    final actions = <Widget>[
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
    final saved = savedFilter == null
        ? null
        : scope.state.maybe('views', savedFilter!);
    final filters = ActionChip(
      key: const Key('board-filters'),
      avatar: Icon(
        saved == null ? Icons.filter_alt_outlined : Icons.filter_alt,
        size: 18,
      ),
      label: Text(saved?.str('title') ?? tr(context, 'Filters', 'Bộ lọc')),
      onPressed: _filters,
    );
    final due = FilterChip(
      key: const Key('filter-due-soon'),
      selected: dueSoon,
      visualDensity: VisualDensity.compact,
      label: Text(tr(context, 'Due in 3 days', 'Hạn trong 3 ngày')),
      onSelected: (v) => setState(() => dueSoon = v),
    );
    final stripShown = showStrip && hasCategories;
    String nameOf(String key) => categoryName(
      context,
      key == CategoryStrip.uncategorisedKey ? null : s.maybe('categories', key),
    );
    final chips = <Widget>[
      for (final key in focus)
        InputChip(
          label: Text(nameOf(key)),
          onDeleted: () => _toggle(key),
          deleteButtonTooltipMessage: tr(
            context,
            'Stop showing only this',
            'Bỏ lọc nhóm này',
          ),
        ),
    ];
    final focusName = focus.isEmpty ? null : focus.map(nameOf).join(', ');
    final time = TimelineChip(scope: scope, board: widget.board);
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
          onSelect: _toggle,
          onEdit: () => editCategories(context, scope, widget.board),
          trailing: [time, filters, due],
        ),
        const SizedBox(height: 8),
      ],
      if (focusName != null)
        FocusBar(name: focusName, onClear: () => setState(() => focus = {})),
      if (unit != null && window != null) ...[
        TimelineBar(
          unit: unit,
          window: window!,
          now: now,
          onWindow: (w) => setState(() => window = w),
        ),
        if (past)
          Builder(
            builder: (context) {
              final ids = [
                for (final t in openIn(
                  s,
                  widget.board,
                  window!,
                  shows: _inFocus,
                ))
                  t.id,
              ];
              return CarryLine(
                unit: unit,
                count: ids.length,
                pastPeriod: true,
                onCarry: () => _carry(ids, unit),
              );
            },
          )
        else if (kind == PeriodKind.current)
          Builder(
            builder: (context) {
              final ids = [
                for (final t in openBefore(
                  s,
                  widget.board,
                  window!.first,
                  shows: _inFocus,
                ))
                  t.id,
              ];
              return CarryLine(
                unit: unit,
                count: ids.length,
                pastPeriod: false,
                onCarry: () => _carry(ids, unit),
              );
            },
          ),
      ] else
        BacklogLine(scope: scope, board: widget.board, shows: _inFocus),
      if (!stripShown)
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in [...chips, time, filters, due])
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
      child: KanbanView(
        key: short ? kanbanShort : kanban,
        state: s,
        board: widget.board,
        now: now,
        detailed: detailed,
        columnColor: ground.column,
        filter: filter,
        // A period gone by is read-only: cards open to read, subtasks may
        // still be ticked, and unfinished ones can be brought forward.
        actions: past
            ? KanbanActions(
                open: (card) => _openPast(card, unit),
                tick: _tick,
                carry: (card) => _carry([card.id], unit),
                carryLabel: tr(
                  context,
                  'Bring ${toThisPeriod(context, unit!)}',
                  'Đem ${toThisPeriod(context, unit)}',
                ),
              )
            : KanbanActions(
                open: (card) => openCard(context, scope, card.id),
                move: _move,
                add: _add,
                tick: _tick,
                cardMenu: (card) =>
                    cardMenu(context, scope, card.id, onMoved: _move),
                columnMenu: (column) => columnMenu(context, scope, column.id),
                addColumn: () => addColumnDialog(context, scope, widget.board),
                fromTemplate: (column) =>
                    addFromCardTemplate(context, scope, column),
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
                  onCover: () => pickBoardCover(context, scope, widget.board),
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
