part of '../handy_inventory.dart';

// Collections (state version 4). An item is one record; a collection only
// names the items in it (by the item's own `collections` list), so an item
// can sit in several collections and still has one box, one loan and one
// set of receipts.

const keepCollectionLimit = 200, keepItemPhotoLimit = 11;
const keepProfiles = ['asset', 'collectible', 'consumable', 'custom'];
const keepStatuses = ['owned', 'ordered', 'wanted'];
const keepPriorities = ['', 'low', 'medium', 'high'];

/// Collector text fields shown by the collectible profile.
const keepCollectorFields = [
  'series',
  'number',
  'variant',
  'edition',
  'condition',
];

String _link(Object? value) {
  final link = _text(value, 2000);
  if (link.isEmpty) return link;
  final uri = Uri.tryParse(link);
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      RegExp(r'[\x00-\x20]').hasMatch(link))
    throw const FormatException('A link must be an http(s) address');
  return link;
}

List<String> _idList(Object? value, int maximum) {
  if (value is! List || value.length > maximum)
    throw const FormatException('Too many references');
  final ids = [for (final v in value) _id(v)];
  if (ids.toSet().length != ids.length)
    throw const FormatException('Duplicate references');
  return List.unmodifiable(ids);
}

/// Reads the optional version-4 fields of an item into [r]. Absent fields
/// stay absent, so an older item writes back exactly as it was.
void _collectorFields(Map<String, dynamic> a, Map<String, dynamic> r) {
  void choice(String key, List<String> allowed) {
    if (!a.containsKey(key)) return;
    if (!allowed.contains(a[key]))
      throw FormatException('Unknown $key: ${a[key]}');
    r[key] = a[key];
  }

  choice('profile', keepProfiles);
  choice('status', keepStatuses);
  choice('priority', keepPriorities);
  if (a.containsKey('collections'))
    r['collections'] = _idList(a['collections'], 50);
  for (final key in keepCollectorFields) {
    if (a.containsKey(key)) r[key] = _text(a[key], 200);
  }
  if (a.containsKey('link')) r['link'] = _link(a['link']);
  if (a.containsKey('budget') || a.containsKey('budgetCurrency')) {
    final budget = _price(a['budget'] ?? ''),
        currency = _currency(a['budgetCurrency'] ?? '');
    if ((budget == '') != (currency == ''))
      throw const FormatException('A budget needs its currency');
    if (budget != '' && _decimals(budget) > currencyDigits(currency))
      throw const FormatException('Too many decimals for this currency');
    r['budget'] = budget;
    r['budgetCurrency'] = currency;
  }
  if (a.containsKey('photos')) {
    final photos = a['photos'];
    if (photos is! List || photos.length > keepItemPhotoLimit)
      throw const FormatException('At most 11 more photos per item');
    final uris = [for (final p in photos) _localUri(p, required: true)];
    if (uris.toSet().length != uris.length)
      throw const FormatException('Duplicate photos');
    r['photos'] = List<String>.unmodifiable(uris);
  }
  if (a.containsKey('fields')) {
    final fields = a['fields'];
    if (fields is! Map || fields.length > 40)
      throw const FormatException('At most 40 own fields per item');
    final own = <String, String>{};
    for (final e in fields.entries) {
      if (e.key is! String ||
          !RegExp(r'^[a-z0-9][a-z0-9_-]{0,39}$').hasMatch(e.key as String))
        throw const FormatException('Invalid field name');
      own[e.key as String] = _text(e.value, 1000);
    }
    r['fields'] = Map<String, String>.unmodifiable(own);
  }
  // Something wanted or on order is not here yet, so it cannot be lent.
  if ((r['status'] ?? 'owned') != 'owned' &&
      ((a['borrower'] ?? '') as Object) != '')
    throw const FormatException('Only an owned item can be lent');
}

/// What a collection is of. It decides the suggested profile and fields of
/// new items; it never limits what an item may hold.
class KeepCollectionKind {
  final String id, en, vi;

  /// Suggested own fields for items (key → EN/VI label).
  final Map<String, (String, String)> fields;
  const KeepCollectionKind(this.id, this.en, this.vi, [this.fields = const {}]);
}

