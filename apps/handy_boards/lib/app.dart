import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'controller.dart';
import 'scope.dart';
import 'ui/form.dart';
import 'ui/labels.dart';
import 'features/editors.dart';
import 'features/board_views.dart';
import 'features/task_detail.dart';
import 'features/task_table.dart';
import 'features/paged_tasks.dart';
import 'data/store.dart';
import 'features/planner.dart';
import 'features/portability.dart';
import 'features/study.dart';
import 'features/advanced.dart';
import 'platform/reminders.dart';
import 'platform/share_inbox.dart';
import 'platform/home_surface.dart';

const boardsBrand = HandyBrand.boards;

class BoardsApp extends StatefulWidget {
  final BoardsController? controller;
  final DateTime Function()? clock;
  const BoardsApp({super.key, this.controller, this.clock});
  @override
  State<BoardsApp> createState() => _BoardsAppState();
}

class _BoardsAppState extends State<BoardsApp> with WidgetsBindingObserver {
  bool reconciling = false;
  Future<void> reconcile() async {
    if (widget.controller != null || reconciling || c.state == null) return;
    reconciling = true;
    try {
      await c.change((s) {
        var next = reconcileRecurrences(s, DateTime.now());
        if (c.advancedEnabled) next = reconcileOpenRules(next, DateTime.now());
        return next;
      }, history: false);
    } catch (e) {
      c.adapterWarning = e.toString();
    } finally {
      reconciling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reconcile());
  }

  final navigator = GlobalKey<NavigatorState>();
  final homeSurface = BoardsHomeSurface();
  late final c = widget.controller ?? BoardsController();
  late final reminderPort = BoardsReminders(
    onTask: (id) {
      if (mounted && c.state?.maybe('tasks', id) != null)
        navigator.currentState?.pushNamed('/task/$id');
    },
  );
  late final scope = BoardsScope(
    c,
    clock: widget.clock,
    reminders: reminderPort,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null)
      c.afterCommit = (s) async {
        await Future.wait<void>([
          reminderPort.sync(s),
          homeSurface.publish(
            s,
            DateTime.now(),
            vi:
                s.preferences['locale'] == 'vi' ||
                ((s.preferences['locale'] ?? 'system') == 'system' &&
                    WidgetsBinding
                            .instance
                            .platformDispatcher
                            .locale
                            .languageCode ==
                        'vi'),
          ),
        ]);
      };
    if (c.state == null) c.load().then((_) => reconcile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeSurface.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => HandyApp(
      app: 'boards',
      navigatorKey: navigator,
      title: 'Handy Boards',
      // Magenta: clear of the banned violet and indigo and of the other apps.
      accent: const Color(0xffa61c8e),
      brand: boardsBrand,
      locale: c.state?.preferences['locale'] ?? 'system',
      theme: c.state?.preferences['theme'] ?? 'system',
      adsVisible: c.adsVisible,
      navigatorObservers: [_BoardsPrivacyObserver(c)],
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/task/') == true) {
          final id = settings.name!.substring(6);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => c.state == null
                ? const Center(child: CircularProgressIndicator())
                : TaskDetail(scope: scope, id: id),
          );
        }
        return null;
      },
      home: _Home(scope, homeSurface),
    ),
  );
}

class _Home extends StatefulWidget {
  final BoardsScope scope;
  final BoardsHomeSurface homeSurface;
  const _Home(this.scope, this.homeSurface);
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  bool openRulesChecked = false;
  final inbox = BoardsShareInbox();
  List<BoardsShare> incoming = [];
  bool shareError = false;
  Uri? pendingHomeLink;
  bool openingHomeLink = false;
  @override
  void initState() {
    super.initState();
    inbox.listen(refreshShares);
    refreshShares();
    widget.homeSurface.listen((uri) {
      if (uri.scheme != 'handy-boards' ||
          !['today', 'capture', 'task'].contains(uri.host))
        return;
      pendingHomeLink = uri;
      if (mounted) setState(() {});
    });
  }

  Future<void> openHomeLink(Uri uri) async {
    if (!mounted) return;
    if (uri.host == 'today') {
      setState(() => tab = 1);
      return;
    }
    if (uri.host == 'task') {
      final id = uri.queryParameters['id'];
      if (id != null && scope.state.maybe('tasks', id) != null)
        await Navigator.of(context).pushNamed('/task/$id');
      return;
    }
    if (uri.host == 'capture') {
      if (scope.state.rows('boards').isEmpty) {
        await editBoard(context, scope);
        return;
      }
      final id = board ?? scope.state.rows('boards').first.id;
      await scope.run(context, () => quickTask(context, scope, id));
    }
  }

  Future<void> refreshShares() async {
    try {
      final rows = await inbox.pending();
      if (mounted)
        setState(() {
          incoming = rows;
          shareError = false;
        });
    } catch (_) {
      if (mounted) setState(() => shareError = true);
    }
  }

