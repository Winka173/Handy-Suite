import 'models.dart';
import 'urls.dart';

String _sameKey(Bookmark b) =>
    UrlTools.normalize(b.canonicalUrl ?? b.normalizedUrl).canonicalUrl;

/// Links saved more than once, by the same rule imports use to skip
/// duplicates (tracking parameters and case dropped; `www.` and a trailing
/// slash still count, since sites differ there). Each group is oldest
/// first; groups are ordered by their oldest save.
List<List<Bookmark>> duplicateGroups(SaveLibrary library) {
  final groups = <String, List<Bookmark>>{};
  for (final b in library.bookmarks) {
    (groups[_sameKey(b)] ??= []).add(b);
  }
  return [
    for (final g in groups.values)
      if (g.length > 1) [...g]..sort((a, b) => a.savedAt.compareTo(b.savedAt)),
  ]..sort((a, b) => a.first.savedAt.compareTo(b.first.savedAt));
}

/// Merges [others] into [keepId], which the person chose: nothing the
/// others carry is lost. Tags are joined, notes are kept one after another,
/// favourite, pinned and read stay on if any had them, the link stays out
/// of the archive if any copy was out, opens are added up, the earliest
/// save and reminder win, and an empty title or collection is filled from
/// the others. Only links that really are the same page are merged.
SaveLibrary mergeBookmarks(
  SaveLibrary library,
  String keepId,
  Iterable<String> others, {
  required String now,
}) {
  final byId = {for (final b in library.bookmarks) b.id: b};
  final keep = byId[keepId] ?? (throw StateError('Unknown link $keepId'));
  final gone = [
    for (final id in others.toSet()..remove(keepId))
      byId[id] ?? (throw StateError('Unknown link $id')),
  ];
  if (gone.isEmpty) return library;
  final key = _sameKey(keep);
  if (gone.any((b) => _sameKey(b) != key))
    throw const FormatException(
      'Only copies of the same link merge / Chỉ gộp các bản của cùng một link',
    );
  final all = [keep, ...gone];
  String? first(String? Function(Bookmark) f) =>
      all.map(f).where((v) => v != null && v.isNotEmpty).firstOrNull;
  String? earliest(Iterable<String?> values) {
    final list = [
      for (final v in values)
        if (v != null && v.isNotEmpty) v,
    ]..sort();
    return list.firstOrNull;
  }

  final notes = <String>[];
  for (final b in all) {
    final n = b.note.trim();
    if (n.isNotEmpty && !notes.contains(n)) notes.add(n);
  }
  final opened = [
    for (final b in all)
      if (b.lastOpenedAt != null) b.lastOpenedAt!,
  ]..sort();
  final merged = keep.copyWith(
    title: keep.title.isNotEmpty ? keep.title : first((b) => b.title) ?? '',
    description: first((b) => b.description),
    thumbnailUrl: first((b) => b.thumbnailUrl),
    siteName: first((b) => b.siteName),
    author: first((b) => b.author),
    collectionId: first((b) => b.collectionId),
    tags: [for (final t in all.expand((b) => b.tags).toSet()) t],
    note: notes.join('\n\n'),
    isFavorite: all.any((b) => b.isFavorite),
    isPinned: all.any((b) => b.isPinned),
    isRead: all.any((b) => b.isRead),
    isArchived: all.every((b) => b.isArchived),
    openedCount: all.fold<int>(0, (n, b) => n + b.openedCount),
    lastOpenedAt: opened.isEmpty ? null : opened.last,
    reminderAt: earliest(all.map((b) => b.reminderAt)),
    savedAt: earliest(all.map((b) => b.savedAt)),
    updatedAt: now,
  );
  final goneIds = {for (final b in gone) b.id};
  // The kept link takes the place of the first copy in the person's order.
  final order = library.fullManualOrder();
  final at = order.indexWhere((id) => id == keepId || goneIds.contains(id));
  final nextOrder = [
    for (final (i, id) in order.indexed)
      if (i == at) keepId else if (id != keepId && !goneIds.contains(id)) id,
  ];
  return library.copyWith(
    bookmarks: [
      for (final b in library.bookmarks)
        if (b.id == keepId) merged else if (!goneIds.contains(b.id)) b,
    ],
    manualOrder: library.manualOrder.isEmpty ? null : nextOrder,
  );
}
