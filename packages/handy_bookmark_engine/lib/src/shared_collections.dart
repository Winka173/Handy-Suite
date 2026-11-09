import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'collection_page.dart';
import 'duplicates.dart';
import 'models.dart';
import 'portable.dart';

/// Marks the data a shared page carries for Handy Bookmark to read back.
const sharedCollectionsMarker = 'HANDY_BOOKMARK_SHARE_V1:';

/// A picture going out with a shared item: the cleaned JPEG and its size.
class SharedPicture {
  final Uint8List jpeg;
  final int width, height;
  const SharedPicture(this.jpeg, this.width, this.height);
}

/// The page a person sends: [collectionIds] (each with its folders) as one
/// HTML file a browser shows, carrying the same items as data so Handy
/// Bookmark can add them on the other side.
///
/// Only what the page shows leaves the device: titles, links, sources,
/// descriptions, the pictures in [pictures] (already cleaned), and notes
/// when [notes] is on. Tags, reminders, read and favourite state, link
/// checks and every other collection stay here.
String sharedCollectionsPage(
  SaveLibrary library,
  List<String> collectionIds, {
  Map<String, SharedPicture> pictures = const {},
  bool notes = false,
  bool vietnamese = false,
  required DateTime now,
}) {
  final byId = {for (final c in library.collections) c.id: c};
  final chosen = {
    for (final id in collectionIds)
      if (byId.containsKey(id)) id,
  };
  // A chosen folder whose collection is chosen too travels as its folder.
  final roots = [
    for (final id in chosen)
      if (!chosen.contains(byId[id]!.parentId))
        byId[id]!.copyWith(parentId: null),
  ];
  if (roots.isEmpty) throw const FormatException('Nothing to share');
  final ids = <String>{for (final c in roots) c.id};
  final folders = [
    for (final c in library.collections)
      if (c.parentId != null && ids.contains(c.parentId)) c,
  ];
  ids.addAll(folders.map((c) => c.id));
  final items = [
    for (final b in library.bookmarks)
      if (!b.isArchived && ids.contains(b.collectionId)) b,
  ];
  final out = <Map<String, dynamic>>[];
  for (final b in items) {
    final picture = pictures[b.id];
    final j =
        b
            .copyWith(
              tags: const [],
              note: notes ? b.note : '',
              isFavorite: false,
              isPinned: false,
              isRead: false,
              openedCount: 0,
              lastOpenedAt: null,
              reminderAt: null,
              linkCheck: null,
              rev: 0,
            )
            .toJson()
          // The picture travels in the page, never the original.
          ..remove('media');
    if (picture != null)
      j['sharedPicture'] = {'w': picture.width, 'h': picture.height};
    out.add(j);
  }
  // An image item cannot travel without its picture.
  out.removeWhere((j) => j['kind'] == 'image' && j['sharedPicture'] == null);
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'collections': [
          for (final c in [...roots, ...folders]) c.toJson(),
        ],
        'items': out,
      }),
    ),
  );
  final page = collectionsPage(
    library,
    [for (final c in roots) c.id],
    pictures: {for (final e in pictures.entries) e.key: e.value.jpeg},
    notes: notes,
    vietnamese: vietnamese,
    now: now,
    importHint: true,
  );
  return page.replaceFirst(
    '<head>',
    '<head>\n<!-- $sharedCollectionsMarker$payload -->',
  );
}

/// Whether [bytes] is a page made by [sharedCollectionsPage].
bool isSharedCollections(Uint8List bytes) {
  final head = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
  return utf8
      .decode(head, allowMalformed: true)
      .contains(sharedCollectionsMarker);
}

/// What a received page holds, checked whole, ready to add.
class SharedImport {
  /// The collections and items as they would arrive (renamed where a
  /// collection with the same name is already here; folders flattened when
  /// they cannot be kept). Commit it with [ImportPreview.commit].
  final ImportPreview preview;

  /// Previews for links (not pictures), keyed by the item ids in
  /// [preview]: store the ones whose items were added.
  final Map<String, Uint8List> thumbnails;

  /// The top collections, by their names as they will arrive.
  final List<String> names;

  /// Folders in the file, and whether they were folded into their
  /// collection (their names became tags on their items).
  final int folders;
  final bool flattened;

  /// Collections renamed because the name is already taken here.
  final int renamed;
  const SharedImport({
    required this.preview,
    required this.thumbnails,
    required this.names,
    required this.folders,
    required this.flattened,
    required this.renamed,
  });
}