  String? board, workspace;
  int tab = 0;
  String view = 'categories', search = '', sort = 'manual', listGroup = 'flat';
  int limit = 100;
  final selected = <String>{};
  Json filters = {};
  final searchInput = TextEditingController();
  final searchFocus = FocusNode();
  Timer? searchTimer;
  BoardsScope get scope => widget.scope;
  @override
  void dispose() {
    searchInput.dispose();
    searchFocus.dispose();
    searchTimer?.cancel();
    inbox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = scope.controller, s = c.state;
    if (s != null && pendingHomeLink != null && !openingHomeLink) {
      openingHomeLink = true;
      final uri = pendingHomeLink!;
      pendingHomeLink = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await openHomeLink(uri);
        } finally {
          if (mounted) setState(() => openingHomeLink = false);
        }
      });
    }
    c.advancedEnabled = boardsPro(context);
    if (c.advancedEnabled && !openRulesChecked && s != null) {
      openRulesChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          scope.run(
            context,
            () => c.change(
              (s) => reconcileOpenRules(s, scope.clock()),
              history: false,
            ),
          );
      });
    }
    scope.adsAllowed = tab == 3;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          c.adsVisible.value != (tab == 3))
        c.adsVisible.value = tab == 3;
    });
    if (s == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Handy Boards')),
        body: Center(
          child: c.error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        context,
                        'Could not open local data. Nothing was reset.',
                        'Không mở được dữ liệu cục bộ. Không xóa dữ liệu.',
                      ),
                    ),
                    SelectableText(boardsError(context, c.error!)),
                    TextButton(
                      onPressed: c.load,
                      child: Text(tr(context, 'Retry', 'Thử lại')),
                    ),
                  ],
                ),
        ),
      );
    if (s.rows('boards').isEmpty)
      return Scaffold(
        appBar: AppBar(title: const Text('Handy Boards')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      'Make room for your work',
                      'Sắp xếp việc theo cách của bạn',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      context,
                      'Start blank or choose a template. Categories can be subjects, clients or anything you need. Your tasks stay on this device.',
                      'Bắt đầu trống hoặc chọn mẫu. Nhóm có thể là môn học, khách hàng hay bất cứ điều gì bạn cần. Task được lưu trên thiết bị.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('boards-create'),
                    onPressed: () =>
                        scope.run(context, () => editBoard(context, scope)),
                    icon: const Icon(Icons.add),
                    label: Text(tr(context, 'Create a board', 'Tạo bảng')),
                  ),
                  TextButton(
                    onPressed: () => scope.run(
                      context,
                      () => importBoards(context, scope, null),
                    ),
                    child: Text(
                      tr(context, 'Restore a backup', 'Khôi phục sao lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    final boards = s
        .rows('boards')
        .where((b) => workspace == null || b.str('workspace') == workspace)
        .toList();
    if (board == null ||
        s.maybe('boards', board) == null ||
        !boards.any((b) => b.id == board))
      board = boards.firstOrNull?.id;
    final current = s.maybe('boards', board),
        tasks =
            (tab == 0 &&
                ['list', 'table'].contains(view) &&
                c.store is BoardsPagedStore)
            ? <BoardRecord>[]
            : queryTasks(
                s,
                board: board,
                search: search,
                sort: sort,
                filter: filters,
              );
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final destinations = [
      (Icons.dashboard_outlined, 'Boards', 'Bảng'),
      (Icons.today_outlined, 'Today', 'Hôm nay'),
      (Icons.calendar_month_outlined, 'Calendar', 'Lịch'),
      (Icons.insights_outlined, 'Insights', 'Thống kê'),
    ];
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _Capture(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _Search(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const _Capture(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const _Search(),
      },
      child: Actions(
        actions: {
          _Capture: CallbackAction<_Capture>(
            onInvoke: (_) {
              if (board != null)
                scope.run(context, () => quickTask(context, scope, board!));
              return null;
            },
          ),
          _Search: CallbackAction<_Search>(
            onInvoke: (_) {
              searchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Handy Boards'),
            actions: [
              IconButton(
                tooltip: tr(context, 'Quick capture', 'Thêm nhanh'),
                icon: const Icon(Icons.add),
                onPressed: board == null
                    ? null
                    : () => scope.run(
                        context,
                        () => quickTask(context, scope, board!),
                      ),
              ),
              IconButton(
                tooltip: tr(context, 'Undo', 'Hoàn tác'),
                icon: const Icon(Icons.undo),
                onPressed: c.canUndo ? () => scope.run(context, c.undo) : null,
              ),
              PopupMenuButton<String>(
                tooltip: tr(context, 'More actions', 'Thao tác khác'),
                onSelected: (v) => scope.run(context, () async {
                  switch (v) {
                    case 'board':
                      await editBoard(context, scope);
                    case 'edit':
                      if (board != null)
                        await editBoard(context, scope, id: board);
                    case 'import':
                      await importBoards(context, scope, board);
                    case 'export':
                      await exportBoards(context, scope, board);
                    case 'settings':
                      if (context.mounted) await _settings(context);
                    case 'trash':
                      if (context.mounted) await _trash(context);
                    case 'study':
                      if (board != null && context.mounted)
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                StudyPage(scope: scope, board: board!),
                          ),
                        );
                    case 'advanced':
                      if (board != null && context.mounted)
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                AdvancedPage(scope: scope, board: board!),
                          ),
                        );
                    case 'workspace':
                      await boardForm(
                        context,
                        tr(context, 'New workspace', 'Không gian mới'),
                        [const BoardField('title', 'Name', 'Tên')],
                        {'title': ''},
                        (v) async {
                          await c.change(
                            (s) => s.put(
                              'workspaces',
                              BoardRecord({'id': newId(), 'title': v['title']}),
                            ),
                          );
                        },
                      );
                    case 'filters':
                      if (board != null && context.mounted)
                        await _filters(context);
                    case 'redo':
                      if (c.canRedo) await c.redo();
                    case 'paste':
                      final clip = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (clip?.text?.isNotEmpty == true &&
                          context.mounted &&
                          await confirmBoards(
                            context,
                            tr(
                              context,
                              'Capture clipboard lines?',
                              'Lưu các dòng clipboard?',
                            ),
                            tr(
                              context,
                              'Each nonempty line becomes one task in the selected board.',
                              'Mỗi dòng không trống thành một task trong bảng đã chọn.',
                            ),
                          ))
                        await c.change(
                          (s) => importLines(s, board!, clip!.text!),
                        );
                  }
                }),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'redo',
                    enabled: c.canRedo,
                    child: Text(tr(context, 'Redo', 'Làm lại')),
                  ),
                  PopupMenuItem(
                    value: 'workspace',
                    child: Text(tr(context, 'New workspace', 'Không gian mới')),
                  ),
                  PopupMenuItem(
                    value: 'filters',
                    child: Text(tr(context, 'Task filters', 'Bộ lọc task')),
                  ),
                  PopupMenuItem(
                    value: 'study',
                    child: Text(
                      tr(
                        context,
                        'Optional Study planner',
                        'Kế hoạch học tập tùy chọn',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'advanced',
                    child: Text(
                      tr(context, 'Advanced planning', 'Kế hoạch nâng cao'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'paste',
                    child: Text(
                      tr(
                        context,
                        'Capture clipboard lines',
                        'Lưu các dòng clipboard',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'board',
                    child: Text(tr(context, 'New board', 'Bảng mới')),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(tr(context, 'Edit board', 'Sửa bảng')),
                  ),
                  PopupMenuItem(
                    value: 'import',
                    child: Text(
                      tr(context, 'Import / Restore', 'Nhập / Khôi phục'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text(
                      tr(context, 'Export / Backup', 'Xuất / Sao lưu'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'trash',
                    child: Text(
                      tr(context, 'Trash / Archived', 'Thùng rác / Lưu trữ'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Text(tr(context, 'Settings', 'Cài đặt')),
                  ),
                ],
              ),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                SizedBox(
                  width: 228,
                  child: Column(
                    children: [
                      Padding(
                        // On the sidebar's own edge, with the rows below it.
                        padding: const EdgeInsets.symmetric(
                          horizontal: HandySpace.l,
                        ),
                        child: DropdownButton<String?>(
                          value: workspace,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(
                                tr(context, 'All workspaces', 'Mọi không gian'),
                              ),
                            ),
                            for (final w in s.rows('workspaces'))
                              DropdownMenuItem(
                                value: w.id,
                                child: Text(w.str('title')),
                              ),
                          ],
                          onChanged: (v) => setState(() => workspace = v),
                        ),
                      ),
                      for (var i = 0; i < destinations.length; i++)
                        ListTile(
                          selected: tab == i,
                          leading: Icon(destinations[i].$1, size: 20),
                          title: Text(
                            tr(context, destinations[i].$2, destinations[i].$3),
                          ),
                          onTap: () => setState(() => tab = i),
                        ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final b in boards)
                              ListTile(
                                selected: board == b.id,
                                title: Text(
                                  b.str('title'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => setState(() {
                                  board = b.id;
                                  tab = 0;
                                  selected.clear();
                                }),
                              ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(tr(context, 'New board', 'Bảng mới')),
                        onTap: () =>
                            scope.run(context, () => editBoard(context, scope)),
                      ),
                    ],
                  ),
                ),
              if (wide) const VerticalDivider(width: 1),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!wide)
                        DropdownButton<String>(
                          value: board,
                          isExpanded: true,
                          items: [
                            for (final b in boards)
                              DropdownMenuItem(
                                value: b.id,
                                child: Text(
                                  b.str('title'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            board = v;
                            selected.clear();
                          }),
                        ),
                      if (incoming.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => scope.run(
                            context,
                            () => _receive(context, incoming.first),
                          ),
                          icon: const Icon(Icons.inbox_outlined),
                          label: Text(
                            '${incoming.length} ${tr(context, 'shared captures to review', 'nội dung chia sẻ cần kiểm tra')}',
                          ),
                        ),
                      if (shareError)
                        TextButton(
                          onPressed: refreshShares,
                          child: Text(
                            tr(
                              context,
                              'Shared inbox unavailable; retry',
                              'Chưa đọc được hộp chia sẻ; thử lại',
                            ),
                          ),
                        ),
                      if (wide && current != null)
                        Text(
                          current.str('title'),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      if (c.adapterWarning != null)
                        Text(
                          '${tr(context, 'Saved; system reminder sync needs attention', 'Đã lưu; cần kiểm tra đồng bộ nhắc hệ thống')}: ${boardsError(context, c.adapterWarning!)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (tab == 0) ...[
                        TextField(
                          controller: searchInput,
                          focusNode: searchFocus,
                          decoration: InputDecoration(
                            labelText: tr(
                              context,
                              'Search tasks, notes and tags',
                              'Tìm task, ghi chú và tag',
                            ),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (v) {
                            searchTimer?.cancel();
                            searchTimer = Timer(
                              const Duration(milliseconds: 250),
                              () {
                                if (mounted)
                                  setState(() {
                                    search = v;
                                    limit = 100;
                                  });
                              },
                            );
                          },
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (id, en, vi) in [
                                ('categories', 'Categories', 'Nhóm'),
                                ('kanban', 'Kanban', 'Kanban'),
                                ('list', 'List', 'Danh sách'),
                                ('table', 'Table', 'Bảng dữ liệu'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 8,
                                    top: 8,
                                    bottom: 8,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(tr(context, en, vi)),
                                    selected: view == id,
                                    onSelected: (_) =>
                                        setState(() => view = id),
                                  ),
                                ),
                              TextButton.icon(
                                onPressed: board == null
                                    ? null
                                    : () => scope.run(
                                        context,
                                        () => quickTask(context, scope, board!),
                                      ),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  tr(context, 'Quick add', 'Thêm nhanh'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Expanded(
                        child: board == null
                            ? const SizedBox()
                            : switch (tab) {
                                1 => TodayPage(scope: scope, board: board),
                                2 => BoardsCalendar(scope: scope, board: board),
                                3 => InsightsPage(scope: scope, board: board),
                                _ => switch (view) {
                                  'categories' => CategoryBoard(
                                    key: ValueKey('categories-$board'),
                                    scope: scope,
                                    board: board!,
                                    tasks: tasks,
                                  ),
                                  'kanban' => KanbanBoard(
                                    scope: scope,
                                    board: board!,
                                    tasks: tasks,
                                  ),
                                  _ => _taskList(context, tasks),
                                },
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(
                        icon: Icon(d.$1),
                        label: tr(context, d.$2, d.$3),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _taskList(BuildContext context, List<BoardRecord> tasks) {
    if (scope.controller.store is BoardsPagedStore)
      return PagedTasks(
        scope: scope,
        board: board!,
        search: search,
        sort: sort,
        group: listGroup,
        filter: filters,
        table: view == 'table',
        selected: selected,
        onSort: (v) => setState(() => sort = v),
        onGroup: (v) => setState(() => listGroup = v),
        select: (id, v) =>
            setState(() => v ? selected.add(id) : selected.remove(id)),
        bulk: () => scope.run(context, () => _bulk(context)),
        clearSelection: () => setState(selected.clear),
      );
    final top = tasks.where((t) => t.data['parent'] == null).toList();
    final visible = top.take(limit).toList(), listRows = <Object>[];
    String group(BoardRecord t) => switch (listGroup) {
      'category' =>
        scope.state.maybe('categories', t.data['category'])?.str('title') ??
            tr(context, 'Uncategorized', 'Chưa phân nhóm'),
      'status' => scope.state.get('statuses', t.str('status')).str('title'),
      'date' =>
        t.data['due'] == null
            ? tr(context, 'No deadline', 'Chưa có hạn')
            : deadlineDay(
                object(t.data['due']),
                scope.state.get('boards', t.str('board')).str('zone'),
              ),
      _ => '',
    };
    if (listGroup == 'flat') {
      listRows.addAll(visible);
    } else {
      final groups = <String, List<BoardRecord>>{};
      for (final t in visible) (groups[group(t)] ??= []).add(t);
      for (final entry in groups.entries) {
        listRows.add('${entry.key} · ${entry.value.length}');
        listRows.addAll(entry.value);
      }
    }
    return Column(
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${top.length} ${tr(context, 'tasks', 'task')}'),
            DropdownButton<String>(
              value: sort,
              items: [
                for (final (id, en, vi) in [
                  ('manual', 'Manual', 'Thủ công'),
                  ('due', 'Due date', 'Hạn'),
                  ('priority', 'Priority', 'Ưu tiên'),
                  ('title', 'Title', 'Tên'),
                ])
                  DropdownMenuItem(value: id, child: Text(tr(context, en, vi))),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
            if (view == 'list')
              DropdownButton<String>(
                value: listGroup,
                items: [
                  for (final (id, en, vi) in [
                    ('flat', 'Ungrouped', 'Không nhóm'),
                    ('category', 'By category', 'Theo nhóm'),
                    ('status', 'By status', 'Theo trạng thái'),
                    ('date', 'By deadline', 'Theo hạn'),
                  ])
                    DropdownMenuItem(
                      value: id,
                      child: Text(tr(context, en, vi)),
                    ),
                ],
                onChanged: (v) => setState(() => listGroup = v!),
              ),
            if (selected.isNotEmpty) ...[
              Text('${selected.length} ${tr(context, 'selected', 'đã chọn')}'),
              TextButton(
                onPressed: () => scope.run(context, () => _bulk(context)),
                child: Text(tr(context, 'Bulk edit', 'Sửa hàng loạt')),
              ),
              IconButton(
                tooltip: tr(context, 'Clear selection', 'Bỏ chọn'),
                onPressed: () => setState(selected.clear),
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
        Expanded(
          child: view == 'table'
              ? TaskTable(
                  scope: scope,
                  board: board!,
                  tasks: top.take(limit).toList(),
                  selected: selected,
                  select: (id, v) => setState(
                    () => v ? selected.add(id) : selected.remove(id),
                  ),
                )
              : ListView.builder(
                  itemCount: listRows.length,
                  itemBuilder: (context, i) {
                    final row = listRows[i];
                    if (row is String)
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          row,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    final task = row as BoardRecord;
                    return TaskRow(
                      scope: scope,
                      task: task,
                      selected: selected.contains(task.id),
                      onSelected: (v) => setState(
                        () => v
                            ? selected.add(task.id)
                            : selected.remove(task.id),
                      ),
                    );
                  },
                ),
        ),
        if (top.length > limit)
          TextButton(
            onPressed: () => setState(() => limit += 100),
            child: Text(
              '${tr(context, 'Load more', 'Xem thêm')} (${limit.clamp(0, top.length)}/${top.length})',
            ),
          ),
      ],
    );
  }

  Future<void> _receive(BuildContext context, BoardsShare item) async {
    final existing = scope.state
        .rows('tasks')
        .where((t) => t.str('shareDelivery') == item.id)
        .firstOrNull;
    if (existing != null) {
      await inbox.acknowledge(item.id);
      await refreshShares();
      return;
    }
    await boardForm(
      context,
      tr(context, 'Review shared capture', 'Kiểm tra nội dung chia sẻ'),
      [
        const BoardField('title', 'Task title', 'Tên task'),
        const BoardField(
          'notes',
          'Shared text / link (no automatic fetch)',
          'Văn bản / link (không tự tải mạng)',
          kind: 'note',
          optional: true,
        ),
        BoardField(
          'board',
          'Destination board',
          'Bảng đích',
          kind: 'select',
          options: {
            for (final b in scope.state.rows('boards')) b.id: b.str('title'),
          },
        ),
      ],
      {
        'title':
            (item.title?.isNotEmpty == true
                    ? item.title!
                    : item.text.split('\n').first)
                .characters
                .take(1000)
                .toString(),
        'notes': item.text,
        'board': board,
      },
      (v) async {
        await scope.controller.change(
          (s) => saveTask(
            s,
            newTask(
              s,
              v['board'],
              v['title'],
            ).copy({'notes': v['notes'], 'shareDelivery': item.id}),
            now: scope.clock(),
          ),
        );
        await inbox.acknowledge(item.id);
        await refreshShares();
      },
      footer: [
        Text(
          tr(
            context,
            'Cancel keeps the delivery queued. Acknowledged only after local save commits.',
            'Hủy giữ nội dung trong hàng đợi. Chỉ xác nhận đã nhận sau khi lưu cục bộ thành công.',
          ),
        ),
      ],
    );
  }

  Future<void> _filters(BuildContext context) => boardForm(
    context,
    tr(context, 'Filter tasks', 'Lọc task'),
    [
      BoardField(
        'category',
        'Category',
        'Nhóm',
        kind: 'select',
        options: {
          'any': tr(context, 'Any', 'Bất kỳ'),
          '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
          ...choices(scope.state, 'categories', board!),
        },
      ),
      BoardField(
        'status',
        'Status',
        'Trạng thái',
        kind: 'select',
        options: {
          'any': tr(context, 'Any', 'Bất kỳ'),
          ...choices(scope.state, 'statuses', board!),
        },
      ),
      BoardField(
        'priority',
        'Priority',
        'Ưu tiên',
        kind: 'select',
        options: {
          'any': tr(context, 'Any', 'Bất kỳ'),
          '0': tr(context, 'Low', 'Thấp'),
          '1': tr(context, 'Normal', 'Thường'),
          '2': tr(context, 'High', 'Cao'),
          '3': tr(context, 'Urgent', 'Khẩn'),
        },
      ),
      BoardField(
        'tag',
        'Tag',
        'Tag',
        kind: 'select',
        options: {
          'any': tr(context, 'Any', 'Bất kỳ'),
          ...choices(scope.state, 'tags', board!),
        },
      ),
      const BoardField(
        'dueFrom',
        'Due from',
        'Hạn từ',
        kind: 'date',
        optional: true,
      ),
      const BoardField(
        'dueTo',
        'Due through',
        'Hạn đến',
        kind: 'date',
        optional: true,
      ),
      const BoardField(
        'blocked',
        'Blocked only',
        'Chỉ task bị chặn',
        kind: 'bool',
        optional: true,
      ),
      if (filters['assignee'] != null || boardsUseAssignee(scope.state))
        const BoardField(
          'assignee',
          'Assignee label (exact; empty = any)',
          'Nhãn phụ trách (chính xác; trống = bất kỳ)',
          optional: true,
        ),
      const BoardField(
        'estimateMin',
        'Minimum estimate (minutes)',
        'Ước lượng tối thiểu (phút)',
        kind: 'number',
        optional: true,
      ),
      const BoardField(
        'estimateMax',
        'Maximum estimate (minutes)',
        'Ước lượng tối đa (phút)',
        kind: 'number',
        optional: true,
      ),
      BoardField(
        'hasReminder',
        'Reminder',
        'Lời nhắc',
        kind: 'select',
        options: {
          'any': tr(context, 'Any', 'Bất kỳ'),
          'yes': tr(context, 'Enabled reminder', 'Có lời nhắc bật'),
          'no': tr(context, 'No enabled reminder', 'Không có lời nhắc bật'),
        },
      ),
      BoardField(
        'archived',
        'Archive',
        'Lưu trữ',
        kind: 'select',
        options: {
          'active': tr(context, 'Active only', 'Đang dùng'),
          'archived': tr(context, 'Archived only', 'Đã lưu trữ'),
        },
      ),
      const BoardField(
        'reset',
        'Clear all filters',
        'Xóa mọi bộ lọc',
        kind: 'bool',
        optional: true,
      ),
    ],
    {
      'category': filters.containsKey('category')
          ? filters['category'] ?? ''
          : 'any',
      'status': filters['status'] ?? 'any',
      'priority': filters['priority']?.toString() ?? 'any',
      'tag': filters['tag'] ?? 'any',
      'dueFrom': filters['dueFrom'],
      'dueTo': filters['dueTo'],
      'blocked': filters['blocked'] == true,
      'reset': false,
      'assignee': filters['assignee'] ?? '',
      'estimateMin': filters['estimateMin']?.toString() ?? '',
      'estimateMax': filters['estimateMax']?.toString() ?? '',
      'hasReminder': filters['hasReminder'] == null
          ? 'any'
          : filters['hasReminder'] == true
          ? 'yes'
          : 'no',
      'archived': filters['archived'] == true ? 'archived' : 'active',
    },
    (v) async {
      if (v['dueFrom'] != null &&
          v['dueTo'] != null &&
          (v['dueFrom'] as String).compareTo(v['dueTo']) > 0)
        throw const FormatException('Invalid date range');
      final min = (v['estimateMin'] as String).isEmpty
              ? null
              : int.parse(v['estimateMin']),
          max = (v['estimateMax'] as String).isEmpty
              ? null
              : int.parse(v['estimateMax']);
      if (min != null && (min < 0 || min > 525600) ||
          max != null && (max < 0 || max > 525600) ||
          min != null && max != null && min > max)
        throw const FormatException('Invalid estimate range');
      if (mounted)
        setState(
          () => filters = v['reset'] == true
              ? {}
              : {
                  if (v['category'] != 'any')
                    'category': v['category'] == '' ? null : v['category'],
                  if (v['status'] != 'any') 'status': v['status'],
                  if (v['priority'] != 'any')
                    'priority': int.parse(v['priority']),
                  if (v['tag'] != 'any') 'tag': v['tag'],
                  if (v['dueFrom'] != null) 'dueFrom': v['dueFrom'],
                  if (v['dueTo'] != null) 'dueTo': v['dueTo'],
                  if (v['blocked'] == true) 'blocked': true,
                  if (v['assignee'] != '') 'assignee': v['assignee'],
                  if (min != null) 'estimateMin': min,
                  if (max != null) 'estimateMax': max,
                  if (v['hasReminder'] != 'any')
                    'hasReminder': v['hasReminder'] == 'yes',
                  if (v['archived'] == 'archived') 'archived': true,
                },
        );
    },
  );
  Future<void> _bulk(BuildContext context) async {
    final ids = Set<String>.of(selected);
    await boardForm(
      context,
      tr(context, 'Bulk edit', 'Sửa hàng loạt'),
      [
        BoardField(
          'action',
          'Action',
          'Thao tác',
          kind: 'select',
          options: {
            'edit': tr(context, 'Edit properties', 'Sửa thuộc tính'),
            'archive': tr(context, 'Archive', 'Lưu trữ'),
            'duplicate': tr(
              context,
              'Duplicate subtrees (no attachments/history)',
              'Nhân bản task con (không tệp/lịch sử)',
            ),
            'move': tr(
              context,
              'Move to another board / Uncategorized',
              'Chuyển bảng khác / Chưa phân nhóm',
            ),
            'export': tr(context, 'Export selected CSV', 'Xuất CSV đã chọn'),
          },
        ),
        BoardField(
          'destination',
          'Move destination board',
          'Bảng đích khi chuyển',
          kind: 'select',
          options: {
            for (final b in scope.state.rows('boards')) b.id: b.str('title'),
          },
        ),
        BoardField(
          'priority',
          'Priority',
          'Ưu tiên',
          kind: 'select',
          options: {
            'keep': tr(context, 'Keep unchanged', 'Giữ nguyên'),
            '0': tr(context, 'Low', 'Thấp'),
            '1': tr(context, 'Normal', 'Thường'),
            '2': tr(context, 'High', 'Cao'),
            '3': tr(context, 'Urgent', 'Khẩn'),
          },
        ),
        const BoardField(
          'tags',
          'Replace tags (comma separated; empty = unchanged)',
          'Thay tag (ngăn dấu phẩy; trống = giữ nguyên)',
          optional: true,
        ),
        const BoardField(
          'clearDue',
          'Clear deadlines',
          'Bỏ hạn',
          kind: 'bool',
          optional: true,
        ),
        BoardField(
          'status',
          'Status',
          'Trạng thái',
          kind: 'select',
          options: {
            '': tr(context, 'Keep unchanged', 'Giữ nguyên'),
            ...choices(scope.state, 'statuses', board!),
          },
        ),
        BoardField(
          'category',
          'Category',
          'Nhóm',
          kind: 'select',
          options: {
            'keep': tr(context, 'Keep unchanged', 'Giữ nguyên'),
            '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
            ...choices(scope.state, 'categories', board!),
          },
        ),
        const BoardField(
          'due',
          'Due date',
          'Hạn',
          kind: 'date',
          optional: true,
        ),
        const BoardField(
          'trash',
          'Move selected tasks to trash',
          'Chuyển các task đã chọn vào thùng rác',
          kind: 'bool',
          optional: true,
        ),
      ],
      {
        'action': 'edit',
        'destination': board,
        'priority': 'keep',
        'tags': '',
        'clearDue': false,
        'status': '',
        'category': 'keep',
        'due': null,
        'trash': false,
      },
      (v) async {
        if (v['action'] == 'export') {
          if (!await confirmBoards(
            context,
            tr(
              context,
              'Export selected private tasks?',
              'Xuất các task riêng tư đã chọn?',
            ),
            '${ids.length} ${tr(context, 'selected roots and descendants; CSV requires existing dictionaries on restore', 'task gốc và task con; CSV cần dữ liệu bảng gốc khi khôi phục')}',
          ))
            return;
          final result = await scope.files.exportText(
            'boards-selected.csv',
            exportTaskCsv(
              scope.state,
              board!,
              taskIds: taskDescendants(scope.state, ids),
            ),
          );
          if (result == null)
            throw const FormatException('Export cancelled; no data changed');
          return;
        }
        if (v['action'] == 'move' &&
            !await confirmBoards(
              context,
              tr(
                context,
                'Move selected task subtrees?',
                'Chuyển các cây task đã chọn?',
              ),
              tr(
                context,
                'Destination category will be Uncategorized. Status resets on another board; tags/custom values clear. Dependencies must move together.',
                'Nhóm đích là Chưa phân nhóm. Khi khác bảng: đổi status, bỏ tag/giá trị tùy chỉnh. Các liên kết phụ thuộc phải chuyển cùng.',
              ),
            ))
          return;
        if (!context.mounted) return;
        if (v['trash'] == true &&
            !await confirmBoards(
              context,
              tr(
                context,
                'Trash selected tasks?',
                'Chuyển các task đã chọn vào thùng rác?',
              ),
              '${ids.length} tasks',
            ))
          return;
        await scope.controller.change((s) {
          var next = s;
          if (v['trash'] == true) return trashTasks(s, ids);
          if (v['action'] == 'move')
            return moveTasks(s, ids, v['destination'], now: scope.clock());
          if (v['action'] == 'duplicate') {
            for (final id in ids)
              next = duplicateTask(next, id, now: scope.clock());
            return next;
          }
          for (final id in ids) {
            var t = next.get('tasks', id);
            if (v['action'] == 'archive') {
              next = next.put('tasks', t.copy({'archived': true}));
              continue;
            }
            if (v['priority'] != 'keep')
              t = t.copy({'priority': int.parse(v['priority'])});
            if (v['status'] != '') t = t.copy({'status': v['status']});
            if (v['category'] != 'keep')
              t = t.copy({
                'category': v['category'] == '' ? null : v['category'],
              });
            if (v['due'] != null)
              t = t.copy({
                'due': {'kind': 'day', 'day': v['due']},
              });
            if (v['clearDue'] == true) t = t.copy({'due': null});
            next = saveTask(next, t, now: scope.clock());
            if ((v['tags'] as String).trim().isNotEmpty)
              next = assignTags(next, id, v['tags']);
          }
          return next;
        });
        if (mounted) setState(selected.clear);
      },
    );
  }

  Future<void> _settings(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => HandySettingsPage(
        appName: 'Handy Boards',
        theme: scope.state.preferences['theme'] ?? 'system',
        locale: scope.state.preferences['locale'] ?? 'system',
        onTheme: (v) => scope.controller.change(
          (s) => s.copy(preferences: {...s.preferences, 'theme': v}),
        ),
        onLocale: (v) => scope.controller.change(
          (s) => s.copy(preferences: {...s.preferences, 'locale': v}),
        ),
        sections: [
          const LifetimeSettings(),
          if (widget.homeSurface.supported)
            AnimatedBuilder(
              animation: scope.controller,
              builder: (context, _) => SwitchListTile(
                title: Text(
                  tr(
                    context,
                    'Show due task names on home widget',
                    'Hiện tên việc đến hạn trên widget',
                  ),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Visible outside the app. Updated on open/edit, not continuously in the background.',
                    'Hiện ngoài ứng dụng. Cập nhật khi mở/sửa; không chạy liên tục nền.',
                  ),
                ),
                value: scope.state.preferences['homeWidget'] == true,
                onChanged: (v) => scope.run(
                  context,
                  () => scope.controller.change(
                    (s) => s.copy(
                      preferences: {...s.preferences, 'homeWidget': v},
                    ),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: () => scope.run(
              context,
              () => boardForm(
                context,
                tr(context, 'Activity retention', 'Thời hạn giữ lịch sử'),
                [
                  const BoardField(
                    'days',
                    'Keep audit days (0 = unlimited; comments retained)',
                    'Số ngày giữ lịch sử (0 = không giới hạn; giữ bình luận)',
                    kind: 'number',
                  ),
                ],
                {'days': '${scope.state.preferences['historyDays'] ?? 0}'},
                (v) async {
                  final days = int.parse(v['days']);
                  if (days < 0 || days > 3650)
                    throw const FormatException('Days 0..3650');
                  await scope.controller.change(
                    (s) => retainActivity(s, days, scope.clock()).copy(
                      preferences: {...s.preferences, 'historyDays': days},
                    ),
                  );
                },
              ),
            ),
            child: Text(
              tr(
                context,
                'Manage local activity retention',
                'Quản lý thời hạn lịch sử cục bộ',
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => scope.run(context, () async {
              if (!scope.reminders.supported) {
                throw UnsupportedError(
                  tr(
                    context,
                    'Use the in-app reminder center on this platform',
                    'Dùng trung tâm nhắc trong app trên nền tảng này',
                  ),
                );
              }
              final allowed = await scope.reminders.request();
              if (!allowed)
                throw StateError(
                  'Notification permission denied; in-app reminders retained',
                );
              await scope.controller.change(
                (s) => s.copy(
                  preferences: {...s.preferences, 'notifications': true},
                ),
              );
            }),
            icon: const Icon(Icons.notifications_outlined),
            label: Text(
              tr(
                context,
                'Enable system reminders',
                'Bật thông báo nhắc hệ thống',
              ),
            ),
          ),
          TextButton(
            onPressed: () => scope.run(
              context,
              () => scope.controller.change(
                (s) => s.copy(
                  preferences: {...s.preferences, 'notifications': false},
                ),
              ),
            ),
            child: Text(
              tr(
                context,
                'Disable system reminders',
                'Tắt thông báo nhắc hệ thống',
              ),
            ),
          ),
          Text(
            tr(
              context,
              'Offline local library. Browser storage can be cleared by the browser; keep backups. No accounts or live collaboration.',
              'Thư viện cục bộ ngoại tuyến. Trình duyệt có thể xóa dữ liệu; nên giữ sao lưu. Không tài khoản hay cộng tác trực tuyến.',
            ),
          ),
        ],
        about: [
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Handy Boards',
            ),
            child: Text(
              tr(context, 'Open source licenses', 'Giấy phép nguồn mở'),
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _trash(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Trash / Archived', 'Thùng rác / Lưu trữ')),
        ),
        body: AnimatedBuilder(
          animation: scope.controller,
          builder: (context, _) {
            final rows = scope.state
                .rows('tasks')
                .where((t) => t.flag('trashed') || t.flag('archived'))
                .toList();
            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final t = rows[i];
                return ListTile(
                  title: Text(t.str('title')),
                  onTap: () => showTask(context, scope, t.id),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: tr(context, 'Restore', 'Khôi phục'),
                        icon: const Icon(Icons.restore),
                        onPressed: () => scope.run(
                          context,
                          () => scope.controller.change(
                            (s) => t.flag('trashed')
                                ? trashTasks(s, {t.id}, restore: true)
                                : s.put('tasks', t.copy({'archived': false})),
                          ),
                        ),
                      ),
                      if (t.flag('trashed'))
                        IconButton(
                          tooltip: tr(
                            context,
                            'Delete permanently',
                            'Xóa vĩnh viễn',
                          ),
                          icon: const Icon(Icons.delete_forever),
                          onPressed: () => scope.run(context, () async {
                            if (await confirmBoards(
                              context,
                              tr(
                                context,
                                'Delete permanently?',
                                'Xóa vĩnh viễn?',
                              ),
                              t.str('title'),
                            ))
                              await scope.controller.change(
                                (s) => permanentlyDelete(s, {
                                  t.id,
                                }, confirmed: true),
                              );
                          }),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

class _Capture extends Intent {
  const _Capture();
}

class _BoardsPrivacyObserver extends NavigatorObserver {
  final BoardsController c;
  _BoardsPrivacyObserver(this.c);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    c.adsVisible.value = false;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    c.adsVisible.value = false;
  }
}

class _Search extends Intent {
  const _Search();
}
