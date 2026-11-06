import 'package:flutter/services.dart';
import '../design/theme.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/add_link.dart';
import '../bookmark/detail_view.dart';
import '../home/home_page.dart';
import '../home/triage_strip.dart';
import '../home/dateline.dart';
import '../home/save_sheet.dart';
import '../home/quick_save.dart';
import '../library/batch_bar.dart';
import '../library/results_view.dart';
import '../scope.dart';
import '../view/library_view.dart';
import 'places_list.dart';
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
        SingleActivator(
          LogicalKeyboardKey.keyF,
          control: !meta,
          meta: meta,
        ): width < 700
            ? () => Navigator.pushNamed(context, '/find')
            : searchFocus.requestFocus,
      },
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          v.selecting ? v.clearSelection() : setState(() => current = null),
    };
    // The same Quick Save row as the phone's Home, in the header.
    final addButtons = [
      SizedBox(
        width: (width * .4).clamp(320, 520),
        child: QuickSaveBar(
          scope: scope,
          onMore: () => showSaveSheet(context, scope, onAdd: add),
        ),
      ),
      const SizedBox(width: HandySpace.s),
    ];
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
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: 68,
              titleSpacing: HandySpace.xl,
              title: Text(
                libraryName(scope.c, context),
                overflow: TextOverflow.ellipsis,
                style: bookmarkSerif(context, 28),
              ),
              actions: [
                ...addButtons,
                IconButton(
                  key: const Key('open-settings'),
                  tooltip: tr(context, 'Settings', 'Cài đặt'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
                const SizedBox(width: HandySpace.m),
              ],
            ),
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
                SizedBox(
                  width: 280,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      HandySpace.l,
                      HandySpace.l,
                      HandySpace.s,
                      HandySpace.xxl,
                    ),
                    children: [
                      PlacesList(
                        scope: scope,
                        onPick: (p, [id]) => setState(() {
                          current = null;
                          v.show(p, id);
                        }),
                        onFocus: () => Navigator.pushNamed(context, '/focus'),
                        onSearch: (s) => setState(() {
                          current = null;
                          v.applySaved(s);
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ResultsView(
                    scope: scope,
                    current: side ? current : null,
                    onDetails: (b) => details(b, side),
                    onAdd: add,
                    leading: [
                      SearchBox(view: v, focus: searchFocus),
                      ShareIssues(controller: scope.c),
                      if (v.place == Place.all &&
                          v.text.isEmpty &&
                          !v.filters.any)
                        TriageStrip(
                          controller: scope.c,
                          onFile: scope.file,
                          onOpen: (b) => details(b, side),
                          onAll: () => v.show(Place.inbox),
                        ),
                      const SizedBox(height: HandySpace.l),
                    ],
                  ),
                ),
                if (side) ...[
                  // The open item on its own raised sheet beside the list.
                  Container(
                    width: 440,
                    margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
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
                              padding: const EdgeInsets.all(HandySpace.xl),
                              children: [
                                DetailView(
                                  scope: scope,
                                  id: current!,
                                  onClosed: () =>
                                      setState(() => current = null),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
