import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'widget_styles.dart';

// Handy Bookmark's home-screen widgets (Android). Each is drawn natively
// from the strings written here under its own prefix; none of them reads
// the library. They never notify: they are there when the person looks.
//
//   save_     Quick save (Free): one tap opens "paste a link".
//   queue_    Reading queue (Free): the newest three unread.
//   shelf_    Favourite collection (Free): its count and newest three.
//   picks_    Reading picks (Pro): four labelled lines, changing daily.
//   gallery_  Gallery (Pro): the pictures of four recent items.
//
// Links: handy-bookmark://save, ://item?id=, ://collection?id=, ://unread.

String _name(Bookmark b, bool vi) => b.title.trim().isNotEmpty
    ? b.title.trim()
    : (b.hasUrl ? b.sourceDomain : (vi ? 'Ảnh' : 'Picture'));

String _itemUri(Bookmark b) => 'handy-bookmark://item?id=${b.id}';

List<Bookmark> _live(SaveLibrary l) => [
  for (final b in l.bookmarks)
    if (b.deletedAt == null && !b.isArchived) b,
]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

HomeWidgetView quickSaveView({required bool vi}) => HomeWidgetView(
  title: 'Handy Bookmark',
  value: vi ? 'Lưu link' : 'Save a link',
  detail: vi ? 'Chạm để dán link đã sao chép' : 'Tap to paste a copied link',
  uri: 'handy-bookmark://save',
);

HomeWidgetView queueView(SaveLibrary l, {required bool vi, bool names = true}) {
  final unread = [
    for (final b in _live(l))
      if (!b.isRead) b,
  ];
  return HomeWidgetView(
    title: vi ? 'Hàng chờ đọc' : 'Reading queue',
    value: vi ? '${unread.length} chưa đọc' : '${unread.length} unread',
    detail: unread.isEmpty
        ? (vi ? 'Chưa có gì để đọc' : 'Nothing waiting to read')
        : '',
    uri: 'handy-bookmark://unread',
    rows: names
        ? [for (final b in unread.take(3)) (_name(b, vi), _itemUri(b))]
        : const [],
  );
}

/// The collection the person picked for the widget, else the one with the
/// most items; when there is none (or it was deleted), Not sorted.
SaveCollection? widgetCollection(SaveLibrary l, String? id) {
  final picked = l.collections.where((c) => c.id == id).firstOrNull;
  if (picked != null) return picked;
  final counts = <String, int>{};
  for (final b in _live(l)) {
    if (b.collectionId != null) {
      counts[b.collectionId!] = (counts[b.collectionId!] ?? 0) + 1;
    }
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return top.isEmpty
      ? null
      : l.collections.where((c) => c.id == top.first.key).firstOrNull;
}

HomeWidgetView shelfView(
  SaveLibrary l, {
  required bool vi,
  String? collection,
  bool names = true,
}) {
  final c = widgetCollection(l, collection);
  final items = [
    for (final b in _live(l))
      if (b.collectionId == c?.id) b,
  ];
  return HomeWidgetView(
    title: c?.name ?? (vi ? 'Chưa xếp' : 'Not sorted'),
    value: vi ? '${items.length} mục' : '${items.length} items',
    detail: items.isEmpty ? (vi ? 'Chưa có mục nào' : 'Nothing here yet') : '',
    uri: c == null
        ? 'handy-bookmark://inbox'
        : 'handy-bookmark://collection?id=${c.id}',
    rows: names
        ? [for (final b in items.take(3)) (_name(b, vi), _itemUri(b))]
        : const [],
  );
}

HomeWidgetView _locked(String title, bool vi) => HomeWidgetView(
  title: title,
  value: vi ? 'Mở khoá trong app' : 'Unlock in the app',
  detail: vi ? 'Widget Pro' : 'A Pro widget',
  uri: 'handy-bookmark://pro',
);

/// Four lines, the same all day: the newest unread saved this fortnight,
/// one saved over a month ago and never opened, a favourite, and one from
/// the chosen collection. A line without a candidate is left out.
List<(String label, Bookmark item)> readingPicks(
  SaveLibrary l,
  DateTime now, {
  required bool vi,
  String? collection,
}) {
  final live = _live(l);
  final day = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(2026)).inDays;
  T? pick<T>(List<T> list) => list.isEmpty ? null : list[day % list.length];
  final used = <String>{};
  final out = <(String, Bookmark)>[];
  void add(String label, Bookmark? b) {
    if (b == null || !used.add(b.id)) return;
    out.add((label, b));
  }

  DateTime saved(Bookmark b) => DateTime.tryParse(b.savedAt) ?? now;
  add(
    vi ? 'Mới lưu' : 'Just saved',
    live
        .where((b) => !b.isRead && now.difference(saved(b)).inDays <= 14)
        .firstOrNull,
  );
  add(
    vi ? 'Chờ lâu' : 'Waiting a while',
    pick([
      for (final b in live)
        if (!b.isRead &&
            b.lastOpenedAt == null &&
            now.difference(saved(b)).inDays > 30)
          b,
    ]),
  );
  add(
    vi ? 'Yêu thích' : 'Favourite',
    pick([
      for (final b in live)
        if (b.isFavorite && !used.contains(b.id)) b,
    ]),
  );
  final c = widgetCollection(l, collection);
  if (c != null) {
    add(
      c.name,
      pick([
        for (final b in live)
          if (b.collectionId == c.id && !used.contains(b.id)) b,
      ]),
    );
  }
  return out;
}

