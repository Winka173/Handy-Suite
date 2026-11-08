import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart';
import '../services/metadata_client.dart';
import '../services/metadata_judge.dart';
import '../ui/collection_picker.dart' show collectionTree;
import 'snapshot.dart';

/// A share as the share sheet receives it: already in the app's private
/// queue (saved) under [id].
class SheetShare {
  final String id, text;
  final String? title;

  /// The collection it arrived in (shared through that collection's
  /// shortcut), chosen to begin with.
  final String? collection;

  /// Pictures the share carried, copied into the queue.
  final List<String> images;
  final SheetSnapshot snapshot;

  /// Earlier shares still waiting for the app to take them in: the places
  /// they were put in, which the snapshot does not know of yet (a new
  /// collection named in another sheet is made only when the app opens).
  final List<QueuedPlace> queued;
  const SheetShare({
    required this.id,
    required this.text,
    this.title,
    this.collection,
    this.images = const [],
    required this.snapshot,
    this.queued = const [],
  });
}

/// Where a share still in the queue goes, and when it arrived.
class QueuedPlace {
  final String? collection, newCollection;
  final DateTime? at;
  const QueuedPlace({this.collection, this.newCollection, this.at});
}

/// A row of the sheet: a collection, or one still to be made.
class SheetPlace {
  final SheetChoice choice;
  final String name;

  /// The collection as the app keeps it; null for one still to be made.
  final SaveCollection? collection;

  /// The parent's name, for a collection inside another.
  final String? parent;
  final int count;

  /// When it last got an item (ms since epoch; 0 for never).
  final int last;

  /// Named in this sheet.
  final bool fresh;
  const SheetPlace({
    required this.choice,
    required this.name,
    this.collection,
    this.parent,
    this.count = 0,
    this.last = 0,
    this.fresh = false,
  });
}

/// The way to the activity that shows the sheet (Android).
class SheetBridge {
  static const channel = MethodChannel('handy.save/sheet');
  const SheetBridge();

  Future<SheetShare> start() async {
    final r = await channel.invokeMapMethod<String, dynamic>('start') ?? {};
    return SheetShare(
      id: r['id'] as String,
      text: r['text'] as String? ?? '',
      title: r['title'] as String?,
      collection: r['collection'] as String?,
      images: [for (final p in r['images'] as List? ?? const []) p as String],
      snapshot: SheetSnapshot.parse(r['snapshot'] as String?),
      queued: [
        for (final q in r['queued'] as List? ?? const [])
          if (q is Map)
            QueuedPlace(
              collection: q['collection'] as String?,
              newCollection: q['newCollection'] as String?,
              at: DateTime.tryParse(q['receivedAt'] as String? ?? ''),
            ),
      ],
    );
  }

  /// Adds the person's choices to the queued share, and closes.
  Future<void> save({
    String? collection,
    String? newCollection,
    MetadataResult? metadata,
    Uint8List? thumbnail,
  }) => channel.invokeMethod<void>('save', {
    'collection': ?collection,
    'newCollection': ?newCollection,
    if (metadata != null)
      'metadata': {
        'title': ?metadata.title,
        'description': ?metadata.description,
        'siteName': ?metadata.siteName,
        'author': ?metadata.author,
        'canonicalUrl': ?metadata.canonicalUrl,
        'thumbnailUrl': ?metadata.thumbnailUrl,
        'contentType': ?metadata.contentType,
        'status': metadata.status,
      },
    'thumbnail': ?thumbnail,
  });

  /// Sets the read-later reminder picked under "Saved in …" (null clears).
  Future<bool> remind(DateTime? at) async =>
      await channel.invokeMethod<bool>('remind', {
        'at': at?.toUtc().toIso8601String(),
      }) ??
      false;

  /// Takes the share back out of the queue, and closes.
  Future<void> discard() => channel.invokeMethod<void>('discard');

  /// Closes; the share stays where it is (Not sorted).
  Future<void> close() => channel.invokeMethod<void>('close');
}

/// Where the share goes: Not sorted, one of the collections, or a new one.
sealed class SheetChoice {
  const SheetChoice();
}

class NotSorted extends SheetChoice {
  const NotSorted();
}

class InCollection extends SheetChoice {
  final String id;
  const InCollection(this.id);
}

class InNewCollection extends SheetChoice {
  final String name;
  const InNewCollection(this.name);
}

/// The sheet's state: the share, what its page said, and the choice.
class SheetController extends ChangeNotifier {
  SheetController({
    this.bridge = const SheetBridge(),
    MetadataClient? metadata,
    this.retryDelay = const Duration(milliseconds: 2200),
    this.confirm = const Duration(milliseconds: 1200),
    this.remindWait = const Duration(milliseconds: 2500),
    this.pictureWait = const Duration(seconds: 4),
    this.scheduler,
  }) : _metadata = metadata;

  /// How long "Saved in …" stays when "Remind me" is offered under it.
  final Duration remindWait;

