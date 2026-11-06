import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:url_launcher/url_launcher.dart';
import 'platform/store.dart';
import 'services/metadata_client.dart';
import 'services/share_inbox.dart';

String saveId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256),
).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
String saveTime() => DateTime.now().toUtc().toIso8601String();
SaveLibrary _decodeLibrary(Map<String, dynamic> raw) {
  final state = Map<String, dynamic>.from(raw['state'] as Map? ?? {});
  // Schema 1 kept the manual order in preferences; schema 2 in the library,
  // so backups carry it.
  final legacy = (state['preferences'] as Map?)?['bookmarkOrder'];
  if (state['manualOrder'] == null && legacy is List)
    state['manualOrder'] = legacy.whereType<String>().toList();
  return SaveLibrary.fromJson({
    'version': 1,
    ...state,
    'bookmarks': raw['bookmarks'] ?? [],
  });
}

class SaveController extends ChangeNotifier {
  final Future<BookmarkStore> Function() openStore;
  final SaveShareInbox inbox;
  final MetadataClient metadata;
  BookmarkStore? store;
  SaveLibrary? library;
  Map<String, dynamic> preferences = {};
  String? error, notice, highlighted;
  final invalidShares = <SharedLink>[];
  final fetching = <String, CancellationToken>{};
  Future<void> _writes = Future.value();
  bool disposed = false, draining = false;
  bool _again = false;
  final _thumbnails = <String, Future<Uint8List?>>{};
  String? clipboardHash;

  /// Bookmarks with an offline reading copy, and when it was saved.
  Map<String, String> readingIds = {};
  SaveController({
    Future<BookmarkStore> Function()? open,
    SaveShareInbox? shares,
    MetadataClient? metadataClient,
  }) : openStore = open ?? openBookmarkStore,
       inbox = shares ?? SaveShareInbox(),
       metadata = metadataClient ?? MetadataClient();
  void changed() {
    if (!disposed) notifyListeners();
  }

  Future<void> initialize() async {
    try {
      error = null;
      if (store != null) {
        try {
          await store!.close();
        } catch (_) {}
        store = null;
      }
      store = await openStore();
      final raw = await store!.read();
      library = await compute(_decodeLibrary, raw);
      preferences = Map<String, dynamic>.from(
        (raw['state'] as Map?)?['preferences'] as Map? ?? {},
      )..remove('bookmarkOrder');
      try {
        readingIds = await store!.readingIndex();
      } catch (_) {
        // Copies are optional; the links still open.
        readingIds = {};
      }
      await inbox.start(
        () => unawaited(drain()),
        (text) => unawaited(
          quickSave(text).then<void>((_) {}).catchError((Object _) {
            error = 'invalid_url';
            changed();
          }),
        ),
        () {
          error = 'share_failed';
          changed();
        },
      );
      changed();
      await drain();
    } catch (_) {
      error = 'storage_failed';
      changed();
    }
  }

  Future<void> update(
    SaveLibrary Function(SaveLibrary) change, {
    Map<String, dynamic>? prefs,
  }) {
    final done = Completer<void>();
    _writes = _writes.then((_) async {
      try {
        if (library == null || store == null)
          throw StateError('Storage not ready');
        final before = library!,
            next = change(before),
            beforeMap = {for (final b in before.bookmarks) b.id: b},
            ids = next.bookmarks.map((b) => b.id).toSet();
        final upserts = [
          for (final b in next.bookmarks)
            if (!identical(b, beforeMap[b.id])) b.toJson(),
        ];
        final state = next.toJson()..remove('bookmarks');
        state['preferences'] = prefs ?? preferences;
        final deleted = {
          for (final b in before.bookmarks)
            if (!ids.contains(b.id)) b.id,
        };
        await store!.write(
          upserts: upserts,
          deletes: deleted.toList(),
          settings: state,
        );
        library = next;
        // The store atomically retains/restores copies alongside link writes.
        // An index refresh is optional UI state: its failure must not turn a
        // committed write into a reported storage failure.
        if (deleted.isNotEmpty ||
            upserts.any((b) => !beforeMap.containsKey(b['id']))) {
          try {
            readingIds = await store!.readingIndex();
          } catch (_) {
            readingIds = {
              for (final e in readingIds.entries)
                if (ids.contains(e.key)) e.key: e.value,
            };
          }
        }
        if (prefs != null) preferences = Map.of(prefs);
        error = null;
        changed();
        done.complete();
      } catch (e) {
        error = 'storage_failed';
        changed();
        done.completeError(e);
      }
    });
    return done.future;
  }

