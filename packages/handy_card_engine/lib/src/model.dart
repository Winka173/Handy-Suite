part of '../handy_card_engine.dart';

/// The schema this build writes. Older documents are migrated on read;
/// newer ones are refused rather than half understood.
const cardSchemaVersion = 1;

const cardElementLimit = 5000, cardDepthLimit = 16, cardTextLimit = 10000;
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

String _id(Object? v) {
  if (v is! String || !_idPattern.hasMatch(v))
    throw const FormatException('Invalid id');
  return v;
}

String _text(Object? v, {int max = cardTextLimit}) {
  if (v is! String || v.length > max)
    throw const FormatException('Invalid text');
  return v;
}

/// Random 16-character ids; stable once given.
String newCardId() {
  final r = math.Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
}

/// `RRGGBB` or `AARRGGBB`, or null for none.
String? cardColor(Object? v) {
  if (v == null) return null;
  if (v is! String || !RegExp(r'^([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$').hasMatch(v))
    throw const FormatException('Invalid colour');
  return v.toUpperCase();
}

/// The colour as 0xAARRGGBB.
int colorValue(String hex) =>
    int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);

/// How an element takes a value from the design's profile: `live` follows
/// the profile, `snapshot` keeps the text it had when it was unlinked.
class ElementBinding {
  final String field, mode;
  const ElementBinding(this.field, {this.mode = 'live'});
  factory ElementBinding.fromJson(Object? raw) {
    final j = _map(raw, 'binding');
    final field = _text(j['field'], max: 80);
    final mode = j['mode'] ?? 'live';
    if (!RegExp(r'^[a-z]+(:[A-Za-z0-9 _-]{1,40})?$').hasMatch(field) ||
        mode is! String ||
        !const {'live', 'snapshot'}.contains(mode))
      throw const FormatException('Invalid binding');
    return ElementBinding(field, mode: mode);
  }
  Map<String, Object?> toJson() => {'field': field, 'mode': mode};
  @override
  bool operator ==(Object o) =>
      o is ElementBinding && o.field == field && o.mode == mode;
  @override
  int get hashCode => Object.hash(field, mode);
}

/// One layer: its type, place, look and, for groups, its children.
/// Keys this build does not know are kept in [extra] and written back, so
/// a document from a newer build loses nothing when saved here.
class CardElement {
  final String id, type, name;
  final Frame frame;
  final double opacity;
  final bool visible, locked;
  final Map<String, Object?> props;
  final List<CardElement> children;
  final ElementBinding? binding;
  final Map<String, Object?> extra;
  CardElement({
    required this.id,
    required this.type,
    this.name = '',
    required this.frame,
    this.opacity = 1,
    this.visible = true,
    this.locked = false,
    Map<String, Object?> props = const {},
    List<CardElement> children = const [],
    this.binding,
    Map<String, Object?> extra = const {},
  }) : props = Map.unmodifiable(props),
       children = List.unmodifiable(children),
       extra = Map.unmodifiable(extra);

  static const _known = {
    'id',
    'type',
    'name',
    'frame',
    'opacity',
    'visible',
    'locked',
    'props',
    'children',
    'binding',
  };

  factory CardElement.fromJson(
    Object? raw,
    ElementRegistry registry, {
    int depth = 0,
  }) {
    if (depth > cardDepthLimit)
      throw const FormatException('Groups nested too deeply');
    final j = _map(raw, 'element');
    final type = _text(j['type'], max: 40);
    if (!RegExp(r'^[a-z][a-z0-9_.-]{0,39}$').hasMatch(type))
      throw const FormatException('Invalid element type');
    final spec = registry.lookup(type);
    final rawProps = j['props'] == null
        ? <String, Object?>{}
        : _map(j['props'], 'props');
    final children = j['children'] == null ? const <Object?>[] : j['children'];
    if (children is! List) throw const FormatException('Invalid children');
    final opacity = _num(j['opacity'] ?? 1, min: 0, max: 1);
    return CardElement(
      id: _id(j['id']),
      type: type,
      name: _text(j['name'] ?? '', max: 120),
      frame: Frame.fromJson(j['frame']),
      opacity: opacity,
      visible: j['visible'] != false,
      locked: j['locked'] == true,
      // An unknown type keeps its properties exactly as they came.
      props: spec == null ? rawProps : spec.normalize(rawProps),
      children: [
        for (final c in children)
          CardElement.fromJson(c, registry, depth: depth + 1),
      ],
      binding: j['binding'] == null
          ? null
          : ElementBinding.fromJson(j['binding']),
      extra: {
        for (final e in j.entries)
          if (!_known.contains(e.key)) e.key: e.value,
      },
    );
  }

  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    'type': type,
    if (name.isNotEmpty) 'name': name,
    'frame': frame.toJson(),
    if (opacity != 1) 'opacity': opacity,
    if (!visible) 'visible': false,
    if (locked) 'locked': true,
    if (props.isNotEmpty) 'props': props,
    if (children.isNotEmpty) 'children': [for (final c in children) c.toJson()],
    if (binding != null) 'binding': binding!.toJson(),
  };

  bool get isGroup => type == 'group';

  T prop<T>(String key, T fallback) {
    final v = props[key];
    if (v is T) return v;
    if (fallback is double && v is num) return v.toDouble() as T;
    return fallback;
  }

  CardElement copyWith({
    String? id,
    String? name,
    Frame? frame,
    double? opacity,
    bool? visible,
    bool? locked,
    Map<String, Object?>? props,
    List<CardElement>? children,
    ElementBinding? binding,
    bool clearBinding = false,
  }) => CardElement(
    id: id ?? this.id,
    type: type,
    name: name ?? this.name,
    frame: frame ?? this.frame,
    opacity: opacity ?? this.opacity,
    visible: visible ?? this.visible,
    locked: locked ?? this.locked,
    props: props ?? this.props,
    children: children ?? this.children,
    binding: clearBinding ? null : binding ?? this.binding,
    extra: extra,
  );

  /// Every element in this subtree, this one first.
  Iterable<CardElement> get descendants sync* {
    yield this;
    for (final c in children) yield* c.descendants;
  }
}