HomeWidgetView picksView(
  SaveLibrary l,
  DateTime now, {
  required bool vi,
  required bool pro,
  String? collection,
  bool names = true,
}) {
  final title = vi ? 'Gợi ý đọc' : 'Reading picks';
  if (!pro) return _locked(title, vi);
  final picks = readingPicks(l, now, vi: vi, collection: collection);
  return HomeWidgetView(
    title: title,
    value: picks.isEmpty
        ? (vi ? 'Chưa có gợi ý' : 'No picks yet')
        : (vi ? 'Hôm nay' : 'Today'),
    detail: picks.isEmpty
        ? (vi ? 'Lưu vài link để có gợi ý' : 'Save a few links to get picks')
        : '',
    uri: 'handy-bookmark://unread',
    maxRows: 4,
    rows: [
      for (final (label, b) in picks)
        (names ? '$label · ${_name(b, vi)}' : label, _itemUri(b)),
    ],
  );
}

/// The gallery: up to four recent items that have a picture, newest first.
List<Bookmark> galleryItems(SaveLibrary l, Set<String> withPicture) => [
  for (final b in _live(l))
    if (withPicture.contains(b.id)) b,
].take(4).toList();

HomeWidgetView galleryView(
  SaveLibrary l,
  List<(Bookmark, String path)> pictures, {
  required bool vi,
  required bool pro,
  bool names = true,
}) {
  final title = vi ? 'Thư viện ảnh' : 'Gallery';
  if (!pro) return _locked(title, vi);
  return HomeWidgetView(
    title: title,
    value: pictures.isEmpty ? (vi ? 'Chưa có ảnh' : 'No pictures yet') : '',
    uri: 'handy-bookmark://library',
    maxRows: 4,
    rows: [
      for (final (b, _) in pictures) (names ? _name(b, vi) : '', _itemUri(b)),
    ],
    extra: {
      for (var i = 0; i < 4; i++)
        'img$i': i < pictures.length ? pictures[i].$2 : null,
    },
  );
}

/// Writes what the five widgets show. Never throws: a widget that cannot
/// update must not break the app.
class BookmarkHomeWidgets {
  static const _base = 'com.example.handysuite.save';
  final feeds = {
    for (final (prefix, cls) in const [
      ('save_', 'QuickSaveWidget'),
      ('queue_', 'QueueWidget'),
      ('shelf_', 'ShelfWidget'),
      ('picks_', 'PicksWidget'),
      ('gallery_', 'GalleryWidget'),
    ])
      prefix: HomeWidgetFeed('$_base.$cls', prefix: prefix),
  };
  final _written = <String, int>{};
  Timer? _debounce;

  bool get supported => homeWidgetsSupported;

  /// After a change: published once things settle for half a second.
  void schedule(
    SaveLibrary l,
    Map<String, dynamic> prefs, {
    required bool vi,
    required bool pro,
    required Future<Uint8List?> Function(String id) thumbnail,
  }) {
    if (!supported) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => publish(
        l,
        prefs,
        vi: vi,
        pro: pro,
        thumbnail: thumbnail,
      ).catchError((Object _) {}),
    );
  }

  Future<void> publish(
    SaveLibrary l,
    Map<String, dynamic> prefs, {
    required bool vi,
    required bool pro,
    required Future<Uint8List?> Function(String id) thumbnail,
  }) async {
    final style = bookmarkWidgetStyleOf(prefs, pro: pro).native;
    final names = prefs['widgetHideNames'] != true;
    final col = prefs['widgetCollection'] as String?;
    final now = DateTime.now();
    final views = <String, HomeWidgetView>{
      'save_': quickSaveView(vi: vi),
      'queue_': queueView(l, vi: vi, names: names),
      'shelf_': shelfView(l, vi: vi, collection: col, names: names),
      'picks_': picksView(
        l,
        now,
        vi: vi,
        pro: pro,
        collection: col,
        names: names,
      ),
      'gallery_': galleryView(
        l,
        pro ? await _pictures(l, thumbnail) : const [],
        vi: vi,
        pro: pro,
        names: names,
      ),
    };
    for (final MapEntry(key: prefix, value: v) in views.entries) {
      await feeds[prefix]!.publish(v.styled(style));
    }
  }

  /// Small copies of the gallery's pictures in the app's own files, where
  /// the widget can read them; rewritten only when an item's picture is new.
  Future<List<(Bookmark, String)>> _pictures(
    SaveLibrary l,
    Future<Uint8List?> Function(String id) thumbnail,
  ) async {
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/widget',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final out = <(Bookmark, String)>[];
    for (final b in _live(l).take(24)) {
      if (out.length == 4) break;
      final bytes = await thumbnail(b.id);
      if (bytes == null || bytes.isEmpty) continue;
      final file = File('${dir.path}/g${out.length}.jpg');
      final key = Object.hash(b.id, bytes.length);
      if (_written[file.path] != key || !file.existsSync()) {
        await file.writeAsBytes(bytes, flush: true);
        _written[file.path] = key;
      }
      out.add((b, file.path));
    }
    return out;
  }

  /// Links from widget taps.
  Stream<Uri> links() => feeds['save_']!.links().handleError((Object _) {});

  void dispose() => _debounce?.cancel();
}
