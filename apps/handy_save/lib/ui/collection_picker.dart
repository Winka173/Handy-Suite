import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';

/// Collections in tree order with their depth.
List<(SaveCollection, int)> collectionTree(SaveLibrary l) {
  final byParent = <String?, List<SaveCollection>>{};
  for (final c in l.collections) {
    (byParent[c.parentId] ??= []).add(c);
  }
  final out = <(SaveCollection, int)>[];
  void walk(String? parent, int depth) {
    for (final c
        in (byParent[parent] ?? [])
          ..sort((a, b) => a.position.compareTo(b.position))) {
      out.add((c, depth));
      walk(c.id, depth + 1);
    }
  }

  walk(null, 0);
  return out;
}

/// The collections a link most likely belongs to: the most used first.
List<SaveCollection> usualCollections(SaveLibrary l, {int take = 4}) {
  final count = <String, int>{};
  for (final b in l.bookmarks) {
    if (b.collectionId != null)
      count[b.collectionId!] = (count[b.collectionId!] ?? 0) + 1;
  }
  final list = [...l.collections]
    ..sort((a, b) {
      final d = (count[b.id] ?? 0).compareTo(count[a.id] ?? 0);
      return d != 0 ? d : a.position.compareTo(b.position);
    });
  return list.take(take).toList();
}

/// Asks where to put links. Returns a collection id, '' for "not sorted",
/// or null when dismissed.
Future<String?> pickCollection(
  BuildContext context,
  SaveLibrary l, {
  bool allowInbox = true,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              0,
              HandySpace.l,
              HandySpace.s,
            ),
            child: Text(
              tr(context, 'Move to', 'Chuyển vào'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (allowInbox)
            ListTile(
              key: const Key('pick-inbox'),
              leading: const Icon(Icons.inbox_outlined),
              title: Text(tr(context, 'Not sorted', 'Chưa xếp')),
              onTap: () => Navigator.pop(context, ''),
            ),
          for (final (c, depth) in collectionTree(l))
            ListTile(
              key: Key('pick-${c.id}'),
              contentPadding: EdgeInsets.only(
                left: HandySpace.l + depth * 24.0,
                right: HandySpace.l,
              ),
              leading: const Icon(Icons.folder_outlined),
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, c.id),
            ),
        ],
      ),
    ),
  ),
);
