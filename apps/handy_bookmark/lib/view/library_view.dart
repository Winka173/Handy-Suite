import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';

/// Where the person is looking: one of the fixed places, a collection, a
/// smart collection or a tag. [broken] holds links whose last check found a
/// problem.
enum Place {
  inbox,
  all,
  favorites,
  unread,
  archive,
  collection,
  smart,
  tag,
  broken,
}

/// Optional narrowing on top of the place (the Filters sheet).
class Filters {
  final String? platform, contentType, tag;
  final String sort;
  final String? savedAfter, savedBefore;
  const Filters({
    this.platform,
    this.contentType,
    this.tag,
    this.sort = 'newest',
    this.savedAfter,
    this.savedBefore,
  });
  bool get any =>
      platform != null ||
      contentType != null ||
      tag != null ||
      sort != 'newest' ||
      savedAfter != null ||
      savedBefore != null;
}

/// The list on screen: what is asked, what came back, what is selected.
/// Results are paged from the store; a newer request always wins.
class LibraryView extends ChangeNotifier {
  final SaveController c;
  LibraryView(this.c) {
    c.addListener(_libraryChanged);
  }

  static const page = 60;
  Place place = Place.all;
  String? id; // collection, smart collection or tag id
  String text = '';
  Filters filters = const Filters();
  List<Bookmark> results = [];
  int total = 0, _revision = 0;
  bool loading = true, failed = false;
  final selected = <String>{};

  SaveLibrary? _undoBefore, _undoAfter;
  Timer? _debounce;
  bool get selecting => selected.isNotEmpty;
  bool get canUndo => _undoAfter != null && identical(c.library, _undoAfter);

