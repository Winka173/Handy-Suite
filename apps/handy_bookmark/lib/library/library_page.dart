import 'package:handy_ui/kit.dart';
import '../collections/share_collection.dart';
import '../data/import_export.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../shell/places_list.dart';
import '../view/library_view.dart';

/// Every place in the library on its own page (phones; `#/library` on the
/// web): Not sorted, everything, favourites, unread, the archive, broken
/// links and Recently Deleted, then the collections as a tree, the tags,
/// and under "Advanced" the smart collections and saved searches kept.
/// The phone's home shows only the covers and what is new; this is the
/// one way to everything else.
class LibraryPage extends StatelessWidget {
  final SaveScope scope;
  const LibraryPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        if (scope.library.collections.isNotEmpty)
          IconButton(
            key: const Key('collections-send'),
            tooltip: tr(context, 'Send collections', 'Gửi bộ sưu tập'),
            onPressed: () => scope.sendCollections(context),
            icon: const Icon(Icons.send_rounded),
          ),
        IconButton(
          key: const Key('collections-receive'),
          tooltip: tr(
            context,
            'Add collections sent to you',
            'Thêm bộ sưu tập được gửi cho bạn',
          ),
          onPressed: () => scope.importLinks(context),
          icon: const Icon(Icons.move_to_inbox_outlined),
        ),
        const SizedBox(width: HandySpace.s),
      ],
      title: Semantics(
        header: true,
        child: Text(
          tr(context, 'Library', 'Thư viện'),
          style: bookmarkSerif(context, 24),
        ),
      ),
    ),
    body: ListenableBuilder(
      listenable: scope.view,
      builder: (context, _) => Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          // Row fills and ripples clipped to the list (see the sidebar).
          child: ClipRect(
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
                key: const Key('library-page'),
                padding: const EdgeInsets.fromLTRB(
                  HandySpace.l,
                  HandySpace.s,
                  HandySpace.l,
                  HandySpace.xxl,
                ),
                children: [
                  PlacesList(
                    scope: scope,
                    marking: false,
                    tiles: true,
                    onPick: (p, [id]) =>
                        Navigator.pushNamed(context, switch (p) {
                          Place.collection => '/collection/$id',
                          Place.smart => '/smart/$id',
                          Place.tag => '/tag/${Uri.encodeComponent(id!)}',
                          _ => '/place/${p.name}',
                        }),
                    onSearch: (s) =>
                        Navigator.pushNamed(context, '/search/${s.id}'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