/// One side or page of a design.
class CardPage {
  final String id, name;
  final String? background;
  final List<CardElement> elements;
  final Map<String, Object?> extra;
  CardPage({
    required this.id,
    this.name = '',
    this.background = 'FFFFFF',
    List<CardElement> elements = const [],
    Map<String, Object?> extra = const {},
  }) : elements = List.unmodifiable(elements),
       extra = Map.unmodifiable(extra);

  factory CardPage.fromJson(Object? raw, ElementRegistry registry) {
    final j = _map(raw, 'page');
    final els = j['elements'] ?? const [];
    if (els is! List) throw const FormatException('Invalid elements');
    return CardPage(
      id: _id(j['id']),
      name: _text(j['name'] ?? '', max: 80),
      background: cardColor(j['background']),
      elements: [for (final e in els) CardElement.fromJson(e, registry)],
      extra: {
        for (final e in j.entries)
          if (!const {'id', 'name', 'background', 'elements'}.contains(e.key))
            e.key: e.value,
      },
    );
  }
  Map<String, Object?> toJson() => {
    ...extra,
    'id': id,
    if (name.isNotEmpty) 'name': name,
    'background': background,
    'elements': [for (final e in elements) e.toJson()],
  };
  CardPage copyWith({
    String? name,
    String? background,
    bool clearBackground = false,
    List<CardElement>? elements,
  }) => CardPage(
    id: id,
    name: name ?? this.name,
    background: clearBackground ? null : background ?? this.background,
    elements: elements ?? this.elements,
    extra: extra,
  );
  Iterable<CardElement> get all => elements.expand((e) => e.descendants);
}

/// A picture the design uses, stored once by the hash of its bytes.
class CardAsset {
  final String id, mime, name;
  final int width, height, size;
  const CardAsset({
    required this.id,
    required this.mime,
    this.name = '',
    this.width = 0,
    this.height = 0,
    this.size = 0,
  });
  factory CardAsset.fromJson(Object? raw) {
    final j = _map(raw, 'asset');
    final id = j['id'];
    final mime = j['mime'];
    if (id is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
        mime is! String ||
        !cardImageMimes.contains(mime))
      throw const FormatException('Invalid asset');
    return CardAsset(
      id: id,
      mime: mime,
      name: _text(j['name'] ?? '', max: 200),
      width: (j['width'] as num? ?? 0).toInt(),
      height: (j['height'] as num? ?? 0).toInt(),
      size: (j['size'] as num? ?? 0).toInt(),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'mime': mime,
    if (name.isNotEmpty) 'name': name,
    'width': width,
    'height': height,
    'size': size,
  };
  String get extension => switch (mime) {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    _ => 'webp',
  };
}

const cardImageMimes = {'image/png', 'image/jpeg', 'image/webp'};

/// A design: its size in points, bleed and safe margin, sides, the pictures
/// it uses and the profile its contact fields read from.
class CardDocument {
  final String id, name, kind, unit;
  final double width, height, bleed, safe;
  final List<CardPage> pages;
  final List<CardAsset> assets;
  final String? profileId;
  final String createdAt, updatedAt;
  final Map<String, Object?> extra;
  CardDocument({
    required this.id,
    this.name = '',
    this.kind = 'custom',
    this.unit = 'mm',
    required this.width,
    required this.height,
    this.bleed = 0,
    this.safe = 0,
    required List<CardPage> pages,
    List<CardAsset> assets = const [],
    this.profileId,
    this.createdAt = '',
    this.updatedAt = '',
    Map<String, Object?> extra = const {},
  }) : pages = List.unmodifiable(pages),
       assets = List.unmodifiable(assets),
       extra = Map.unmodifiable(extra);

