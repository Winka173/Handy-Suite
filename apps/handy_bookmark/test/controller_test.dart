import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/platform/store.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

class TestStore implements BookmarkStore {
  final rows = <String, Map<String, dynamic>>{};
  Map<String, dynamic> state = {};
  final reading = <String, Map<String, dynamic>>{};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> read() async => {
    'bookmarks': rows.values.toList(),
    'state': state,
  };
  @override
  Future<void> write({
    List<Map<String, dynamic>> upserts = const [],
    List<String> deletes = const [],
    Map<String, dynamic>? settings,
    bool replace = false,
  }) async {
    if (fail) throw StateError('Disk full');
    if (replace) {
      rows.clear();
      reading.clear();
    }
    for (final id in deletes) {
      rows.remove(id);
      reading.remove(id);
    }
    for (final b in upserts) rows[b['id'] as String] = Map.of(b);
    if (settings != null) state = Map.of(settings);
  }

  @override
  Future<Map<String, dynamic>> search(
    Map<String, dynamic> q, {
    int offset = 0,
    int limit = 100,
  }) async {
    final library = SaveLibrary.fromJson({
      ...state,
      'bookmarks': rows.values.toList(),
    });
    var list = searchBookmarks(
      library,
      SearchQuery.fromJson(q),
    ).where((b) => q['inbox'] != true || b.collectionId == null).toList();
    // Pinned first, like the real stores.
    list = [
      ...list.where((b) => b.isPinned),
      ...list.where((b) => !b.isPinned),
    ];
    return {
      'bookmarks': list
          .skip(offset)
          .take(limit)
          .map((b) => b.toJson())
          .toList(),
      'total': list.length,
    };
  }

  @override
  Future<void> clearThumbnails() async {}
  @override
  Future<void> close() async {}
  @override
  Future<String> integrity() async => 'ok';
  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async {}
  @override
  Future<Uint8List?> thumbnail(String id) async => null;
  @override
  Future<Map<String, dynamic>?> readingCopy(String id) async => reading[id];
  @override
  Future<void> putReadingCopies(
    Map<String, Map<String, dynamic>> copies,
  ) async {
    if (fail) throw StateError('Disk full');
    if (copies.keys.any((id) => !rows.containsKey(id)))
      throw StateError('Bookmark not found');
    reading.addAll(copies);
  }

  @override
  Future<void> deleteReadingCopy(String id) async => reading.remove(id);
  @override
  Future<Map<String, String>> readingIndex() async => {
    for (final e in reading.entries) e.key: e.value['savedAt'] as String,
  };
  @override
  Future<Map<String, Map<String, dynamic>>> readingCopies() async =>
      Map.of(reading);
  @override
  Future<void> clearReadingCopies() async => reading.clear();
}

class TestInbox extends SaveShareInbox {
  List<SharedLink> pending = [];
  final acknowledgments = <String>[];
  @override
  Future<void> start(
    void Function() incoming,
    void Function(String) dropped,
    void Function() failed,
  ) async {}
  @override
  Future<List<SharedLink>> drain() async => List.of(pending);
  @override
  Future<void> acknowledge(String id) async {
    acknowledgments.add(id);
    pending.removeWhere((s) => s.id == id);
  }

  @override
  void dispose() {}
}

void main() {
  test(
    'durable share ack follows committed storage; failure preserves incoming delivery and saved data',
    () async {
      final store = TestStore(),
          inbox = TestInbox()
            ..pending = [
              const SharedLink(
                'one',
                'Look https://youtu.be/dQw4w9WgXcQ\nhttps://github.com/flutter/flutter',
                'Shared title',
              ),
            ];
      final c = SaveController(open: () async => store, shares: inbox);
      await c.initialize();
      expect(store.rows.length, 2);
      expect(inbox.acknowledgments, ['one']);
      expect(c.adsVisible.value, isFalse);
      inbox.pending = [
        const SharedLink(
          'two',
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=test',
          null,
        ),
      ];
      await c.drain();
      expect(store.rows.length, 2);
      expect(inbox.acknowledgments, ['one', 'two']);
      store.fail = true;
      inbox.pending = [
        const SharedLink('three', 'https://example.org/new', null),
      ];
      await c.drain();
      expect(store.rows.length, 2);
      expect(inbox.pending.single.id, 'three');
      expect(inbox.acknowledgments, hasLength(2));
      store.fail = false;
      await c.drain();
      expect(store.rows.length, 3);
      expect(inbox.acknowledgments.last, 'three');
      c.dispose();
    },
  );
  test(
    'explicit duplicate keeps notes; add anyway makes a new record; no implicit network',
    () async {
      final store = TestStore(),
          c = SaveController(open: () async => store, shares: TestInbox());
      await c.initialize();
      final first = (await c.quickSave(
        'https://example.com/item?sku=1',
      )).single;
      await c.put(
        first.copyWith(
          note: 'Keep private note',
          title: 'My title',
          metadataSource: 'user',
        ),
      );
      final duplicate = (await c.quickSave(
        'https://example.com/item?sku=1&utm_source=share',
      )).single;
      expect(duplicate.id, first.id);
      expect(duplicate.note, 'Keep private note');
      expect(c.fetching, isEmpty);
      await c.quickSave(
        'https://example.com/item?sku=1',
        allowDuplicates: true,
      );
      expect(c.library!.bookmarks, hasLength(2));
      await c.quickSave('https://example.com/item?sku=2');
      expect(c.library!.bookmarks, hasLength(3));
      c.dispose();
    },
  );
}
