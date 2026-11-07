import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_core/handy_core.dart';
import '../services/metadata_client.dart';
import '../services/metadata_judge.dart';
import 'snapshot.dart';

/// A share as the share sheet receives it: already in the app's private
/// queue (saved) under [id].
class SheetShare {
  final String id, text;
  final String? title;

  /// Pictures the share carried, copied into the queue.
  final List<String> images;
  final SheetSnapshot snapshot;
  const SheetShare({
    required this.id,
    required this.text,
    this.title,
    this.images = const [],
    required this.snapshot,
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
      images: [for (final p in r['images'] as List? ?? const []) p as String],
      snapshot: SheetSnapshot.parse(r['snapshot'] as String?),
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
  }) : _metadata = metadata;

  final SheetBridge bridge;
  final Duration retryDelay;
  MetadataClient? _metadata;
  final _cancel = CancellationToken();

  SheetShare? share;

  /// The share could not be handed over (it is saved all the same).
  bool broken = false;
  bool reading = false, busy = false;
  MetadataResult? page;
  Uint8List? picture;
  SheetChoice choice = const NotSorted();

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
    notifyListeners();
    final s = share, u = link;
    if (s == null || u == null || s.images.isNotEmpty) return;
    if (!s.snapshot.read) return;
    unawaited(_read(u));
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

  /// A new collection named in the sheet; chosen at once. A name already
  /// listed picks that one instead.
  void name(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final key = clean.toLowerCase();
    final existing = share?.snapshot.library.collections
        .where((c) => c.parentId == null && c.name.trim().toLowerCase() == key)
        .firstOrNull;
    if (existing != null) {
      choose(InCollection(existing.id));
      return;
    }
    named.removeWhere((n) => n.toLowerCase() == key);
    named.insert(0, clean.length > 200 ? clean.substring(0, 200) : clean);
    choose(InNewCollection(named.first));
  }

  Future<void> save() async {
    if (busy) return;
    busy = true;
    notifyListeners();
    _cancel.cancel();
    final c = choice;
    try {
      await bridge.save(
        collection: c is InCollection ? c.id : null,
        newCollection: c is InNewCollection ? c.name : null,
        // Only a page read whole (with its picture) is kept as it is.
        metadata: picture == null ? null : page,
        thumbnail: picture,
      );
    } catch (_) {
      // Saved in Not sorted all the same; the sheet closes.
      await close();
    }
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