/// Reads a shared page. Nothing is kept unless the whole file is valid.
///
/// [keepFolders] (Pro): folders arrive as folders. Without it every item
/// in a folder goes into the folder's collection and carries the folder's
/// name as a tag, so nothing is lost and the group can still be found.
/// A top collection whose name is already used here arrives as
/// "name [suffix]" so it never mixes into the person's own. Items arrive
/// unread, newest first, saved [now].
SharedImport readSharedCollections(
  Uint8List bytes, {
  required SaveLibrary current,
  required bool keepFolders,
  required String suffix,
  required DateTime now,
}) {
  if (bytes.length > SavePortable.maxImportBytes)
    throw const FormatException('File too large');
  final text = utf8.decode(bytes, allowMalformed: false);
  final match = RegExp(
    '${RegExp.escape(sharedCollectionsMarker)}([A-Za-z0-9_=-]+)',
  ).firstMatch(text);
  if (match == null) throw const FormatException('Not a shared collection');
  final data = jsonDecode(utf8.decode(base64Url.decode(match.group(1)!)));
  if (data is! Map || data['v'] != 1)
    throw const FormatException('Unknown shared format');
  final rawCollections = data['collections'], rawItems = data['items'];
  if (rawCollections is! List || rawItems is! List)
    throw const FormatException('Broken shared file');
  if (rawCollections.length > 2000 || rawItems.length > 50000)
    throw const FormatException('Too many items');
  var collections = [
    for (final c in rawCollections)
      SaveCollection.fromJson(Map<String, dynamic>.from(c as Map)),
  ];
  final byId = {for (final c in collections) c.id: c};
  if (byId.length != collections.length)
    throw const FormatException('Repeated collection');
  for (final c in collections) {
    if (c.parentId != null && byId[c.parentId]?.parentId != null)
      throw const FormatException('Folders are one level deep');
    if (c.parentId != null && !byId.containsKey(c.parentId))
      throw const FormatException('Folder without its collection');
  }
  // Pictures the page shows, by item id.
  final shown = <String, Uint8List>{};
  for (final m in RegExp(
    r'<img alt="" loading="lazy" data-item="([^"]+)" src="data:image/jpeg;base64,([A-Za-z0-9+/=]+)">',
  ).allMatches(text)) {
    shown[_unescape(m.group(1)!)] = base64Decode(m.group(2)!);
  }
  final stamp = now.toUtc();
  final tag = sha256
      .convert(utf8.encode('${stamp.microsecondsSinceEpoch}:${bytes.length}'))
      .toString()
      .substring(0, 10);
  final folders = collections.where((c) => c.parentId != null).toList();
  final flatten = !keepFolders && folders.isNotEmpty;
  final folderName = {for (final c in folders) c.id: c.name.trim()};
  final media = <String, PortablePicture>{};
  final thumbnails = <String, Uint8List>{};
  final items = <Bookmark>[];
  final sorted = [
    for (final raw in rawItems) Map<String, dynamic>.from(raw as Map),
  ]..sort((a, b) => '${b['savedAt']}'.compareTo('${a['savedAt']}'));
  for (final (i, j) in sorted.indexed) {
    final size = j.remove('sharedPicture');
    final fileId = '${j['id']}';
    final picture = shown[fileId];
    MediaRef? ref;
    if (j['kind'] == 'image') {
      if (picture == null || size is! Map)
        throw const FormatException('A picture is missing');
      ref = MediaRef(
        id: sha256.convert(picture).toString(),
        mime: 'image/jpeg',
        width: size['w'] as int,
        height: size['h'] as int,
        bytes: picture.length,
      );
      media[ref.id] = PortablePicture(picture, picture);
      j['media'] = ref.toJson();
    } else {
      j.remove('media');
    }
    var b = Bookmark.fromJson(j);
    if (b.collectionId == null || !byId.containsKey(b.collectionId))
      throw const FormatException('Item outside the shared collections');
    final when = stamp.subtract(Duration(seconds: i)).toIso8601String();
    var collection = b.collectionId!;
    var tags = const <String>[];
    if (flatten && folderName.containsKey(collection)) {
      tags = [folderName[collection]!];
      collection = byId[collection]!.parentId!;
    }
    final id = 'shared-$tag-$i';
    b = b.copyWith(
      id: id,
      collectionId: collection,
      tags: tags,
      media: ref,
      savedAt: when,
      updatedAt: when,
      isRead: false,
      isArchived: false,
      reminderAt: null,
      rev: 0,
    );
    if (picture != null && !b.isImage) thumbnails[id] = picture;
    items.add(b);
  }
  if (flatten)
    collections = [
      for (final c in collections)
        if (c.parentId == null) c,
    ];
  // A top collection whose name is taken here arrives under a new name.
  final taken = {
    for (final c in current.collections)
      if (c.parentId == null) c.name.trim().toLowerCase(),
  };
  var renamed = 0;
  final names = <String>[];
  collections = [
    for (final c in collections)
      if (c.parentId != null)
        c
      else
        () {
          var name = c.name.trim();
          if (taken.contains(name.toLowerCase())) {
            renamed++;
            var n = 1;
            var next = '$name $suffix';
            while (taken.contains(next.toLowerCase())) {
              next = '$name $suffix ${++n}';
            }
            name = next;
          }
          taken.add(name.toLowerCase());
          names.add(name);
          return c.copyWith(name: name);
        }(),
  ];
  final library = SaveLibrary(
    tags: {for (final b in items) ...b.tags}.toList(),
    collections: collections,
    bookmarks: items,
  );
  final known = current.bookmarks.map(sameItemKey).toSet();
  final duplicates = items.where((b) => known.contains(sameItemKey(b))).length;
  return SharedImport(
    preview: ImportPreview(
      library: library,
      duplicateCount: duplicates,
      invalidCount: 0,
      pictures: media,
    ),
    thumbnails: thumbnails,
    names: names,
    folders: folders.length,
    flattened: flatten,
    renamed: renamed,
  );
}

String _unescape(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
