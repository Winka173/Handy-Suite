import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'store.dart';

/// Everything the person has made, loaded from the store, and the writes
/// back to it. Each change writes one record, then notifies.
class CardLibrary extends ChangeNotifier {
  final CardStore store;
  final ElementRegistry registry;
  final DateTime Function() clock;
  CardLibrary(this.store, this.registry, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  final designs = <String, CardDocument>{};
  final templates = <String, CardDocument>{};
  final profiles = <String, CardProfile>{};
  final settings = <String, Object?>{};
  Set<String> assetIds = {};
  final _bytes = <String, Uint8List>{};

  /// Records that could not be read; they stay in the store untouched.
  final unreadable = <String>[];
  bool loaded = false;
  Object? error;

  Future<void> load() async {
    try {
      final data = await store.read();
      designs.clear();
      templates.clear();
      profiles.clear();
      unreadable.clear();
      for (final e in (data.records['design'] ?? const {}).entries) {
        _read(
          e.key,
          () => designs[e.key] = CardDocument.decode(e.value, registry),
        );
      }
      for (final e in (data.records['template'] ?? const {}).entries) {
        _read(
          e.key,
          () => templates[e.key] = CardDocument.decode(e.value, registry),
        );
      }
      for (final e in (data.records['profile'] ?? const {}).entries) {
        _read(
          e.key,
          () => profiles[e.key] = CardProfile.fromJson(jsonDecode(e.value)),
        );
      }
      final raw = data.records['settings']?['app'];
      settings
        ..clear()
        ..addAll(
          raw == null
              ? const {}
              : Map<String, Object?>.from(jsonDecode(raw) as Map),
        );
      assetIds = data.assets;
      error = null;
      loaded = true;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  void _read(String id, void Function() parse) {
    try {
      parse();
    } on FormatException {
      unreadable.add(id);
    }
  }

  /// Designs, the most recently changed first.
  List<CardDocument> get recent =>
      designs.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  String get stamp => clock().toUtc().toIso8601String();

  Future<CardDocument> saveDesign(CardDocument d, {bool touch = true}) async {
    final next = touch ? d.copyWith(updatedAt: stamp) : d;
    next.validate();
    await store.put('design', next.id, next.encode());
    designs[next.id] = next;
    notifyListeners();
    return next;
  }

  Future<void> deleteDesign(String id) async {
    await store.delete('design', id);
    designs.remove(id);
    notifyListeners();
  }

  Future<CardDocument> duplicateDesign(
    CardDocument d, {
    String suffix = ' (copy)',
  }) {
    final copy = CardDocument.decode(d.encode(), registry);
    final fresh = CardDocument.fromJson({
      ...copy.toJson(),
      'id': newCardId(),
      'name': '${d.name}$suffix'.trim(),
      'createdAt': stamp,
      'pages': [
        for (final p in copy.pages)
          {
            ...p
                .copyWith(
                  elements: [for (final e in p.elements) cloneElement(e)],
                )
                .toJson(),
            'id': newCardId(),
          },
      ],
    }, registry);
    return saveDesign(fresh);
  }

  Future<CardDocument> saveTemplate(CardDocument d, String name) async {
    final t = CardDocument.fromJson({
      ...d.toJson(),
      'id': newCardId(),
      'name': name,
      'createdAt': stamp,
      'updatedAt': stamp,
    }, registry);
    await store.put('template', t.id, t.encode());
    templates[t.id] = t;
    notifyListeners();
    return t;
  }

  Future<void> deleteTemplate(String id) async {
    await store.delete('template', id);
    templates.remove(id);
    notifyListeners();
  }

  Future<CardProfile> saveProfile(CardProfile p) async {
    final next = CardProfile.fromJson({...p.toJson(), 'updatedAt': stamp});
    await store.put('profile', next.id, jsonEncode(next.toJson()));
    profiles[next.id] = next;
    notifyListeners();
    return next;
  }

  Future<void> deleteProfile(String id) async {
    await store.delete('profile', id);
    profiles.remove(id);
    notifyListeners();
  }

  Future<void> setSetting(String key, Object? value) async {
    settings[key] = value;
    await store.put('settings', 'app', jsonEncode(settings));
    notifyListeners();
  }

  String setting(String key, String fallback) =>
      settings[key] is String ? settings[key] as String : fallback;
  bool flag(String key, {bool fallback = true}) =>
      settings[key] is bool ? settings[key] as bool : fallback;

  /// Stores a picture (PNG, JPEG or WebP up to 12 MB) once, by its hash.
  Future<CardAsset> addAsset(Uint8List bytes, {String name = ''}) async {
    if (bytes.length > 12000000) {
      throw const FormatException('Pictures up to 12 MB / Ảnh tối đa 12 MB');
    }
    final mime = imageMime(bytes);
    if (mime == null) {
      throw const FormatException(
        'Use a PNG, JPEG or WebP picture / Dùng ảnh PNG, JPEG hoặc WebP',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final asset = CardAsset(
      id: assetId(bytes),
      mime: mime,
      name: name.length > 200 ? name.substring(0, 200) : name,
      width: descriptor.width,
      height: descriptor.height,
      size: bytes.length,
    );
    descriptor.dispose();
    buffer.dispose();
    if (!assetIds.contains(asset.id)) {
      await store.putAsset(asset.id, bytes);
      assetIds = {...assetIds, asset.id};
    }
    _bytes[asset.id] = bytes;
    return asset;
  }

  Future<Uint8List?> assetBytes(String id) async {
    final cached = _bytes[id];
    if (cached != null) return cached;
    final bytes = await store.asset(id);
    if (bytes != null) _bytes[id] = bytes;
    return bytes;
  }

  /// Bytes of every picture [docs] use (for exports and backups).
  Future<Map<String, Uint8List>> assetsFor(
    Iterable<CardDocument> docs, {
    Iterable<CardProfile> profiles = const [],
  }) async {
    final ids = {
      for (final d in docs) ...d.assets.map((a) => a.id),
      for (final p in profiles) ...[?p.photo, ?p.logo],
    };
    return {
      for (final id in ids)
        if (await assetBytes(id) case final b?) id: b,
    };
  }

  /// Pictures no design, template or profile uses any more are removed.
  /// Runs after loading, never while a picture could still be undone into
  /// a design that is open.
  Future<int> collectUnused({Set<String> keep = const {}}) async {
    final used = {
      ...keep,
      for (final d in [...designs.values, ...templates.values])
        ...d.assets.map((a) => a.id),
      for (final p in profiles.values) ...[?p.photo, ?p.logo],
    };
    final unused = assetIds.difference(used);
    if (unused.isEmpty) return 0;
    await store.deleteAssets(unused);
    assetIds = assetIds.difference(unused);
    _bytes.removeWhere((k, _) => unused.contains(k));
    return unused.length;
  }

  /// A portable copy of everything, pictures included.
  Future<Uint8List> exportProject({Iterable<CardDocument>? only}) async {
    final ds = (only ?? designs.values).toList();
    final ts = only == null ? templates.values.toList() : <CardDocument>[];
    final ps = only == null
        ? profiles.values.toList()
        : [for (final d in ds) ?profiles[d.profileId]];
    return encodeCardProject(
      designs: ds,
      templates: ts,
      profiles: ps,
      assets: await assetsFor([...ds, ...ts], profiles: ps),
      at: clock(),
    );
  }

  /// Adds what a project holds. A design or profile with an id already
  /// here gets a new id, so nothing existing is overwritten.
  Future<({int designs, int profiles, int templates})> importProject(
    CardProjectContents c,
  ) async {
    for (final e in c.assets.entries) {
      if (!assetIds.contains(e.key)) {
        await store.putAsset(e.key, e.value);
        assetIds = {...assetIds, e.key};
      }
    }
    final remap = <String, String>{};
    for (final p in c.profiles) {
      final id = profiles.containsKey(p.id) ? newCardId() : p.id;
      remap[p.id] = id;
      await saveProfile(CardProfile.fromJson({...p.toJson(), 'id': id}));
    }
    for (final d in c.designs) {
      final json = d.toJson();
      if (designs.containsKey(d.id)) json['id'] = newCardId();
      if (d.profileId != null)
        json['profileId'] = remap[d.profileId] ?? d.profileId;
      await saveDesign(CardDocument.fromJson(json, registry), touch: false);
    }
    for (final t in c.templates) {
      final json = t.toJson();
      if (templates.containsKey(t.id)) json['id'] = newCardId();
      final doc = CardDocument.fromJson(json, registry);
      await store.put('template', doc.id, doc.encode());
      templates[doc.id] = doc;
    }
    notifyListeners();
    return (
      designs: c.designs.length,
      profiles: c.profiles.length,
      templates: c.templates.length,
    );
  }
}

/// Decoded pictures for drawing, loaded on first use.
class CardImages extends ChangeNotifier {
  final CardLibrary library;
  CardImages(this.library);
  final _images = <String, ui.Image>{};
  final _loading = <String>{};

  ui.Image? operator [](String id) {
    final hit = _images[id];
    if (hit != null || _loading.contains(id)) return hit;
    _loading.add(id);
    library
        .assetBytes(id)
        .then((bytes) async {
          if (bytes == null) return;
          final codec = await ui.instantiateImageCodec(bytes);
          _images[id] = (await codec.getNextFrame()).image;
          notifyListeners();
        })
        .whenComplete(() => _loading.remove(id));
    return null;
  }

  @override
  void dispose() {
    for (final i in _images.values) {
      i.dispose();
    }
    super.dispose();
  }
}