const keepCollectionKinds = [
  KeepCollectionKind('figures', 'Figures', 'Mô hình nhân vật', {
    'maker': ('Maker', 'Hãng'),
    'scale': ('Scale', 'Tỉ lệ'),
  }),
  KeepCollectionKind('cards', 'Trading cards', 'Thẻ sưu tầm', {
    'set': ('Set', 'Bộ'),
    'rarity': ('Rarity', 'Độ hiếm'),
  }),
  KeepCollectionKind('books', 'Books and manga', 'Sách và truyện', {
    'author': ('Author', 'Tác giả'),
    'publisher': ('Publisher', 'Nhà xuất bản'),
  }),
  KeepCollectionKind('games', 'Video games', 'Trò chơi điện tử', {
    'platform': ('Platform', 'Hệ máy'),
    'region': ('Region', 'Khu vực'),
  }),
  KeepCollectionKind('board-games', 'Board games', 'Board game', {
    'players': ('Players', 'Số người chơi'),
  }),
  KeepCollectionKind('models', 'LEGO and models', 'LEGO và mô hình lắp', {
    'set': ('Set number', 'Mã bộ'),
    'pieces': ('Pieces', 'Số mảnh'),
  }),
  KeepCollectionKind('watches', 'Watches', 'Đồng hồ', {
    'reference': ('Reference', 'Mã tham chiếu'),
    'movement': ('Movement', 'Bộ máy'),
  }),
  KeepCollectionKind('devices', 'Devices', 'Thiết bị', {
    'model': ('Model', 'Mẫu'),
  }),
  KeepCollectionKind('camera-gear', 'Camera gear', 'Đồ máy ảnh', {
    'mount': ('Mount', 'Ngàm'),
    'focal': ('Focal length', 'Tiêu cự'),
  }),
  KeepCollectionKind('custom', 'Something else', 'Thứ khác'),
];

KeepCollectionKind keepCollectionKind(String id) => keepCollectionKinds
    .firstWhere((k) => k.id == id, orElse: () => keepCollectionKinds.last);

class InventoryCollection {
  final String id, name, kind, notes, coverAssetId;

  /// Identity hue index (HandyPalette, 0–7), or −1 for none.
  final int hue;

  /// How many the person means to have in all (0 = no target). Set by the
  /// person; Keep knows no official catalogue.
  final int target;