  void _libraryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), reload);
  }

  void show(Place p, [String? which]) {
    place = p;
    id = which;
    selected.clear();
    reload();
  }

  /// The list is in the person's own order.
  bool get manual => filters.sort == 'manual';

  /// Worth saving as a search: some words or a filter beyond the place.
  bool get canSaveSearch => text.trim().isNotEmpty || filters.any;

  /// What a saved search keeps: the query in the shared [SearchQuery] shape
  /// (so imports remap its collection) plus the place it was made in.
  Map<String, dynamic> savedQuery() => {
    ...query,
    'place': place.name,
    if (id != null && place != Place.collection) 'placeId': id,
  };

  /// Shows a saved search: its place, words and filters. Searches saved by
  /// the earlier app (no `place`) are read from their flags.
  void applySaved(SavedSearch s) {
    final q = s.query;
    final lib = c.library!;
    final tags = (q['tags'] as List? ?? []).whereType<String>().toList();
    var p = Place.values.where((x) => x.name == q['place']).firstOrNull;
    p ??= q['collectionId'] != null
        ? Place.collection
        : q['isFavorite'] == true
        ? Place.favorites
        : q['isArchived'] == true
        ? Place.archive
        : q['isRead'] == false
        ? Place.unread
        : Place.all;
    String? which = switch (p) {
      Place.collection => q['collectionId'] as String?,
      Place.smart || Place.tag => q['placeId'] as String?,
      _ => null,
    };
    final gone = switch (p) {
      Place.collection => !lib.collections.any((x) => x.id == which),
      Place.smart => !lib.smartCollections.any((x) => x.id == which),
      Place.tag => which == null,
      _ => false,
    };
    if (gone) {
      p = Place.all;
      which = null;
    }
    final rest = [
      for (final t in tags)
        if (!(p == Place.tag && t == which)) t,
    ];
    place = p;
    id = which;
    text = q['text'] as String? ?? '';
    filters = Filters(
      platform: q['platform'] as String?,
      contentType: q['contentType'] as String?,
      tag: rest.firstOrNull,
      sort: q['sort'] as String? ?? 'newest',
      savedAfter: q['savedAfter'] as String?,
      savedBefore: q['savedBefore'] as String?,
    );
    selected.clear();
    reload();
  }

  void search(String value) {
    text = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), reload);
  }

  void filter(Filters f) {
    filters = f;
    reload();
  }

  Map<String, dynamic> get query => {
    ...SearchQuery(
      text: text,
      platform: filters.platform,
      contentType: filters.contentType,
      collectionId: place == Place.collection ? id : null,
      tags: [
        if (place == Place.tag) id!,
        if (filters.tag != null) filters.tag!,
      ],
      isFavorite: place == Place.favorites ? true : null,
      isArchived: place == Place.archive
          ? true
          : (place == Place.smart || place == Place.broken ? null : false),
      isRead: place == Place.unread ? false : null,
      linkIssue: place == Place.broken ? true : null,
      savedAfter: filters.savedAfter,
      savedBefore: filters.savedBefore,
    ).toJson(),
    'sort': filters.sort,
    'inbox': place == Place.inbox,
    'smartCollectionId': place == Place.smart ? id : null,
  };

  Future<List<Bookmark>> _fetch(int offset, int limit) async {
    final lib = c.library!;
    if (place == Place.smart) {
      final rule = lib.smartCollections.where((s) => s.id == id).firstOrNull;
      if (rule == null) return [];
      final all = searchBookmarks(
        lib,
        SearchQuery.fromJson(query),
        smartCollection: rule,
      );
      total = all.length;
      return all.skip(offset).take(limit).toList();
    }
    final r = await c.store!.search(query, offset: offset, limit: limit);
    total = r['total'] as int;
    return [
      for (final v in r['bookmarks'] as List)
        Bookmark.fromJson(Map<String, dynamic>.from(v)),
    ];
  }

  Future<void> reload() async {
    if (_disposed || c.library == null || c.store == null) return;
    final mine = ++_revision;
    try {
      final rows = await _fetch(0, page);
      if (mine != _revision) return;
      results = rows;
      selected.removeWhere((s) => !c.library!.bookmarks.any((b) => b.id == s));
      failed = false;
    } catch (_) {
      if (mine != _revision) return;
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  /// The next page, when the list is scrolled near its end.
  Future<void> more() async {
    if (results.length >= total) return;
    final mine = _revision;
    final rows = await _fetch(results.length, page);
    if (mine != _revision) return;
    results = [...results, ...rows];
    notifyListeners();
  }

  void toggle(String bookmarkId) {
    selected.contains(bookmarkId)
        ? selected.remove(bookmarkId)
        : selected.add(bookmarkId);
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  /// Ids of every bookmark the current view matches, in its order.
  Future<List<String>> allIds() async {
    final ids = <String>[];
    for (var offset = 0; offset < total; offset += 500) {
      ids.addAll((await _fetch(offset, 500)).map((b) => b.id));
    }
    return ids;
  }

  /// Every bookmark the current view matches, not only the loaded page.
  Future<void> selectAll() async {
    final ids = await allIds();
    selected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Changes the library and remembers the step so it can be undone once.
  Future<void> change(
    SaveLibrary Function(SaveLibrary) edit, {
    Map<String, dynamic>? prefs,
  }) async {
    final before = c.library!;
    await c.update(edit, prefs: prefs);
    _undoBefore = before;
    _undoAfter = c.library;
    notifyListeners();
  }

  /// Puts back the library from before the last change, if nothing else
  /// changed since.
  Future<bool> undo() async {
    if (!canUndo) return false;
    final before = _undoBefore!;
    await c.update((_) => before);
    _undoBefore = _undoAfter = null;
    notifyListeners();
    return true;
  }

  /// Applies [edit] to every selected bookmark.
  Future<void> batch(Bookmark Function(Bookmark) edit) {
    final ids = {...selected};
    final now = saveTime();
    return change(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            ids.contains(b.id) ? edit(b).copyWith(updatedAt: now) : b,
        ],
      ),
    );
  }

  Future<void> deleteSelected() {
    final ids = {...selected};
    selected.clear();
    return change(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            if (!ids.contains(b.id)) b,
        ],
      ),
    );
  }

  bool _disposed = false;

  /// A reload can finish after the screen has gone; then nobody listens.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    c.removeListener(_libraryChanged);
    _debounce?.cancel();
    super.dispose();
  }
}