  /// Schedules the reminder's notification under the share's id (asking
  /// for the permission); false when notifications are not allowed. Null
  /// where this device has no notifications: "Remind me" is not offered.
  final Future<bool> Function(String shareId, String title, DateTime at)?
  scheduler;

  /// The person touched "Remind me": the sheet stays until they pick.
  bool holding = false;

  /// The reminder picked here, shown as "Reminding …" before closing.
  DateTime? remindAt;

  /// Notifications could not be allowed: the reminder is kept on the item.
  bool remindBlocked = false;

  /// "Remind me" is offered for a link (not for pictures alone).
  bool get offerRemind => scheduler != null && link != null;

  void hold() {
    if (holding) return;
    holding = true;
    notifyListeners();
  }

  /// Off closes; a time is kept with the share and scheduled now, so it
  /// rings even before the app takes the link in.
  Future<void> remind(DateTime? at) async {
    if (at == null) return close();
    try {
      await bridge.remind(at);
      final id = share?.id;
      final title = page?.title ?? share?.title ?? link?.sourceDomain ?? '';
      if (id != null && scheduler != null) {
        remindBlocked = !await scheduler!(id, title, at);
      }
    } catch (_) {
      remindBlocked = true;
    }
    remindAt = at;
    notifyListeners();
    await Future<void>.delayed(remindBlocked ? remindWait : confirm);
    await close();
  }

  final SheetBridge bridge;
  final Duration retryDelay;

  /// How long "Saved in …" shows before the sheet goes.
  final Duration confirm;

  /// How long a tap waits for a picture still on its way, so the link
  /// keeps the one shown here.
  final Duration pictureWait;
  Future<void>? _reading;
  MetadataClient? _metadata;
  final _cancel = CancellationToken();

  SheetShare? share;

  /// The share could not be handed over (it is saved all the same).
  bool broken = false;
  bool reading = false, busy = false;

  /// The choice is with the share: "Saved in …" shows, then the sheet goes.
  bool done = false;
  MetadataResult? page;
  Uint8List? picture;

  /// Where the share is now: Not sorted, or the collection whose shortcut
  /// it came through.
  SheetChoice choice = const NotSorted();

  /// The place just tapped, shown with its tick while the sheet closes.
  SheetChoice? placed;

  /// Collections named here, newest first, shown above the others.
  final List<String> named = [];

  /// The first link in the share, read for its title and picture.
  UrlCandidate? get link {
    final text = share?.text ?? '';
    final urls = UrlTools.extract(text);
    return urls.isEmpty ? null : urls.first;
  }

  int get moreLinks {
    final n = UrlTools.extract(share?.text ?? '').length;
    return n > 1 ? n - 1 : 0;
  }

  Future<void> load() async {
    try {
      share = await bridge.start();
    } catch (_) {
      broken = true;
    }
    final from = share?.collection;
    if (from != null &&
        share!.snapshot.library.collections.any((c) => c.id == from)) {
      choice = InCollection(from);
    }
    notifyListeners();
    final s = share, u = link;
    if (s == null || u == null || s.images.isNotEmpty) return;
    if (!s.snapshot.read) return;
    unawaited(_reading = _read(u));
  }

  Future<void> _read(UrlCandidate u) async {
    final client = _metadata ??= MetadataClient();
    if (!client.available) return;
    reading = true;
    notifyListeners();
    try {
      var result = await client.fetch(u.originalUrl, cancellation: _cancel);
      if ({'rateLimited', 'busy'}.contains(result.errorCode)) {
        await Future<void>.delayed(retryDelay);
        _cancel.check();
        result = await client.fetch(u.originalUrl, cancellation: _cancel);
      }
      _cancel.check();
      // A login page in place of the post is not what was shared.
      if (result.status != 'failed' &&
          !looksLikeLoginWall(
            domain: u.sourceDomain,
            platform: u.platform,
            result: result,
          )) {
        page = result;
        notifyListeners();
        final cover = result.thumbnailUrl;
        if (cover != null) {
          final t = await client.fetchThumbnail(cover, cancellation: _cancel);
          _cancel.check();
          picture = t.bytes;
        }
      }
    } catch (_) {
      // Not read: the app reads it again when it takes the share in.
    } finally {
      reading = false;
      if (!_cancel.isCancelled) notifyListeners();
    }
  }

  void choose(SheetChoice value) {
    choice = value;
    notifyListeners();
  }

