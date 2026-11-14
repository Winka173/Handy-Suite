import 'package:flutter/services.dart';
import '../design/theme.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/add_link.dart';
import '../bookmark/detail_view.dart';
import '../home/home_page.dart';
import '../home/dateline.dart';
import '../home/save_sheet.dart';
import '../home/quick_save.dart';
import '../library/batch_bar.dart';
import '../library/results_view.dart';
import '../scope.dart';
import '../view/library_view.dart';
import 'sidebar.dart';
import '../ui/header_band.dart';
import 'search_box.dart';
import 'share_issues.dart';

/// Save's frame. Wide: places, links, and the chosen link side by side.
/// Medium: places and links; a link opens as a page. Phone: the home.
class SaveShell extends StatefulWidget {
  final SaveScope scope;
  final VoidCallback onExport;
  const SaveShell({super.key, required this.scope, required this.onExport});
  @override
  State<SaveShell> createState() => _SaveShellState();
}

class _SaveShellState extends State<SaveShell> {
  final searchFocus = FocusNode();
  String? current;

  /// The Library overview fills the middle (the sidebar's first row).
  bool overview = true;

  /// The sidebar is shown (a computer or a tablet); remembered.
  late bool sideOpen = scope.c.preferences['sidebarCollapsed'] != true;

  void setSide(bool open) {
    setState(() => sideOpen = open);
    scope.c
        .update(
          (l) => l,
          prefs: {...scope.c.preferences, 'sidebarCollapsed': !open},
        )
        .catchError((_) {});
  }

  /// Every collection fills the middle (Collections › See all).
  bool collections = false;
  SaveScope get scope => widget.scope;

  @override
  void dispose() {
    searchFocus.dispose();
    super.dispose();
  }

  void details(Bookmark b, bool side) => side
      ? setState(() => current = b.id)
      : Navigator.pushNamed(context, '/bookmark/${b.id}');

  Future<void> add({bool clipboard = false}) async {
    final show = await addLinks(context, scope, fromClipboard: clipboard);
    if (show != null && mounted)
      details(show, MediaQuery.sizeOf(context).width >= 1100);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width >= 1100;
    final v = scope.view;
    // Just how much the library holds; what waits has its own cards.
    String counts() {
      final live = scope.library.bookmarks.where((b) => !b.isArchived).length;
      final n = formatFigure(context, '$live');
      return tr(context, live == 1 ? '1 item' : '$n items', '$n mục');
    }

    // Search from anywhere on a wide screen (the button on the band, Ctrl K
    // or Ctrl F): the overview steps into Everything so the box is there.
    void search() {
      if (overview || collections)
        setState(() {
          overview = false;
          collections = false;
          v.show(Place.all);
        });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => searchFocus.requestFocus(),
      );
    }

