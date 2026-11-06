import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/words.dart';
import 'clipping.dart';

/// The person's own save, drawn as a clipping: its picture, its title and
/// where it came from (and its collection once it has one).
class SavedClipping extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const SavedClipping({super.key, required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final title = b.title.trim().isNotEmpty
        ? b.title
        : b.isImage
        ? tr(context, 'Picture', 'Ảnh')
        : b.sourceDomain;
    final where = collectionOf(scope.library, b.collectionId)?.$1.name;
    final source = [
      if (where != null) where,
      b.isImage ? tr(context, 'Picture', 'Ảnh') : sourceLine(b),
      ago(context, b.savedAt),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Semantics(
      label: '$title. $source',
      excludeSemantics: true,
      child: Clipping(
        key: ValueKey('welcome-saved-${b.id}'),
        width: double.infinity,
        title: title,
        source: source,
        picture: LinkThumb(scope.c, b, size: 56),
      ),
    );
  }
}

/// Collections to put the first save in: the person's own, or four starter
/// ones that are created when chosen. Filing is one undoable change.
class Filing extends StatefulWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const Filing({super.key, required this.scope, required this.bookmark});
  @override
  State<Filing> createState() => _FilingState();
}

class _FilingState extends State<Filing> {
  bool busy = false;
  SaveScope get scope => widget.scope;

  List<String> _starters(BuildContext context) => [
    tr(context, 'Recipes', 'Món ngon'),
    tr(context, 'To buy', 'Cần mua'),
    tr(context, 'Read later', 'Đọc sau'),
    tr(context, 'Trips', 'Du lịch'),
  ];

  Future<void> _file({SaveCollection? into, String? name}) async {
    if (busy) return;
    setState(() => busy = true);
    final b = widget.bookmark;
    final ok = await scope.run(context, () async {
      final existing =
          into ??
          scope.library.collections
              .where((c) => c.name.toLowerCase() == name!.toLowerCase())
              .firstOrNull;
      final target =
          existing ??
          SaveCollection(
            id: saveId(),
            name: name!,
            color: '#0EA5E9',
            position: scope.library.collections.length,
          );
      await scope.view.change(
        (l) => l.copyWith(
          collections: existing == null
              ? [...l.collections, target]
              : l.collections,
          bookmarks: [
            for (final x in l.bookmarks)
              x.id == b.id
                  ? x.copyWith(collectionId: target.id, updatedAt: saveTime())
                  : x,
          ],
        ),
      );
    });
    if (ok) HapticFeedback.selectionClick();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _other() async {
    final id = await pickCollection(context, scope.library);
    if (id == null || id.isEmpty || !mounted) return;
    final c = scope.library.collections.where((c) => c.id == id).firstOrNull;
    if (c != null) await _file(into: c);
  }

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    final current = widget.bookmark.collectionId;
    final usual = usualCollections(l);
    final names = {for (final c in l.collections) c.name.toLowerCase()};
    // A chosen chip stays fully drawn (selected, not disabled); choosing it
    // again does nothing.
    void keep(bool _) {}
    final chips = <Widget>[
      for (final c in usual)
        ChoiceChip(
          key: Key('welcome-file-${c.id}'),
          avatar: HandyDot(collectionHue(l, c.id), size: 10),
          label: Text(c.name),
          selected: current == c.id,
          onSelected: current == c.id
              ? keep
              : busy
              ? null
              : (_) => _file(into: c),
        ),
      // Starter collections fill the row until there are four of the
      // person's own.
      if (usual.length < 4)
        for (final (i, name) in _starters(context).indexed)
          if (!names.contains(name.toLowerCase()))
            ChoiceChip(
              key: Key('welcome-start-$i'),
              label: Text(name),
              selected: false,
              onSelected: busy ? null : (_) => _file(name: name),
            ),
      if (l.collections.length > usual.length)
        ActionChip(
          key: const Key('welcome-file-other'),
          label: Text(tr(context, 'Other…', 'Khác…')),
          onPressed: busy ? null : _other,
        ),
    ];
    return Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: chips,
    );
  }
}
