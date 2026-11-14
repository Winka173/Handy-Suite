import 'models.dart';
import 'search.dart';

/// Where a save most likely belongs, best first, worked out on the device
/// from the library alone:
///
/// 1. collections that already hold saves from the same source (a site, or
///    a platform such as YouTube);
/// 2. collections whose name shares a word with the save's title, source
///    or tags ("Phở" in the title, "Ăn uống · phở" as the name);
/// 3. the collections used most;
/// 4. the person's own order.
///
/// The save itself is never counted. [take] bounds the list.
List<SaveCollection> suggestCollections(
  SaveLibrary library,
  Bookmark bookmark, {
  int take = 4,
}) {
  final mine = sourceKey(bookmark);
  final sameSource = <String, int>{};
  final used = <String, int>{};
  for (final b in library.bookmarks) {
    final id = b.collectionId;
    if (id == null || b.id == bookmark.id) continue;
    used[id] = (used[id] ?? 0) + 1;
    if (mine.isNotEmpty && sourceKey(b) == mine)
      sameSource[id] = (sameSource[id] ?? 0) + 1;
  }
  final about = [
    bookmark.title,
    bookmark.sourceDomain,
    ...bookmark.tags,
  ].join(' ');
  final named = {
    for (final c in library.collections) c.id: nameMatches(c.name, about),
  };
  final list = [...library.collections]
    ..sort((a, b) {
      for (final d in [
        (sameSource[b.id] ?? 0).compareTo(sameSource[a.id] ?? 0),
        named[b.id]!.compareTo(named[a.id]!),
        (used[b.id] ?? 0).compareTo(used[a.id] ?? 0),
        a.position.compareTo(b.position),
      ]) {
        if (d != 0) return d;
      }
      return 0;
    });
  return list.take(take).toList();
}

/// Where a save comes from, as suggestions compare it: its platform (so
/// youtu.be and youtube.com agree), else its site without "www."; empty
/// for a picture.
String sourceKey(Bookmark b) =>
    b.isImage ? '' : sourceKeyOf(platform: b.platform, domain: b.sourceDomain);

/// [sourceKey] for a link not saved yet.
String sourceKeyOf({required String platform, required String domain}) =>
    platform.isNotEmpty && platform != 'web' && platform != 'image'
    ? platform
    : domain.replaceFirst(RegExp(r'^www\.'), '');

/// How many words of a collection's [name] appear in [text], marks and
/// case aside.
int nameMatches(String name, String text) {
  final words = _words(text);
  return _words(name).where(words.contains).length;
}

/// Words worth matching: folded (no Vietnamese marks), three letters or
/// more, so "Hội An" never lands in "Ăn uống" on "an" alone.
Set<String> _words(String text) => {
  for (final w in foldSearch(text).split(RegExp(r'[^a-z0-9]+')))
    if (w.length >= 3) w,
};