    void pick(Place p, [String? id]) => setState(() {
      current = null;
      overview = false;
      collections = false;
      v.show(p, id);
    });
    final keys = <ShortcutActivator, VoidCallback>{
      for (final meta in [false, true]) ...{
        SingleActivator(
          LogicalKeyboardKey.keyV,
          control: !meta,
          meta: meta,
        ): () =>
            add(clipboard: true),
        SingleActivator(LogicalKeyboardKey.keyN, control: !meta, meta: meta):
            add,
        for (final key in [LogicalKeyboardKey.keyF, LogicalKeyboardKey.keyK])
          SingleActivator(key, control: !meta, meta: meta): width < 700
              ? () => Navigator.pushNamed(context, '/find')
              : search,
      },
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          v.selecting ? v.clearSelection() : setState(() => current = null),
    };
    // The same Quick Save row as the phone's Home, on the header band.
    // Sized from the room beside the sidebar, so the library's name keeps
    // one line at every width.
    final room = width - (sideOpen ? 260 : 56) - 2 * HandySpace.xl;
    final saveRow = SizedBox(
      width: (room * .45).clamp(280, 520),
      child: QuickSaveBar(
        scope: scope,
        onBand: true,
        onMore: () => showSaveSheet(context, scope, onAdd: add),
      ),
    );
    if (width < 700) {
      return CallbackShortcuts(
        bindings: keys,
        child: Focus(
          autofocus: true,
          child: SaveHomePage(
            scope: scope,
            searchFocus: searchFocus,
            onAdd: add,
            onExport: widget.onExport,
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: keys,
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: v,
          builder: (context, _) => Scaffold(
            bottomNavigationBar: HandySwap(
              child: v.selecting
                  ? BatchBar(
                      key: const ValueKey('batch'),
                      scope: scope,
                      onExport: widget.onExport,
                    )
                  : const SizedBox.shrink(),
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandySideRail(
                  open: !sideOpen,
                  child: SideReopen(onTap: () => setSide(true)),
                ),
                HandySidePanel(
                  width: 260,
                  open: sideOpen,
                  child: BookmarkSidebar(
                    onCollapse: () => setSide(false),
                    scope: scope,
                    overview: overview,
                    onOverview: () => setState(() {
                      current = null;
                      collections = false;
                      overview = true;
                    }),
                    onPick: pick,
                    onSearch: (s) => setState(() {
                      current = null;
                      overview = false;
                      collections = false;
                      v.applySaved(s);
                    }),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The page's head on the deep band: title, counts,
                      // and the link field with the gold Save at the right.
                      SafeArea(
                        bottom: false,
                        left: false,
                        child: Padding(
                          // The same side margins as the page below it.
                          padding: const EdgeInsets.fromLTRB(
                            HandySpace.xl,
                            HandySpace.l,
                            HandySpace.xl,
                            HandySpace.s,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: HeaderBand(
                                  across: true,
                                  title: libraryName(scope.c, context),
                                  counts: [TextSpan(text: counts())],
                                  trailing: [
                                    IconButton(
                                      key: const Key('open-search'),
                                      tooltip: tr(
                                        context,
                                        'Search (Ctrl K)',
                                        'Tìm (Ctrl K)',
                                      ),
                                      icon: const Icon(Icons.search_rounded),
                                      onPressed: search,
                                    ),
                                  ],
                                  action: saveRow,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (collections)
                              Expanded(
                                child: AllCollections(
                                  scope: scope,
                                  onPick: pick,
                                ),
                              )
                            else if (overview)
                              Expanded(
                                child: LibraryOverview(
                                  scope: scope,
                                  onOpen: (b) => details(b, false),
                                  onPick: pick,
                                  onAllCollections: () => setState(() {
                                    current = null;
                                    overview = false;
                                    collections = true;
                                  }),
                                ),
                              )
                            else
                              Expanded(
                                child: ResultsView(
                                  inset: HandySpace.xl,
                                  scope: scope,
                                  current: side ? current : null,
                                  onDetails: (b) => details(b, side),
                                  onAdd: add,
                                  leading: [
                                    SearchBox(view: v, focus: searchFocus),
                                    ShareIssues(controller: scope.c),
                                    const SizedBox(height: HandySpace.l),
                                  ],
                                ),
                              ),
                            if (side && !overview && !collections) ...[
                              // The open item on its own raised sheet beside the list.
                              Container(
                                width: 440,
                                margin: const EdgeInsets.fromLTRB(
                                  0,
                                  8,
                                  HandySpace.xl,
                                  16,
                                ),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: BookmarkPalette.of(context).surface,
                                  borderRadius: BorderRadius.circular(
                                    BookmarkRadii.collection,
                                  ),
                                ),
                                child: HandySwap(
                                  child: current == null
                                      ? HandyEmpty(
                                          key: const ValueKey('none'),
                                          title: tr(
                                            context,
                                            'Pick something to see it here',
                                            'Chọn một mục để xem ở đây',
                                          ),
                                        )
                                      : ListView(
                                          key: ValueKey(current),
                                          padding: const EdgeInsets.all(
                                            HandySpace.xl,
                                          ),
                                          children: [
                                            DetailView(
                                              scope: scope,
                                              id: current!,
                                              onClosed: () => setState(
                                                () => current = null,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
