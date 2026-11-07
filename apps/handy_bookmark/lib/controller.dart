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
import 'services/media_import.dart';
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
    'trash': raw['trash'] ?? [],
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

  /// Pages turned away by a login page: how often, and the retries waiting.
  final _wallTries = <String, int>{};
  final _later = <Timer>[];
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
      final opened = DateTime.now();
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
      unawaited(_retryMissing());
      await tidy(opened);
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
            ids = next.bookmarks.map((b) => b.id).toSet(),
            beforeTrash = {for (final b in before.trash) b.id: b},
            trashIds = next.trash.map((b) => b.id).toSet();
        final upserts = [
          for (final b in next.bookmarks)
            if (!identical(b, beforeMap[b.id])) b.toJson(),
        ];
        // Recently Deleted rows travel in the same transaction, so an item
        // is never in both places nor in neither.
        final trashUpserts = [
          for (final b in next.trash)
            if (!identical(b, beforeTrash[b.id])) b.toJson(),
        ];
        final trashDeletes = [
          for (final b in before.trash)
            if (!trashIds.contains(b.id)) b.id,
        ];
        final state = next.toJson()
          ..remove('bookmarks')
          ..remove('trash');
        state['preferences'] = prefs ?? preferences;
        final deleted = {
          for (final b in before.bookmarks)
            if (!ids.contains(b.id)) b.id,
        };
        await store!.write(
          upserts: upserts,
          deletes: deleted.toList(),
          settings: state,
          trashUpserts: trashUpserts,
          trashDeletes: trashDeletes,
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

  /// Housekeeping, at defined moments (opening the library, before an
  /// automatic backup): items in Recently Deleted for 30 days go for good,
  /// deletions remembered for sync longer than [tombstoneRetention] are
  /// forgotten, and pictures that neither an item nor a Trash item uses
  /// are reclaimed. Never fails the library: a later moment tries again.
  Future<void> tidy([DateTime? at]) async {
    final now = at ?? DateTime.now();
    SaveLibrary next(SaveLibrary l) =>
        pruneTombstones(expireTrash(l, now), now);
    try {
      if (library == null || store == null) return;
      if (!identical(next(library!), library)) await update(next);
    } catch (_) {
      /* Housekeeping only; nothing the person did is lost. */
    }
    try {
      // Live and Trash pictures are kept (the store also checks its own
      // rows), and so is any picture stored within [mediaGrace].
      await store?.collectMedia(mediaInUse(library!));
    } catch (_) {
      /* Reclaiming space can wait. */
    }
  }

  /// Saves the links in [text]. With [collectionId] (a share sent to one
  /// of the person's collections) new links go into it, and a link already
  /// saved but not yet sorted is moved into it.
  Future<List<Bookmark>> quickSave(
    String text, {
    String? title,
    bool allowDuplicates = false,
    String? collectionId,
  }) async {
    try {
      final urls = UrlTools.extract(text);
      if (urls.isEmpty) throw const FormatException('No URL');
      final saved = <Bookmark>[];
      await update((current) {
        final into = current.collections.any((c) => c.id == collectionId)
            ? collectionId
            : null;
        final list = [...current.bookmarks],
            // Picture items have no address and never match a link.
            known = {
              for (final b in current.bookmarks)
                if (b.hasUrl) b.normalizedUrl: b,
              for (final b in current.bookmarks)
                if (b.hasUrl) UrlTools.normalize(b.originalUrl).canonicalUrl: b,
            };
        for (final u in urls) {
          final existing = known[u.normalizedUrl] ?? known[u.canonicalUrl];
          if (existing != null && !allowDuplicates) {
            if (into != null && existing.collectionId == null) {
              final moved = existing.copyWith(
                collectionId: into,
                updatedAt: saveTime(),
              );
              list[list.indexWhere((b) => b.id == existing.id)] = moved;
              known[u.normalizedUrl] = moved;
              known[u.canonicalUrl] = moved;
              saved.add(moved);
            } else {
              saved.add(existing);
            }
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
                collectionId: into,
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
      // On unless switched off: a save brings its title and picture.
      if (preferences['automaticMetadata'] != false) {
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
          // Pictures first, then any link alongside them; the delivery is
          // acknowledged (and its files deleted) only after both committed.
          if (share.images.isNotEmpty) {
            final into =
                library!.collections.any((c) => c.id == share.collection)
                ? share.collection
                : null;
            await addPictures([
              for (final i in share.images)
                (bytes: await inbox.readImage(i.path), name: i.name),
            ], collectionId: into);
            if (UrlTools.extract(share.text).isNotEmpty)
              await quickSave(
                share.text,
                title: share.title,
                collectionId: share.collection,
              );
          } else {
            await quickSave(
              share.text,
              title: share.title,
              collectionId: share.collection,
            );
          }
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
    if (!b.hasUrl) return false;
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
      var result = await metadata.fetch(b.originalUrl, cancellation: token);
      // Asked too soon after another page of the same site, or two pages
      // already reading: wait a moment and ask again.
      for (
        var tries = 0;
        tries < 4 && {'rateLimited', 'busy'}.contains(result.errorCode);
        tries++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        token.check();
        result = await metadata.fetch(b.originalUrl, cancellation: token);
      }
      token.check();
      // Facebook and Instagram sometimes answer with their login page (a
      // title that only names the site, no picture) and the real page a
      // little later: not a title to keep; asked again shortly, and when
      // the app next opens.
      if (_loginWall(b, result)) {
        result = const MetadataResult(status: 'failed', errorCode: 'loginWall');
        if ((_wallTries[id] = (_wallTries[id] ?? 0) + 1) <= 1) {
          _later.add(
            Timer(const Duration(seconds: 45), () {
              if (!disposed) unawaited(refreshMetadata(id));
            }),
          );
        }
      }
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
                          (current.metadataSource == 'share' &&
                              !_genericTitle(current, result))
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

  /// A title an app shared that only names the site ("Facebook",
  /// "youtube.com"): the page's own title says more.
  static bool _genericTitle(Bookmark b, MetadataResult r) {
    if (r.title == null) return _bare(b.title).isEmpty;
    return _onlyNamesSite(b, b.title, r.siteName);
  }

  static String _bare(String? v) =>
      (v ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Whether [text] is no more than the site's name or address.
  static bool _onlyNamesSite(Bookmark b, String? text, String? siteName) {
    final bare = _bare(text);
    if (bare.isEmpty) return true;
    final host = b.sourceDomain.toLowerCase().replaceFirst(
      RegExp(r'^(www|m|mobile)\.'),
      '',
    );
    return {
      _bare(host),
      _bare(host.split('.').first),
      _bare(siteName),
      _bare(b.platform),
    }.contains(bare);
  }

  /// A Facebook or Instagram login page in place of the post or reel.
  static bool _loginWall(Bookmark b, MetadataResult r) =>
      {'facebook', 'instagram'}.contains(b.platform) &&
      r.thumbnailUrl == null &&
      (_onlyNamesSite(b, r.title, r.siteName) ||
          RegExp(
            r'log ?in|sign up|đăng nhập',
            caseSensitive: false,
          ).hasMatch(r.title!));

  /// Links saved lately that have no picture on this device (the page could
  /// not be read, showed a login page, or its picture did not arrive) are
  /// asked again once each time the app opens, one at a time, newest first.
  Future<void> _retryMissing() async {
    if (preferences['automaticMetadata'] == false || !metadata.available) {
      return;
    }
    final since = DateTime.now().subtract(const Duration(days: 30));
    final missing =
        library!.bookmarks
            .where(
              (b) =>
                  b.kind != 'image' &&
                  b.originalUrl.isNotEmpty &&
                  b.metadataSource != 'user' &&
                  ({'unavailable', 'failed'}.contains(b.metadataStatus) ||
                      // Its picture is known but never arrived.
                      b.thumbnailUrl != null ||
                      // Read before, but only a login page came back.
                      (b.metadataStatus == 'partial' &&
                          {'facebook', 'instagram'}.contains(b.platform) &&
                          _onlyNamesSite(b, b.title, null))) &&
                  (DateTime.tryParse(b.savedAt)?.isAfter(since) ?? false),
            )
            .toList()
          ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    var asked = 0;
    for (final b in missing) {
      if (disposed || asked >= 12) return;
      // Only those with no picture on this device.
      if (await thumbnail(b.id) != null) continue;
      asked++;
      await refreshMetadata(b.id);
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

  /// Stores [copies] for items in the library or in Recently Deleted (a
  /// restored backup brings both); only the first show as readable.
  Future<void> putReadingCopies(Map<String, ReadingCopy> copies) async {
    if (copies.isEmpty) return;
    await store!.putReadingCopies({
      for (final e in copies.entries) e.key: e.value.toJson(),
    });
    final live = {for (final b in library?.bookmarks ?? <Bookmark>[]) b.id};
    readingIds = {
      ...readingIds,
      for (final e in copies.entries)
        if (live.contains(e.key)) e.key: e.value.savedAt,
    };
    changed();
  }

  Future<void> deleteReadingCopy(String id) async {
    await store!.deleteReadingCopy(id);
    readingIds = {...readingIds}..remove(id);
    changed();
  }

  /// Every valid stored copy, for a full backup.
  Future<Map<String, ReadingCopy>> allReadingCopies() async =>
      (await readingCopiesForBackup()).copies;

  /// Every valid stored copy (of items and of those in Recently Deleted),
  /// and how many could not be read. A damaged
  /// copy is left out of the backup rather than failing it, but counted,
  /// so the backup never claims to hold it. When the copies cannot be read
  /// at all, every copy the index knows of counts as unreadable.
  Future<({Map<String, ReadingCopy> copies, int unreadable})>
  readingCopiesForBackup() async {
    final Map<String, Map<String, dynamic>> raw;
    try {
      raw = await store!.readingCopies();
    } catch (_) {
      return (copies: <String, ReadingCopy>{}, unreadable: readingIds.length);
    }
    final out = <String, ReadingCopy>{};
    var unreadable = 0;
    for (final e in raw.entries) {
      try {
        out[e.key] = ReadingCopy.fromJson(e.value);
      } on FormatException {
        unreadable++;
      } on TypeError {
        unreadable++;
      }
    }
    return (copies: out, unreadable: unreadable);
  }

  /// What the last automatic backup held and left out; null before the
  /// first one. Kept in this device's settings, never in a backup.
  BackupReport? get lastBackup =>
      BackupReport.fromJson(preferences[lastBackupKey]);
  static const lastBackupKey = 'lastBackup';

  /// Keeps [report] as [lastBackup]. A failure here never fails the backup.
  Future<void> recordBackup(BackupReport report) async {
    try {
      await update(
        (l) => l,
        prefs: {...preferences, lastBackupKey: report.toJson()},
      );
    } catch (_) {
      /* The backup itself was built; only its report is not kept. */
    }
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

  final _previews = <String, Future<Uint8List?>>{};

  /// Saves pictures (screenshots, photos) as image items, each stored once
  /// by its content. Every picture is checked and prepared off the UI
  /// isolate first; nothing is written unless all of [files] are usable,
  /// and the items appear only after the database committed them. A
  /// picture already saved as an image item is not saved twice: its item
  /// is returned instead.
  Future<({List<Bookmark> added, List<Bookmark> existing})> addPictures(
    List<({Uint8List bytes, String name})> files, {
    String? collectionId,
  }) async {
    if (files.isEmpty) return (added: <Bookmark>[], existing: <Bookmark>[]);
    final prepared = <PreparedPicture>[];
    for (final f in files) {
      prepared.add(
        await compute(
          (({Uint8List bytes, String name}) f) =>
              preparePicture(f.bytes, name: f.name),
          f,
        ),
      );
    }
    final byMedia = {
      for (final b in library!.bookmarks)
        if (b.isImage) b.media!.id: b,
    };
    final existing = <Bookmark>[];
    final fresh = <Bookmark>[];
    final seen = <String>{};
    for (final p in prepared) {
      final old = byMedia[p.ref.id];
      if (old != null) {
        existing.add(old);
        continue;
      }
      if (!seen.add(p.ref.id)) continue;
      // Stored before the item that uses it, so the item never points at
      // a missing picture; a picture whose item then fails to save is
      // reclaimed later.
      await store!.putMedia(p.ref.toJson(), p.original, p.preview);
      final now = saveTime();
      fresh.add(
        Bookmark(
          id: saveId(),
          kind: 'image',
          originalUrl: '',
          normalizedUrl: '',
          platform: 'image',
          contentType: 'image',
          media: p.ref,
          title: pictureTitle(p.ref.name),
          collectionId: collectionId,
          savedAt: now,
          updatedAt: now,
          metadataStatus: 'unavailable',
          metadataSource: 'local',
        ),
      );
    }
    if (fresh.isNotEmpty)
      await update((l) => l.copyWith(bookmarks: [...l.bookmarks, ...fresh]));
    return (added: fresh, existing: existing);
  }

  /// Checks, prepares and stores one picture; returns its record. The
  /// caller then writes the item that uses it.
  Future<MediaRef> storePicture(Uint8List bytes, {String name = ''}) async {
    final p = await compute(
      (({Uint8List bytes, String name}) f) =>
          preparePicture(f.bytes, name: f.name),
      (bytes: bytes, name: name),
    );
    await store!.putMedia(p.ref.toJson(), p.original, p.preview);
    return p.ref;
  }

  /// The small preview of a picture the person owns.
  Future<Uint8List?> mediaPreview(String mediaId) {
    if (!_previews.containsKey(mediaId) && _previews.length >= 64)
      _previews.remove(_previews.keys.first);
    return _previews.putIfAbsent(
      mediaId,
      () => store!.media(mediaId, preview: true),
    );
  }

  /// The picture itself, as the person saved it.
  Future<Uint8List?> mediaOriginal(String mediaId) => store!.media(mediaId);

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
    for (final t in _later) t.cancel();
    for (final t in fetching.values) t.cancel();
    inbox.dispose();
    metadata.dispose();
    if (store != null) unawaited(store!.close());
    super.dispose();
  }
}
