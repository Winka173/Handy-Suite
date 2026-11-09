import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../library/batch_bar.dart';
import '../scope.dart';
import '../view/library_view.dart';
import '../shell/share_issues.dart';
import '../links/task_strip.dart';
import 'collection_covers.dart';
import 'dateline.dart';
import 'save_sheet.dart';
import 'empty_library.dart';
import 'home_sections.dart';
import '../ui/header_band.dart';
import '../ui/read_later_ribbon.dart';
import 'home_queues.dart';
import 'pastel_blocks.dart';
import 'quick_save.dart';

/// The phone's home, a launchpad: the library's name, the Quick Save row
/// (a link field and the one Save control), a compact reminder of what
/// waits in Focus, the collections as covers, and the last few saves.
/// Search and every item live one step in (the search icon, See all).
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
    void open(Bookmark b) => Navigator.pushNamed(context, '/bookmark/${b.id}');
    return ListenableBuilder(
      listenable: Listenable.merge([v, scope.c]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final l = scope.library;
        final empty = l.bookmarks.isEmpty && l.trash.isEmpty;
        var live = 0, unsorted = 0;
        for (final b in l.bookmarks) {
          if (b.isArchived) continue;
          live++;
          if (b.collectionId == null) unsorted++;
        }
        final now = DateTime.now();
        final later = l.bookmarks
            .where((b) => !b.isArchived && readLaterAt(b, now) != null)
            .length;
        // "87 items · 4 not sorted · 3 to read later", figures in white.
        InlineSpan figure(int v) => bandFigure(context, v);
        final subtitle = <InlineSpan>[
          figure(live),
          TextSpan(text: tr(context, live == 1 ? ' item' : ' items', ' mục')),
          if (unsorted > 0) ...[
            const TextSpan(text: ' · '),
            figure(unsorted),
            TextSpan(text: tr(context, ' not sorted', ' chưa xếp')),
          ],
          if (later > 0) ...[
            const TextSpan(text: ' · '),
            figure(later),
            TextSpan(text: tr(context, ' to read later', ' hẹn đọc')),
          ],
        ];
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 64,
            titleSpacing: HandySpace.l,
            title: Row(
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
                Flexible(
                  child: Text(
                    'Handy Bookmark',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (!empty)
                IconButton(
                  key: const Key('open-search'),
                  tooltip: tr(context, 'Search', 'Tìm'),
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => Navigator.pushNamed(context, '/find'),
                ),
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
              : null,
          body: ListView(
            key: const Key('save-home'),
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.xs,
              HandySpace.l,
              HandySpace.xxl,
            ),
            children: [
              HeaderBand(
                title: libraryName(scope.c, context),
                counts: empty ? const [] : subtitle,
                action: QuickSaveBar(
                  scope: scope,
                  onBand: true,
                  onMore: () => showSaveSheet(context, scope, onAdd: onAddFrom),
                ),
              ),
              const SizedBox(height: HandySpace.m),
              ShareIssues(controller: scope.c),
              TaskStrip(
                tasks: scope.tasks,
                onBroken: () {
                  scope.tasks.dismiss();
                  openPlace(context, Place.broken);
                },
              ),
              if (empty)
                EmptyLibrary(onPicture: () => scope.addPhoto(context))
              else ...[
                // As in the mock: the two queues right under the band,
                // then what is set to read later.
                HomeQueues(
                  scope: scope,
                  onFocus: () => Navigator.pushNamed(context, '/focus'),
                ),
                ReadLaterShelf(scope: scope, onOpen: open),
              ],
              if (!empty || l.collections.isNotEmpty)
                CollectionCovers(
                  scope: scope,
                  limit: 6,
                  onAll: () => Navigator.pushNamed(context, '/library'),
                  onOpen: (col) => openPlace(context, Place.collection, col.id),
                ),
              if (!empty)
                RecentlySaved(
                  scope: scope,
                  onOpen: open,
                  onAll: () => openPlace(context, Place.all),
                ),
            ],
          ),
        );
      },
    );
  }
}
