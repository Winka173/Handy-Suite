import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'metadata_types.dart';
import 'shared_file.dart';
import 'web_share_inbox.dart';

class SharedLink {
  final String id, text;
  final String? title;

  /// Pictures the share carried, already copied into the app's private
  /// queue: their files, types and original names.
  final List<({String path, String mime, String name})> images;

  /// The collection it was shared into, when the person picked one of
  /// their collections in the share sheet's top row.
  final String? collection;

  /// A collection named in the share sheet, made when the share is taken
  /// in (or the one already called that).
  final String? newCollection;

  /// What the share sheet read of the page, and the picture it showed
  /// (already checked and re-encoded, in the private queue).
  final MetadataResult? metadata;
  final String? thumbnail;
  const SharedLink(
    this.id,
    this.text,
    this.title, [
    this.images = const [],
    this.collection,
  ]) : newCollection = null,
       metadata = null,
       thumbnail = null;

  const SharedLink.full(
    this.id,
    this.text,
    this.title, {
    this.images = const [],
    this.collection,
    this.newCollection,
    this.metadata,
    this.thumbnail,
  });
}

MetadataResult? _metadata(Object? raw) {
  if (raw is! Map) return null;
  String? s(String k) => raw[k] is String ? raw[k] as String : null;
  return MetadataResult(
    title: s('title'),
    description: s('description'),
    siteName: s('siteName'),
    author: s('author'),
    canonicalUrl: s('canonicalUrl'),
    thumbnailUrl: s('thumbnailUrl'),
    contentType: s('contentType'),
    status: s('status') ?? 'partial',
  );
}

List<({String path, String mime, String name})> _images(Object? raw) => [
  for (final i in raw as List? ?? const [])
    (
      path: (i as Map)['path'] as String,
      mime: i['mime'] as String,
      name: i['name'] as String? ?? '',
    ),
];

class SaveShareInbox {
  final browser = BrowserShareInbox();
  static const channel = MethodChannel('handy.save/share');
  Future<void> start(
    VoidCallback incoming,
    ValueChanged<String> dropped,
    VoidCallback failed,
  ) async {
    if (kIsWeb) {
      browser.listen(incoming);
      return;
    }
    channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming')
        incoming();
      else if (call.method == 'incomingText' && call.arguments is String)
        dropped(call.arguments as String);
      else if (call.method == 'shareError')
        failed();
    });
  }

  Future<List<SharedLink>> drain() async {
    if (kIsWeb)
      return [
        for (final r in await browser.drain())
          SharedLink(
            r['id'] as String,
            r['text'] as String,
            r['title'] as String?,
          ),
      ];
    try {
      final rows = await channel.invokeListMethod<dynamic>('drain') ?? [];
      return [
        for (final r in rows)
          SharedLink.full(
            r['id'] as String,
            r['text'] as String,
            r['title'] as String?,
            images: _images(r['images']),
            collection: r['collection'] as String?,
            newCollection: r['newCollection'] as String?,
            metadata: _metadata(r['metadata']),
            thumbnail: r['thumbnail'] as String?,
          ),
      ];
    } on MissingPluginException {
      return [];
    }
  }

  /// Offers these collections in the top row of the system share sheet
  /// (Android 10+); elsewhere nothing happens. Only names and colours go
  /// to the system, never links.
  Future<void> offerCollections(
    List<({String id, String name, int color})> targets,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<bool>('shareTargets', {
        'targets': [
          for (final t in targets)
            {'id': t.id, 'name': t.name, 'color': t.color},
        ],
      });
    } on MissingPluginException {
      // A host test or an older build: the plain share still works.
    } on PlatformException {
      // The system declined (rate limit); offered again on the next change.
    }
  }

  /// Keeps [snapshot] (see `sheetSnapshot`) where the share sheet reads it
  /// (Android); elsewhere nothing happens.
  Future<void> offerSheet(String snapshot) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await channel.invokeMethod<bool>('sheetSnapshot', {'snapshot': snapshot});
    } on MissingPluginException {
      // A host test or an older build: the sheet lists no collections.
    } on PlatformException {
      // Written again on the next change.
    }
  }

  /// The bytes of a picture the share queue copied into private storage.
  Future<Uint8List> readImage(String path) => readSharedFile(path);

  Future<void> acknowledge(String id) async {
    if (kIsWeb) {
      await browser.ack(id);
      return;
    }
    final ok = await channel.invokeMethod<bool>('ack', {'id': id});
    if (ok != true)
      throw StateError('Share acknowledgment failed; saved data is retained');
  }

  void dispose() {
    browser.dispose();
    if (!kIsWeb) channel.setMethodCallHandler(null);
  }
}