  /// Every collection it can go in, the one that last got an item first;
  /// those named in this sheet lead. Collections named in earlier sheets
  /// and not yet made by the app are listed as well.
  List<SheetPlace> get places {
    final s = share;
    if (s == null) return const [];
    final snapshot = s.snapshot;
    final collections = snapshot.library.collections;
    final byId = {for (final c in collections) c.id: c};
    String key(String name) => name.trim().toLowerCase();
    final topLevel = {
      for (final c in collections)
        if (c.parentId == null) key(c.name): c,
    };
    // What earlier shares still in the queue add to each place.
    final count = <String, int>{}, last = <String, int>{};
    final waiting = <String, String>{}; // key → name as first typed
    void add(String k, DateTime? at) {
      count[k] = (count[k] ?? 0) + 1;
      final ms = at?.millisecondsSinceEpoch ?? 0;
      if (ms > (last[k] ?? 0)) last[k] = ms;
    }

    for (final q in s.queued) {
      final n = q.newCollection?.trim();
      if (n != null && n.isNotEmpty) {
        final made = topLevel[key(n)];
        if (made != null) {
          add(made.id, q.at);
        } else {
          waiting.putIfAbsent(key(n), () => n);
          add('new:${key(n)}', q.at);
        }
      } else if (q.collection != null && byId.containsKey(q.collection)) {
        add(q.collection!, q.at);
      }
    }

    final freshKeys = {for (final n in named) key(n)};
    final out = <SheetPlace>[
      for (final n in named)
        SheetPlace(
          choice: InNewCollection(waiting[key(n)] ?? n),
          name: waiting[key(n)] ?? n,
          count: count['new:${key(n)}'] ?? 0,
          fresh: true,
        ),
    ];
    final rest = <SheetPlace>[
      for (final MapEntry(key: k, value: n) in waiting.entries)
        if (!freshKeys.contains(k))
          SheetPlace(
            choice: InNewCollection(n),
            name: n,
            count: count['new:$k'] ?? 0,
            last: last['new:$k'] ?? 0,
          ),
      for (final (c, _) in collectionTree(snapshot.library))
        SheetPlace(
          choice: InCollection(c.id),
          name: c.name,
          collection: c,
          parent: c.parentId == null ? null : byId[c.parentId]?.name,
          count: (snapshot.counts[c.id] ?? 0) + (count[c.id] ?? 0),
          last: [
            snapshot.last[c.id] ?? 0,
            last[c.id] ?? 0,
          ].reduce((a, b) => a > b ? a : b),
        ),
    ];
    // Newest first; the tree's order where none is newer (a stable sort).
    final order = {for (var i = 0; i < rest.length; i++) rest[i]: i};
    rest.sort((a, b) {
      final by = b.last.compareTo(a.last);
      return by != 0 ? by : order[a]!.compareTo(order[b]!);
    });
    return [...out, ...rest];
  }

  /// A new collection named in the sheet, or the one already called that.
  SheetChoice? name(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    final key = clean.toLowerCase();
    final existing = share?.snapshot.library.collections
        .where((c) => c.parentId == null && c.name.trim().toLowerCase() == key)
        .firstOrNull;
    if (existing != null) return InCollection(existing.id);
    // Named in an earlier sheet, not made yet: the same place.
    final waiting = share?.queued
        .map((q) => q.newCollection?.trim())
        .whereType<String>()
        .where((n) => n.toLowerCase() == key)
        .firstOrNull;
    if (waiting != null) return InNewCollection(waiting);
    named.removeWhere((n) => n.toLowerCase() == key);
    named.insert(0, clean.length > 200 ? clean.substring(0, 200) : clean);
    return InNewCollection(named.first);
  }

  /// One tap: the share goes there at once and "Saved in …" shows. A
  /// picture still on its way is waited for a few seconds and sent after,
  /// so the link keeps the one shown here; then the sheet closes.
  Future<void> put(SheetChoice where) async {
    if (busy || placed != null) return;
    placed = where;
    choice = where;
    busy = true;
    notifyListeners();
    final shown = Future<void>.delayed(offerRemind ? remindWait : confirm);
    final hadPicture = picture != null;
    try {
      await _send();
    } catch (_) {
      // Saved where it arrived all the same; the sheet closes.
      await close();
      return;
    }
    done = true;
    notifyListeners();
    final reading = _reading;
    if (!hadPicture && reading != null) {
      await reading.timeout(pictureWait, onTimeout: () {});
      if (picture != null) {
        try {
          await _send();
        } catch (_) {
          // The app reads the page itself when it takes the share in.
        }
      }
    }
    await shown;
    if (!holding) await close();
  }

  /// The name of a place, for the sheet's line "Saved in …".
  String? placeName(SheetChoice where) => switch (where) {
    NotSorted() => null,
    InNewCollection(:final name) => name,
    InCollection(:final id) =>
      share?.snapshot.library.collections
          .where((c) => c.id == id)
          .firstOrNull
          ?.name,
  };

  /// Sends the choice, and what was read of the page with its picture.
  Future<void> _send() {
    final c = choice;
    return bridge.save(
      collection: c is InCollection ? c.id : null,
      newCollection: c is InNewCollection ? c.name : null,
      // Only a page read whole (with its picture) is kept as it is.
      metadata: picture == null ? null : page,
      thumbnail: picture,
    );
  }

  Future<void> discard() async {
    _cancel.cancel();
    try {
      await bridge.discard();
    } catch (_) {
      await close();
    }
  }

  Future<void> close() async {
    _cancel.cancel();
    try {
      await bridge.close();
    } catch (_) {
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _cancel.cancel();
    _metadata?.dispose();
    super.dispose();
  }
}