  Future<List<Bookmark>> quickSave(
    String text, {
    String? title,
    bool allowDuplicates = false,
  }) async {
    try {
      final urls = UrlTools.extract(text);
      if (urls.isEmpty) throw const FormatException('No URL');
      final saved = <Bookmark>[];
      await update((current) {
        final list = [...current.bookmarks],
            known = {
              for (final b in current.bookmarks) b.normalizedUrl: b,
              for (final b in current.bookmarks)
                UrlTools.normalize(b.originalUrl).canonicalUrl: b,
            };
        for (final u in urls) {
          final existing = known[u.normalizedUrl] ?? known[u.canonicalUrl];
          if (existing != null && !allowDuplicates) {
            saved.add(existing);
            continue;
          }
          final now = saveTime(),
              b = Bookmark(
                id: saveId(),
                originalUrl: u.originalUrl,
                normalizedUrl: u.normalizedUrl,
                canonicalUrl: u.canonicalUrl,
                platform: u.platform,
                contentType: u.contentType,
                sourceDomain: u.sourceDomain,
                title: title?.trim().isNotEmpty == true
                    ? title!.trim()
                    : u.sourceDomain,
                savedAt: now,
                updatedAt: now,
                metadataStatus: 'unavailable',
                metadataSource: title == null ? 'fallback' : 'share',
              );
          list.add(b);
          known[b.normalizedUrl] = b;
          known[u.canonicalUrl] = b;
          saved.add(b);
        }
        return current.copyWith(bookmarks: list);
      });
      highlighted = saved.last.id;
      notice = 'saved';
      changed();
      if (preferences['automaticMetadata'] == true) {
        for (final b in saved) {
          unawaited(refreshMetadata(b.id));
        }
      }
      return saved;
    } catch (_) {
      if (error != 'storage_failed') error = 'invalid_url';
      changed();
      rethrow;
    }
  }

  Future<void> drain() async {
    if (draining) {
      _again = true;
      return;
    }
    if (library == null || disposed) return;
    draining = true;
    try {
      final pending = await inbox.drain();
      for (final share in pending) {
        try {
          await quickSave(share.text, title: share.title);
          await inbox.acknowledge(share.id);
        } catch (_) {
          if (!invalidShares.any((s) => s.id == share.id))
            invalidShares.add(share);
          error = 'share_failed';
          changed();
        }
      }
    } catch (_) {
      error = 'share_failed';
      changed();
    } finally {
      draining = false;
      if (_again) {
        _again = false;
        unawaited(drain());
      }
    }
  }

  Future<void> discardShare(SharedLink share) async {
    await inbox.acknowledge(share.id);
    invalidShares.removeWhere((s) => s.id == share.id);
    error = null;
    changed();
  }

  Future<String?> clipboard() async {
    final value = (await Clipboard.getData('text/plain'))?.text;
    if (value == null) return null;
    final hash = sha256.convert(utf8.encode(value)).toString();
    if (hash == clipboardHash) {
      notice = 'clipboard_seen';
      changed();
      return null;
    }
    clipboardHash = hash;
    return value;
  }