  /// Item ids in the person's own order; items not listed follow by name.
  final List<String> order;
  InventoryCollection({
    required this.id,
    required this.name,
    this.kind = 'custom',
    this.notes = '',
    this.coverAssetId = '',
    this.hue = -1,
    this.target = 0,
    Iterable<String> order = const [],
  }) : order = List.unmodifiable(order);
  factory InventoryCollection.fromJson(Object? value) {
    final r = _record(value);
    final kind = r['kind'] ?? 'custom', hue = r['hue'] ?? -1;
    final target = r['target'] ?? 0;
    if (!keepCollectionKinds.any((k) => k.id == kind))
      throw const FormatException('Unknown collection kind');
    if (hue is! int || hue < -1 || hue > 7)
      throw const FormatException('Invalid collection hue');
    if (target is! int || target < 0 || target > 100000)
      throw const FormatException('Invalid collection target');
    return InventoryCollection(
      id: _id(r['id']),
      name: _text(r['name'], 200, required: true),
      kind: kind as String,
      notes: _text(r['notes'] ?? '', 10000),
      coverAssetId: r['coverAssetId'] == null || r['coverAssetId'] == ''
          ? ''
          : _id(r['coverAssetId']),
      hue: hue,
      target: target,
      order: _idList(r['order'] ?? const [], keepAssetLimit),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'notes': notes,
    'coverAssetId': coverAssetId,
    'hue': hue,
    'target': target,
    'order': order,
  };
  InventoryCollection copyWith(Map<String, Object?> changes) =>
      InventoryCollection.fromJson({...toJson(), ...changes});
}

List<InventoryCollection> _collections(
  Object? value,
  List<InventoryAsset> assets,
) {
  if (value == null) return const [];
  if (value is! List || value.length > keepCollectionLimit)
    throw const FormatException('At most 200 collections');
  final collections = value.map(InventoryCollection.fromJson).toList();
  final ids = collections.map((c) => c.id).toSet(),
      assetIds = assets.map((a) => a.id).toSet();
  if (ids.length != collections.length)
    throw const FormatException('Duplicate collection IDs');
  if (assets.any((a) => a.collections.any((c) => !ids.contains(c))))
    throw const FormatException('Item refers to a missing collection');
  for (final c in collections) {
    if (c.coverAssetId.isNotEmpty && !assetIds.contains(c.coverAssetId))
      throw const FormatException('Collection cover is a missing item');
    if (c.order.any((id) => !assetIds.contains(id)))
      throw const FormatException('Collection order names a missing item');
  }
  return collections;
}

List<Map<String, Object?>> _collectionsJson(KeepState state) =>
    state.collections.map((c) => c.toJson()).toList();

KeepState _withCollections(
  KeepState state,
  Iterable<InventoryCollection> collections, [
  Iterable<InventoryAsset>? assets,
]) => validateKeepState({
  'version': keepStateVersion,
  'assets': (assets ?? state.assets).map((a) => a.toJson()).toList(),
  'boxes': state.boxes.map((b) => b.toJson()).toList(),
  'collections': collections.map((c) => c.toJson()).toList(),
});

/// Adds or replaces a collection.
KeepState saveCollection(KeepState state, InventoryCollection collection) =>
    _withCollections(
      state,
      state.collections.any((c) => c.id == collection.id)
          ? state.collections.map((c) => c.id == collection.id ? collection : c)
          : [...state.collections, collection],
    );

/// Removes a collection. Its items stay; they only leave it.
KeepState removeCollection(KeepState state, String id) => _withCollections(
  state,
  state.collections.where((c) => c.id != id),
  state.assets.map(
    (a) => a.collections.contains(id)
        ? a.copyWith({
            'collections': a.collections.where((c) => c != id).toList(),
          })
        : a,
  ),
);

/// Puts item [assetId] in exactly [collectionIds].
KeepState setItemCollections(
  KeepState state,
  String assetId,
  Iterable<String> collectionIds, {
  String? now,
}) {
  final a = _asset(state, assetId), ids = collectionIds.toSet().toList();
  final left = a.collections.where((c) => !ids.contains(c)).toSet();
  return _withCollections(
    state,
    state.collections.map(
      (c) => left.contains(c.id)
          ? c.copyWith({
              'order': c.order.where((o) => o != assetId).toList(),
              if (c.coverAssetId == assetId) 'coverAssetId': '',
            })
          : c,
    ),
    state.assets.map(
      (x) => x.id == assetId
          ? x.copyWith({'collections': ids, 'updatedAt': now ?? _now()})
          : x,
    ),
  );
}

/// A wanted or ordered item has arrived: the same record becomes owned (no
/// copy), with the purchase day and, when given, what it cost.
KeepState markOwned(
  KeepState state,
  String assetId, {
  required String purchasedOn,
  String price = '',
  String currency = '',
  String? now,
}) {
  final a = _asset(state, assetId);
  return saveAsset(
    state,
    a.copyWith({
      'status': 'owned',
      'purchasedOn': purchasedOn,
      if (price.isNotEmpty) 'price': price,
      if (price.isNotEmpty) 'currency': currency,
      'updatedAt': now ?? _now(),
    }),
  );
}

/// Items of a collection in its order: the person's order first, then the
/// rest by name.
List<InventoryAsset> collectionItems(KeepState state, String collectionId) {
  final c = state.collections.firstWhere(
    (c) => c.id == collectionId,
    orElse: () => throw const FormatException('Collection not found'),
  );
  final members = {
    for (final a in state.assets)
      if (a.collections.contains(c.id)) a.id: a,
  };
  return [
    for (final id in c.order)
      if (members.remove(id) case final a?) a,
    ...members.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  ];
}

/// How far a collection is: owned, ordered and wanted items, and the
/// person's target (0 when none). [missing] counts only what the target
/// says is still to find; it is never guessed.
typedef KeepCompletion = ({
  int owned,
  int ordered,
  int wanted,
  int target,
  int missing,
});

KeepCompletion collectionCompletion(KeepState state, String collectionId) {
  final c = state.collections.firstWhere((c) => c.id == collectionId);
  var owned = 0, ordered = 0, wanted = 0;
  for (final a in state.assets) {
    if (!a.collections.contains(c.id)) continue;
    switch (a.status) {
      case 'owned':
        owned++;
      case 'ordered':
        ordered++;
      default:
        wanted++;
    }
  }
  return (
    owned: owned,
    ordered: ordered,
    wanted: wanted,
    target: c.target,
    missing: c.target > owned ? c.target - owned : 0,
  );
}
