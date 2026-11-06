import 'package:handy_ui/kit.dart';
import '../library/batch_bar.dart';
import '../library/results_view.dart';
import '../scope.dart';
import '../shell/search_box.dart';
import '../view/library_view.dart';
import '../shell/share_issues.dart';
import 'triage_strip.dart';
import '../links/task_strip.dart';
import 'collection_covers.dart';
import 'dateline.dart';
import 'save_sheet.dart';
import '../design/theme.dart';
import 'empty_library.dart';

/// The phone's home, as simple as saving is: find something, the two ways
/// further in (the whole Library, and Focus), what was saved lately, and
/// the collections as covers. Typing (or choosing Links / Pictures) turns
/// the home into results; clearing brings it back. One Save button.
class SaveHomePage extends StatelessWidget {
  final SaveScope scope;
  final FocusNode searchFocus;
  final VoidCallback onAdd, onExport;
  final Future<void> Function({bool clipboard}) onAddFrom;
  SaveHomePage({
    super.key,
    required this.scope,
    required this.searchFocus,
    required Future<void> Function({bool clipboard}) onAdd,
    required this.onExport,
  }) : onAddFrom = onAdd,
       onAdd = (() => onAdd());

  void openPlace(BuildContext context, Place p, [String? id]) =>
      Navigator.pushNamed(context, switch (p) {
        Place.collection => '/collection/$id',
        Place.smart => '/smart/$id',
        Place.tag => '/tag/${Uri.encodeComponent(id!)}',
        _ => '/place/${p.name}',
      });

  @override
  Widget build(BuildContext context) {
    final v = scope.view;
    return ListenableBuilder(
      listenable: v,
      builder: (context, _) {
        final searching = v.text.trim().isNotEmpty || v.filters.kind != null;
        final l = scope.library;
        final empty = l.bookmarks.isEmpty && l.trash.isEmpty;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 64,
            titleSpacing: HandySpace.l,
            title: Semantics(
              header: true,
              child: Text(
                libraryName(scope.c),
                overflow: TextOverflow.ellipsis,
                style: bookmarkSerif(context, 28),
              ),
            ),
            actions: [
              IconButton(
                key: const Key('open-settings'),
                tooltip: tr(context, 'Settings', 'Cài đặt'),
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(width: HandySpace.s),
            ],
          ),
          bottomNavigationBar: v.selecting
              ? BatchBar(scope: scope, onExport: onExport)
              : HandyBottomBar(
                  child: SaveButton(
                    scope: scope,
                    onAdd: onAddFrom,
                    expand: true,
                  ),
                ),
          body: searching
              ? ResultsView(
                  scope: scope,
                  onDetails: (b) =>
                      Navigator.pushNamed(context, '/bookmark/${b.id}'),
                  onAdd: onAdd,
                  leading: [
                    SearchBox(view: v, focus: searchFocus),
                    const SizedBox(height: HandySpace.l),
                  ],
                )
              : ListView(
                  key: const Key('save-home'),
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    HandySpace.xs,
                    HandySpace.l,
                    HandySpace.xxl,
                  ),
                  children: [
                    SearchBox(view: v, focus: searchFocus),
                    if (empty)
                      EmptyLibrary(
                        // The same sheet as the Save button: one way in.
                        onAdd: () =>
                            showSaveSheet(context, scope, onAdd: onAddFrom),
                      )
                    else
                      HomeDoors(
                        scope: scope,
                        onLibrary: () =>
                            Navigator.pushNamed(context, '/library'),
                        onFocus: () => Navigator.pushNamed(context, '/focus'),
                      ),
                    ShareIssues(controller: scope.c),
                    TaskStrip(
                      tasks: scope.tasks,
                      onBroken: () {
                        scope.tasks.dismiss();
                        openPlace(context, Place.broken);
                      },
                    ),
                    TriageStrip(
                      controller: scope.c,
                      onFile: scope.file,
                      onOpen: (b) =>
                          Navigator.pushNamed(context, '/bookmark/${b.id}'),
                      onAll: () => openPlace(context, Place.inbox),
                    ),
                    if (!empty || l.collections.isNotEmpty)
                      CollectionCovers(
                        scope: scope,
                        onOpen: (col) =>
                            openPlace(context, Place.collection, col.id),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// The two ways further in, side by side under the search: the whole
/// Library (every place, tag and kept list) and Focus (what is not read
/// yet, one at a time). Stacked when the screen is narrow or the text is
/// large.
class HomeDoors extends StatelessWidget {
  final SaveScope scope;
  final VoidCallback onLibrary, onFocus;
  const HomeDoors({
    super.key,
    required this.scope,
    required this.onLibrary,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    var live = 0, unread = 0;
    for (final b in l.bookmarks) {
      if (b.isArchived) continue;
      live++;
      if (!b.isRead) unread++;
    }
    final n = formatFigure(context, '$live');
    final library = _Door(
      key: const Key('home-library'),
      icon: Icons.bookmarks_outlined,
      title: tr(context, 'Library', 'Thư viện'),
      // How much is in it; what waits to be sorted is on the shelf below.
      note: tr(context, n == 1 ? '1 item' : '$n items', '$n mục'),
      onTap: onLibrary,
    );
    final focus = _Door(
      key: const Key('place-focus'),
      icon: Icons.center_focus_strong_outlined,
      title: tr(context, 'Focus', 'Tập trung'),
      note: unread == 0
          ? tr(context, 'Everything is read', 'Đã xem hết')
          : tr(
              context,
              '${formatFigure(context, '$unread')} not read yet',
              '${formatFigure(context, '$unread')} mục chưa xem',
            ),
      onTap: onFocus,
    );
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.m),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth / 2 < 150 * scale
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  library,
                  const SizedBox(height: HandySpace.s),
                  focus,
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: library),
                    const SizedBox(width: HandySpace.s),
                    Expanded(child: focus),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  final IconData icon;
  final String title, note;
  final VoidCallback onTap;
  const _Door({
    super.key,
    required this.icon,
    required this.title,
    required this.note,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: p.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: p.muted,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