  static const kinds = {
    'business',
    'portfolio',
    'social',
    'event',
    'brand',
    'custom',
  };

  factory CardDocument.fromJson(Object? raw, ElementRegistry registry) {
    final j = migrateCardDocument(_map(raw, 'design'));
    final pages = j['pages'];
    final assets = j['assets'] ?? const [];
    if (pages is! List || pages.isEmpty || pages.length > 50 || assets is! List)
      throw const FormatException('Invalid design pages');
    final kind = j['kind'] ?? 'custom';
    final unit = j['unit'] ?? 'mm';
    if (!kinds.contains(kind) || !const {'mm', 'in', 'px', 'pt'}.contains(unit))
      throw const FormatException('Invalid design kind or unit');
    final doc = CardDocument(
      id: _id(j['id']),
      name: _text(j['name'] ?? '', max: 120),
      kind: kind as String,
      unit: unit as String,
      width: _num(j['width'], min: 1, max: 20000),
      height: _num(j['height'], min: 1, max: 20000),
      bleed: _num(j['bleed'] ?? 0, min: 0, max: 100),
      safe: _num(j['safe'] ?? 0, min: 0, max: 1000),
      pages: [for (final p in pages) CardPage.fromJson(p, registry)],
      assets: [for (final a in assets) CardAsset.fromJson(a)],
      profileId: j['profileId'] == null ? null : _id(j['profileId']),
      createdAt: _text(j['createdAt'] ?? '', max: 40),
      updatedAt: _text(j['updatedAt'] ?? '', max: 40),
      extra: {
        for (final e in j.entries)
          if (!_docKeys.contains(e.key)) e.key: e.value,
      },
    );
    doc.validate();
    return doc;
  }

  static const _docKeys = {
    'schema',
    'id',
    'name',
    'kind',
    'unit',
    'width',
    'height',
    'bleed',
    'safe',
    'pages',
    'assets',
    'profileId',
    'createdAt',
    'updatedAt',
  };

  Map<String, Object?> toJson() => {
    ...extra,
    'schema': cardSchemaVersion,
    'id': id,
    'name': name,
    'kind': kind,
    'unit': unit,
    'width': width,
    'height': height,
    'bleed': bleed,
    'safe': safe,
    'pages': [for (final p in pages) p.toJson()],
    'assets': [for (final a in assets) a.toJson()],
    if (profileId != null) 'profileId': profileId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  /// Ids are unique, counts stay inside the limits, and every picture an
  /// element uses is listed.
  void validate() {
    final ids = <String>{};
    var count = 0;
    for (final p in pages) {
      if (!ids.add(p.id)) throw const FormatException('Duplicate page id');
      for (final e in p.all) {
        if (!ids.add(e.id)) throw const FormatException('Duplicate element id');
        if (++count > cardElementLimit)
          throw const FormatException('Too many elements');
        final asset = e.props['asset'];
        if (asset is String && !assets.any((a) => a.id == asset))
          throw const FormatException('Element refers to a missing picture');
      }
    }
  }

  CardDocument copyWith({
    String? name,
    String? kind,
    String? unit,
    double? width,
    double? height,
    double? bleed,
    double? safe,
    List<CardPage>? pages,
    List<CardAsset>? assets,
    String? profileId,
    bool clearProfile = false,
    String? updatedAt,
  }) => CardDocument(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    unit: unit ?? this.unit,
    width: width ?? this.width,
    height: height ?? this.height,
    bleed: bleed ?? this.bleed,
    safe: safe ?? this.safe,
    pages: pages ?? this.pages,
    assets: assets ?? this.assets,
    profileId: clearProfile ? null : profileId ?? this.profileId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    extra: extra,
  );

  CardPage page(String id) => pages.firstWhere((p) => p.id == id);
  Box get trim => Box(0, 0, width, height);

  /// The design as written and read back: the same document.
  String encode() => jsonEncode(toJson());
  static CardDocument decode(String text, ElementRegistry registry) =>
      CardDocument.fromJson(jsonDecode(text), registry);
}

/// Brings an older design up to [cardSchemaVersion]. Each step is a pure
/// function of the JSON; a newer schema is refused, never guessed at.
Map<String, Object?> migrateCardDocument(Map<String, Object?> j) {
  final schema = j['schema'] ?? 0;
  if (schema is! int || schema < 0)
    throw const FormatException('Invalid design schema');
  if (schema > cardSchemaVersion)
    throw const FormatException(
      'This design was made by a newer Handy Card; update the app to open it',
    );
  var out = j;
  // Schema 0 (pre-release drafts) kept a single page under "elements".
  if (schema == 0) {
    out = {
      ...out,
      'schema': 1,
      'pages':
          out['pages'] ??
          [
            {
              'id': 'front',
              'name': 'Front',
              'background': 'FFFFFF',
              'elements': out['elements'] ?? const [],
            },
          ],
    }..remove('elements');
  }
  return out;
}