  Future<void> put(Bookmark value) => update(
    (s) => s.copyWith(
      bookmarks: [
        for (final b in s.bookmarks)
          if (b.id == value.id) value else b,
      ],
    ),
  );
  Future<bool> open(Bookmark b, {bool browser = false}) async {
    final u = UrlTools.normalize(b.originalUrl);
    if (!{
      'https',
      'http',
    }.contains(Uri.parse(u.originalUrl).scheme.toLowerCase()))
      return false;
    await put(
      b.copyWith(
        openedCount: b.openedCount + 1,
        lastOpenedAt: saveTime(),
        updatedAt: saveTime(),
      ),
    );
    final mode = browser
        ? 'external'
        : preferences['openingMode'] as String? ?? 'system';
    var ok = false;
    if (mode == 'app') {
      try {
        ok = await launchUrl(
          Uri.parse(b.originalUrl),
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } catch (_) {
        ok = false;
      }
    }
    if (!ok)
      ok = await launchUrl(
        Uri.parse(b.originalUrl),
        mode: LaunchMode.externalApplication,
      );
    if (!ok) {
      error = 'open_failed';
      changed();
    }
    return ok;
  }

  Future<void> refreshMetadata(String id) async {
    if (fetching.containsKey(id) || library == null) return;
    final b = library!.bookmarks.where((b) => b.id == id).firstOrNull;
    if (b == null) return;
    final token = CancellationToken();
    fetching[id] = token;
    changed();
    try {
      final result = await metadata.fetch(b.originalUrl, cancellation: token);
      token.check();
      await update(
        (s) => s.copyWith(
          bookmarks: [
            for (final current in s.bookmarks)
              if (current.id != id || current.originalUrl != b.originalUrl)
                current
              else
                current.copyWith(
                  title:
                      current.metadataSource == 'user' ||
                          current.metadataSource == 'share'
                      ? current.title
                      : (result.title ?? current.title),
                  description: current.metadataSource == 'user'
                      ? current.description
                      : (result.description ?? current.description),
                  siteName: result.siteName ?? current.siteName,
                  author: result.author ?? current.author,
                  canonicalUrl: result.canonicalUrl ?? current.canonicalUrl,
                  thumbnailUrl: result.thumbnailUrl ?? current.thumbnailUrl,
                  metadataStatus: result.status,
                  metadataSource: current.metadataSource == 'user'
                      ? 'user'
                      : 'html',
                  updatedAt: saveTime(),
                ),
          ],
        ),
      );
      if (result.thumbnailUrl != null) {
        final thumbnail = await metadata.fetchThumbnail(
          result.thumbnailUrl!,
          cancellation: token,
        );
        token.check();
        if (thumbnail.bytes != null &&
            library!.bookmarks.any((b) => b.id == id)) {
          await store!.putThumbnail(id, thumbnail.bytes!);
          _thumbnails.remove(id);
        }
      }
    } catch (_) {
      if (!disposed) notice = 'metadata_unavailable';
    } finally {
      fetching.remove(id);
      changed();
    }
  }

  /// Network-backed tools (reading copies, link checks) are off in the
  /// browser, which cannot guarantee the safe network policy.
  bool get networkAvailable => metadata.available;

  /// The stored copy, or null; a damaged one reads as missing.
  Future<ReadingCopy?> readingCopy(String id) async {
    final raw = await store!.readingCopy(id);
    if (raw == null) return null;
    try {
      return ReadingCopy.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  Future<void> putReadingCopies(Map<String, ReadingCopy> copies) async {
    if (copies.isEmpty) return;
    await store!.putReadingCopies({
      for (final e in copies.entries) e.key: e.value.toJson(),
    });
    readingIds = {
      ...readingIds,
      for (final e in copies.entries) e.key: e.value.savedAt,
    };
    changed();
  }

  Future<void> deleteReadingCopy(String id) async {
    await store!.deleteReadingCopy(id);
    readingIds = {...readingIds}..remove(id);
    changed();
  }

  /// Every valid stored copy, for a full backup.
  Future<Map<String, ReadingCopy>> allReadingCopies() async {
    final out = <String, ReadingCopy>{};
    for (final e in (await store!.readingCopies()).entries) {
      try {
        out[e.key] = ReadingCopy.fromJson(e.value);
      } on FormatException {
        // A damaged copy is left out of the backup rather than failing it.
      }
    }
    return out;
  }

  /// Re-reads visible copies after import, reset, deletion or Undo.
  Future<void> refreshReading() async {
    try {
      readingIds = await store!.readingIndex();
    } catch (_) {
      readingIds = {};
    }
    changed();
  }

  Future<Uint8List?> thumbnail(String id) {
    if (!_thumbnails.containsKey(id) && _thumbnails.length >= 32)
      _thumbnails.remove(_thumbnails.keys.first);
    return _thumbnails.putIfAbsent(id, () => store!.thumbnail(id));
  }

  void thumbnailChanged(String id) {
    _thumbnails.remove(id);
    changed();
  }

  void clearThumbnailMemory() {
    _thumbnails.clear();
    changed();
  }

  @override
  void dispose() {
    disposed = true;
    for (final t in fetching.values) t.cancel();
    inbox.dispose();
    metadata.dispose();
    if (store != null) unawaited(store!.close());
    super.dispose();
  }
}
