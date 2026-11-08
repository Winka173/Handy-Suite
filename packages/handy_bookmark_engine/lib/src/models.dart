import 'urls.dart';

const _unset = Object();
String _string(Map<String, dynamic> j, String k, [String fallback = '']) {
  final v = j[k];
  if (v == null) return fallback;
  if (v is! String) throw FormatException('$k must be text');
  return v;
}

String? _optional(Map<String, dynamic> j, String k) =>
    j[k] == null ? null : _string(j, k);
bool _bool(Map<String, dynamic> j, String k) {
  if (j[k] != null && j[k] is! bool)
    throw FormatException('$k must be boolean');
  return j[k] == true;
}

List<String> _strings(dynamic v) {
  if (v == null) return [];
  if (v is! List || v.any((e) => e is! String))
    throw const FormatException('Expected text list');
  return List<String>.from(v);
}

String _date(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Timestamp must contain timezone');
  }
  return parsed.toUtc().toIso8601String();
}

String _id(String value) {
  if (value.trim().isEmpty || value.length > 512)
    throw const FormatException('Invalid identifier');
  return value;
}

void _bounded(String? value, int length, String field) {
  if (value != null && value.length > length)
    throw FormatException('$field exceeds $length characters');
}

Object? _freeze(Object? value, [int depth = 0]) {
  if (depth > 100)
    throw const FormatException('Saved search is nested too deeply');
  if (value == null || value is String || value is bool) return value;
  if (value is num && value.isFinite) return value;
  if (value is List)
    return List<Object?>.unmodifiable(value.map((e) => _freeze(e, depth + 1)));
  if (value is Map && value.keys.every((k) => k is String))
    return Map<String, Object?>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, _freeze(v, depth + 1))),
    );
  throw const FormatException('Saved search must contain JSON values');
}

/// A picture the person owns: a screenshot or photo saved as an item, or
/// the preview they chose for a link. Addressed by the SHA-256 of its
/// original bytes, so the same picture is stored once however many items
/// use it. Unlike a fetched page thumbnail it is user data, not a cache,
/// and goes into full backups.
class MediaRef {
  static const mimes = {'image/jpeg', 'image/png', 'image/webp'};

  /// Originals larger than this are refused, not resized silently.
  static const maxBytes = 25 * 1024 * 1024;
  final String id, mime, name;
  final int width, height, bytes;
  MediaRef({
    required this.id,
    required this.mime,
    required this.width,
    required this.height,
    required this.bytes,
    this.name = '',
  }) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(id))
      throw const FormatException('Invalid media id');
    if (!mimes.contains(mime))
      throw const FormatException('Unsupported picture type');
    if (width < 1 || height < 1 || width > 20000 || height > 20000)
      throw const FormatException('Invalid picture size');
    if (bytes < 1 || bytes > maxBytes)
      throw const FormatException('Picture too large');
    _bounded(name, 255, 'media name');
  }

  factory MediaRef.fromJson(Map<String, dynamic> j) => MediaRef(
    id: _string(j, 'id'),
    mime: _string(j, 'mime'),
    width: j['width'] is int
        ? j['width'] as int
        : throw const FormatException('Invalid picture width'),
    height: j['height'] is int
        ? j['height'] as int
        : throw const FormatException('Invalid picture height'),
    bytes: j['bytes'] is int
        ? j['bytes'] as int
        : throw const FormatException('Invalid picture bytes'),
    name: _string(j, 'name'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mime': mime,
    'width': width,
    'height': height,
    'bytes': bytes,
    if (name.isNotEmpty) 'name': name,
  };

  String get extension => switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  @override
  bool operator ==(Object other) =>
      other is MediaRef &&
      jsonEncodeSorted(toJson()) == jsonEncodeSorted(other.toJson());
  @override
  int get hashCode => id.hashCode;
}

/// Stable JSON for comparisons.
String jsonEncodeSorted(Map<String, dynamic> m) =>
    (m.keys.toList()..sort()).map((k) => '$k=${m[k]}').join('&');

/// Something deleted for good. Kept so a device that was offline cannot
/// bring the item back when it syncs, and pruned only after long silence.
class Tombstone {
  static const entities = {'bookmark', 'collection'};
  final String entity, id, deletedAt;
  Tombstone({
    required this.entity,
    required String id,
    required String deletedAt,
  }) : id = _id(id),
       deletedAt = _date(deletedAt) {
    if (!entities.contains(entity))
      throw const FormatException('Invalid tombstone entity');
  }
  factory Tombstone.fromJson(Map<String, dynamic> j) => Tombstone(
    entity: _string(j, 'entity'),
    id: _string(j, 'id'),
    deletedAt: _string(j, 'deletedAt'),
  );
  Map<String, dynamic> toJson() => {
    'entity': entity,
    'id': id,
    'deletedAt': deletedAt,
  };
}

class Bookmark {
  final String id,
      originalUrl,
      normalizedUrl,
      platform,
      contentType,
      title,
      sourceDomain;
  final String? canonicalUrl,
      description,
      thumbnailUrl,
      siteName,
      author,
      collectionId,
      lastOpenedAt,
      reminderAt;
  final List<String> tags;
  final String note, savedAt, updatedAt, metadataStatus, metadataSource;
  final bool isFavorite, isPinned, isArchived, isRead;
  final int openedCount;

  /// The last explicit link check, when the person ran one.
  final LinkCheck? linkCheck;

  /// `link`: an address (required), maybe with a picture the person chose.
  /// `image`: a screenshot or photo (required), maybe with the address it
  /// came from.
  final String kind;

  /// The person's own picture: the image of an image item, or a link's
  /// chosen preview.
  final MediaRef? media;

  /// Set while the item is in Recently Deleted.
  final String? deletedAt;

  /// Increases with every local change; sync compares it.
  final int rev;

  bool get isImage => kind == 'image';
  bool get hasUrl => originalUrl.isNotEmpty;

  Bookmark({
    required String id,
    required this.originalUrl,
    required this.normalizedUrl,
    this.canonicalUrl,
    this.platform = 'web',
    this.contentType = 'link',
    this.title = '',
    this.description,
    this.thumbnailUrl,
    this.siteName,
    this.author,
    this.sourceDomain = '',
    this.collectionId,
    List<String> tags = const [],
    this.note = '',
    this.isFavorite = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isRead = false,
    this.openedCount = 0,
    required String savedAt,
    required String updatedAt,
    String? lastOpenedAt,
    this.metadataStatus = 'pending',
    this.metadataSource = 'local',
    String? reminderAt,
    this.linkCheck,
    this.kind = 'link',
    this.media,
    String? deletedAt,
    this.rev = 0,
  }) : id = _id(id),
       deletedAt = deletedAt == null ? null : _date(deletedAt),
       tags = List.unmodifiable(tags),
       savedAt = _date(savedAt),
       updatedAt = _date(updatedAt),
       lastOpenedAt = lastOpenedAt == null ? null : _date(lastOpenedAt),
       reminderAt = reminderAt == null ? null : _date(reminderAt) {
    if (kind != 'link' && kind != 'image')
      throw const FormatException('Invalid item kind');
    if (kind == 'image' && media == null)
      throw const FormatException('An image item needs its picture');
    if (rev < 0) throw const FormatException('Negative revision');
    if (originalUrl.isEmpty) {
      // Only an image may stand without an address.
      if (kind != 'image' || normalizedUrl.isNotEmpty || canonicalUrl != null)
        throw const FormatException('A link needs its address');
    } else {
      _validateUrls();
    }
    _validateRest();
  }

  void _validateUrls() {
    UrlTools.normalize(originalUrl);
    if (Uri.parse(originalUrl).userInfo.isNotEmpty ||
        Uri.parse(normalizedUrl).userInfo.isNotEmpty ||
        (canonicalUrl != null &&
            Uri.parse(canonicalUrl!).userInfo.isNotEmpty)) {
      throw const FormatException('Remove credentials before saving a URL');
    }
    if (UrlTools.normalize(normalizedUrl).normalizedUrl != normalizedUrl)
      throw const FormatException('normalizedUrl is not normalized');
    if (canonicalUrl != null) UrlTools.normalize(canonicalUrl!);
  }

  void _validateRest() {
    if (thumbnailUrl != null) {
      UrlTools.normalize(thumbnailUrl!);
      if (Uri.parse(thumbnailUrl!).userInfo.isNotEmpty)
        throw const FormatException('Thumbnail URL contains credentials');
    }
    if (!{
      'pending',
      'complete',
      'partial',
      'failed',
      'unavailable',
    }.contains(metadataStatus))
      throw const FormatException('Invalid metadata status');
    if (!{
      'share',
      'html',
      'user',
      'fallback',
      'local',
    }.contains(metadataSource))
      throw const FormatException('Invalid metadata source');
    if (openedCount < 0) throw const FormatException('Negative openedCount');
    for (final field in {
      'title': title,
      'siteName': siteName,
      'author': author,
    }.entries) {
      _bounded(field.value, 8192, field.key);
    }
    _bounded(description, 65536, 'description');
    _bounded(note, 262144, 'note');
    _bounded(thumbnailUrl, 8192, 'thumbnailUrl');
    _bounded(sourceDomain, 8192, 'sourceDomain');
    _bounded(platform, 128, 'platform');
    _bounded(contentType, 128, 'contentType');
    _bounded(metadataStatus, 128, 'metadataStatus');
    _bounded(metadataSource, 128, 'metadataSource');
    var tagLength = 0;
    for (final tag in tags) {
      _bounded(tag, 512, 'tag');
      tagLength += tag.length;
    }
    if (tagLength > 262144)
      throw const FormatException('Tags exceed 256 KiB character budget');
  }

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
    id: _string(j, 'id'),
    originalUrl: _string(j, 'originalUrl'),
    normalizedUrl: _string(j, 'normalizedUrl', _string(j, 'originalUrl')),
    kind: _string(j, 'kind', 'link'),
    media: j['media'] == null
        ? null
        : j['media'] is Map
        ? MediaRef.fromJson(Map<String, dynamic>.from(j['media'] as Map))
        : throw const FormatException('Invalid media'),
    deletedAt: _optional(j, 'deletedAt'),
    rev: j['rev'] == null
        ? 0
        : j['rev'] is int
        ? j['rev'] as int
        : throw const FormatException('Invalid revision'),
    canonicalUrl: _optional(j, 'canonicalUrl'),
    platform: _string(j, 'platform', 'web'),
    contentType: _string(j, 'contentType', 'link'),
    title: _string(j, 'title'),
    description: _optional(j, 'description'),
    thumbnailUrl: _optional(j, 'thumbnailUrl'),
    siteName: _optional(j, 'siteName'),
    author: _optional(j, 'author'),
    sourceDomain: _string(j, 'sourceDomain'),
    collectionId: _optional(j, 'collectionId'),
    tags: _strings(j['tags']),
    note: _string(j, 'note'),
    isFavorite: _bool(j, 'isFavorite'),
    isPinned: _bool(j, 'isPinned'),
    isArchived: _bool(j, 'isArchived'),
    isRead: _bool(j, 'isRead'),
    openedCount: j['openedCount'] == null
        ? 0
        : j['openedCount'] is int
        ? j['openedCount'] as int
        : throw const FormatException('Invalid openedCount'),
    savedAt: _string(j, 'savedAt'),
    updatedAt: _string(j, 'updatedAt'),
    lastOpenedAt: _optional(j, 'lastOpenedAt'),
    reminderAt: _optional(j, 'reminderAt'),
    metadataStatus: _string(j, 'metadataStatus', 'pending'),
    metadataSource: _string(j, 'metadataSource', 'local'),
    linkCheck: j['linkCheck'] == null
        ? null
        : j['linkCheck'] is Map
        ? LinkCheck.fromJson(Map<String, dynamic>.from(j['linkCheck'] as Map))
        : throw const FormatException('Invalid linkCheck'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalUrl': originalUrl,
    'normalizedUrl': normalizedUrl,
    'canonicalUrl': canonicalUrl,
    'platform': platform,
    'contentType': contentType,
    'title': title,
    'description': description,
    'thumbnailUrl': thumbnailUrl,
    'siteName': siteName,
    'author': author,
    'sourceDomain': sourceDomain,
    'collectionId': collectionId,
    'tags': tags,
    'note': note,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isRead': isRead,
    'openedCount': openedCount,
    'savedAt': savedAt,
    'updatedAt': updatedAt,
    'lastOpenedAt': lastOpenedAt,
    'reminderAt': reminderAt,
    'metadataStatus': metadataStatus,
    'metadataSource': metadataSource,
    // Written only once a check ran, so unchecked libraries keep their size.
    if (linkCheck != null) 'linkCheck': linkCheck!.toJson(),
    // New fields are written only when used, so older items keep their
    // exact JSON (and older apps can still read libraries without them).
    if (kind != 'link') 'kind': kind,
    if (media != null) 'media': media!.toJson(),
    if (deletedAt != null) 'deletedAt': deletedAt,
    if (rev != 0) 'rev': rev,
  };

  Bookmark copyWith({
    String? id,
    String? originalUrl,
    String? normalizedUrl,
    Object? canonicalUrl = _unset,
    String? platform,
    String? contentType,
    String? title,
    Object? description = _unset,
    Object? thumbnailUrl = _unset,
    Object? siteName = _unset,
    Object? author = _unset,
    String? sourceDomain,
    Object? collectionId = _unset,
    List<String>? tags,
    String? note,
    bool? isFavorite,
    bool? isPinned,
    bool? isArchived,
    bool? isRead,
    int? openedCount,
    String? savedAt,
    String? updatedAt,
    Object? lastOpenedAt = _unset,
    String? metadataStatus,
    String? metadataSource,
    Object? reminderAt = _unset,
    Object? linkCheck = _unset,
    String? kind,
    Object? media = _unset,
    Object? deletedAt = _unset,
    int? rev,
  }) {
    final j = toJson();
    final changes = <String, dynamic>{
      'id': id,
      'originalUrl': originalUrl,
      'normalizedUrl': normalizedUrl,
      'platform': platform,
      'contentType': contentType,
      'title': title,
      'sourceDomain': sourceDomain,
      'tags': tags,
      'note': note,
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isRead': isRead,
      'openedCount': openedCount,
      'savedAt': savedAt,
      'updatedAt': updatedAt,
      'metadataStatus': metadataStatus,
      'metadataSource': metadataSource,
      'kind': kind,
      'rev': rev,
    };
    changes.forEach((k, v) {
      if (v != null) j[k] = v;
    });
    final nullable = {
      'canonicalUrl': canonicalUrl,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'siteName': siteName,
      'author': author,
      'collectionId': collectionId,
      'lastOpenedAt': lastOpenedAt,
      'reminderAt': reminderAt,
    };
    nullable.forEach((k, v) {
      if (!identical(v, _unset)) j[k] = v;
    });
    if (!identical(linkCheck, _unset))
      j['linkCheck'] = (linkCheck as LinkCheck?)?.toJson();
    if (!identical(media, _unset)) j['media'] = (media as MediaRef?)?.toJson();
    if (!identical(deletedAt, _unset)) j['deletedAt'] = deletedAt;
    return Bookmark.fromJson(j);
  }
}

/// What an explicit link check found, and when. `moved` carries the new
/// address from permanent redirects; `gone` is a 404/410; `unreachable` means
/// the check could not tell (network, timeout, sign-in, server error).
class LinkCheck {
  static const statuses = {'ok', 'moved', 'gone', 'unreachable'};
  final String status, checkedAt;
  final String? movedTo, reason;
  final int? httpStatus;
  LinkCheck({
    required this.status,
    required String checkedAt,
    this.movedTo,
    this.httpStatus,
    this.reason,
  }) : checkedAt = _date(checkedAt) {
    if (!statuses.contains(status))
      throw const FormatException('Invalid link status');
    if ((status == 'moved') != (movedTo != null))
      throw const FormatException('Only a moved link has a new address');
    if (movedTo != null) {
      _bounded(movedTo, 8192, 'movedTo');
      UrlTools.normalize(movedTo!);
      if (Uri.parse(movedTo!).userInfo.isNotEmpty)
        throw const FormatException('Moved URL contains credentials');
    }
    if (httpStatus != null && (httpStatus! < 100 || httpStatus! > 599))
      throw const FormatException('Invalid HTTP status');
    _bounded(reason, 128, 'reason');
  }

  /// Anything but a plain `ok` deserves a look.
  bool get broken => status != 'ok';

  factory LinkCheck.fromJson(Map<String, dynamic> j) => LinkCheck(
    status: _string(j, 'status'),
    checkedAt: _string(j, 'checkedAt'),
    movedTo: _optional(j, 'movedTo'),
    httpStatus: j['httpStatus'] == null
        ? null
        : j['httpStatus'] is int
        ? j['httpStatus'] as int
        : throw const FormatException('Invalid httpStatus'),
    reason: _optional(j, 'reason'),
  );
  Map<String, dynamic> toJson() => {
    'status': status,
    'checkedAt': checkedAt,
    if (movedTo != null) 'movedTo': movedTo,
    if (httpStatus != null) 'httpStatus': httpStatus,
    if (reason != null) 'reason': reason,
  };
}

class SaveCollection {
  final String id, name, color, icon, description;
  final String? parentId;
  final int position;
  SaveCollection({
    required String id,
    required this.name,
    this.parentId,
    this.color = '#6366F1',
    this.icon = 'folder',
    this.description = '',
    this.position = 0,
  }) : id = _id(id) {
    if (name.trim().isEmpty)
      throw const FormatException('Collection needs a name');
    _bounded(name, 8192, 'collection name');
    _bounded(description, 65536, 'collection description');
    _bounded(color, 128, 'color');
    _bounded(icon, 256, 'icon');
  }
  factory SaveCollection.fromJson(Map<String, dynamic> j) => SaveCollection(
    id: _string(j, 'id'),
    name: _string(j, 'name'),
    parentId: _optional(j, 'parentId'),
    color: _string(j, 'color', '#6366F1'),
    icon: _string(j, 'icon', 'folder'),
    description: _string(j, 'description'),
    position: j['position'] is int ? j['position'] as int : 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'color': color,
    'icon': icon,
    'description': description,
    'position': position,
  };
  SaveCollection copyWith({
    String? id,
    String? name,
    Object? parentId = _unset,
    String? color,
    String? icon,
    String? description,
    int? position,
  }) => SaveCollection(
    id: id ?? this.id,
    name: name ?? this.name,
    parentId: identical(parentId, _unset) ? this.parentId : parentId as String?,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    description: description ?? this.description,
    position: position ?? this.position,
  );
}

class SmartRule {
  final String field, operator;
  final Object? value;
  SmartRule({
    required this.field,
    required this.operator,
    required this.value,
  }) {
    if (!{
          'text',
          'title',
          'note',
          'platform',
          'contentType',
          'sourceDomain',
          'collectionId',
          'tags',
          'isFavorite',
          'isPinned',
          'isArchived',
          'isRead',
          'savedAt',
          'updatedAt',
          'reminderAt',
          'openedCount',
        }.contains(field) ||
        !{
          'equals',
          'contains',
          'notEquals',
          'before',
          'after',
          'greaterThan',
          'lessThan',
          'exists',
          'withinDays',
        }.contains(operator))
      throw const FormatException('Unsupported smart rule');
    if (value != null && value is! String && value is! num && value is! bool)
      throw const FormatException('Invalid smart rule value');
    if (value is num && !(value as num).isFinite)
      throw const FormatException('Invalid numeric rule value');
    if (operator == 'withinDays' &&
        (value is! num || (value as num) < 1 || (value as num) > 36500)) {
      throw const FormatException('withinDays requires 1 to 36500 days');
    }
  }
  factory SmartRule.fromJson(Map<String, dynamic> j) => SmartRule(
    field: _string(j, 'field'),
    operator: _string(j, 'operator'),
    value: j['value'],
  );
  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator,
    'value': value,
  };
  SmartRule copyWith({
    String? field,
    String? operator,
    Object? value = _unset,
  }) => SmartRule(
    field: field ?? this.field,
    operator: operator ?? this.operator,
    value: identical(value, _unset) ? this.value : value,
  );
}

class SmartCollection {
  final String id, name, mode;
  final List<SmartRule> rules;
  SmartCollection({
    required String id,
    required this.name,
    this.mode = 'all',
    List<SmartRule> rules = const [],
  }) : id = _id(id),
       rules = List.unmodifiable(rules) {
    if (!{'all', 'any'}.contains(mode))
      throw const FormatException('Invalid smart collection mode');
    if (name.trim().isEmpty)
      throw const FormatException('Smart collection needs a name');
    _bounded(name, 8192, 'smart collection name');
  }
  factory SmartCollection.fromJson(Map<String, dynamic> j) => SmartCollection(
    id: _string(j, 'id'),
    name: _string(j, 'name'),
    mode: _string(j, 'mode', 'all'),
    rules: _objects(j['rules'], SmartRule.fromJson),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode,
    'rules': rules.map((e) => e.toJson()).toList(),
  };
  SmartCollection copyWith({
    String? id,
    String? name,
    String? mode,
    List<SmartRule>? rules,
  }) => SmartCollection(
    id: id ?? this.id,
    name: name ?? this.name,
    mode: mode ?? this.mode,
    rules: rules ?? this.rules,
  );
}

class SavedSearch {
  final String id, name;
  final Map<String, dynamic> query;
  SavedSearch({
    required String id,
    required this.name,
    Map<String, dynamic> query = const {},
  }) : id = _id(id),
       query = _freeze(query) as Map<String, dynamic> {
    if (name.trim().isEmpty)
      throw const FormatException('Saved search needs a name');
    _bounded(name, 8192, 'saved search name');
  }
  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
    id: _string(j, 'id'),
    name: _string(j, 'name'),
    query: Map<String, dynamic>.from(j['query'] as Map? ?? {}),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'query': query};
  SavedSearch copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? query,
  }) => SavedSearch(
    id: id ?? this.id,
    name: name ?? this.name,
    query: query ?? this.query,
  );
}

List<T> _objects<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  if (value == null) return [];
  if (value is! List) throw const FormatException('Expected array');
  return value.map((e) {
    if (e is! Map) throw const FormatException('Expected object');
    return parse(Map<String, dynamic>.from(e));
  }).toList();
}

class SaveLibrary {
  /// Library format. 2 added the manual order and link checks; 3 added
  /// pictures, Recently Deleted and tombstones. A library that uses none of
  /// 3's additions is still written as 2. 1 and 2 still read.
  static const version = 3;

  /// Items in Recently Deleted stay this long before they go for good.
  static const trashRetention = Duration(days: 30);
  final List<String> tags;
  final List<Bookmark> bookmarks;
  final List<SaveCollection> collections;
  final List<SmartCollection> smartCollections;
  final List<SavedSearch> savedSearches;

  /// Bookmark ids in the person's own order. Unknown ids and repeats are
  /// dropped; links that are not listed follow in saving order.
  final List<String> manualOrder;

  /// Recently Deleted: whole items with [Bookmark.deletedAt], kept apart so
  /// no list, search, count, export or Focus queue can show them by mistake.
  final List<Bookmark> trash;

  /// Items and collections deleted for good (for sync).
  final List<Tombstone> tombstones;
  SaveLibrary({
    List<String> tags = const [],
    List<Bookmark> bookmarks = const [],
    List<SaveCollection> collections = const [],
    List<SmartCollection> smartCollections = const [],
    List<SavedSearch> savedSearches = const [],
    List<String> manualOrder = const [],
    List<Bookmark> trash = const [],
    List<Tombstone> tombstones = const [],
  }) : tags = List.unmodifiable(tags.toSet()),
       trash = _trash(trash, collections),
       tombstones = List.unmodifiable(tombstones),
       bookmarks = List.unmodifiable(bookmarks),
       collections = List.unmodifiable(_oneLevel(collections)),
       smartCollections = List.unmodifiable(smartCollections),
       savedSearches = List.unmodifiable(savedSearches),
       manualOrder = _order(manualOrder, bookmarks) {
    validate();
  }

  /// Folders are one level deep: a collection inside a folder becomes a
  /// folder of the top collection above it. Items stay where they are; a
  /// broken tree (a cycle, a missing parent) is left for [validate].
  static List<SaveCollection> _oneLevel(List<SaveCollection> collections) {
    final byId = {for (final c in collections) c.id: c};
    String? top(SaveCollection c) {
      var at = c;
      for (var i = 0; i <= collections.length; i++) {
        final parent = at.parentId == null ? null : byId[at.parentId];
        if (parent == null) return at.parentId == null ? at.id : null;
        at = parent;
      }
      return null;
    }

    return [
      for (final c in collections)
        if (c.parentId != null && byId[c.parentId]?.parentId != null)
          switch (top(c)) {
            final root? => c.copyWith(parentId: root),
            null => c,
          }
        else
          c,
    ];
  }

  /// A deleted item whose collection is gone returns to Not sorted.
  static List<Bookmark> _trash(
    List<Bookmark> trash,
    List<SaveCollection> collections,
  ) {
    if (trash.isEmpty) return const [];
    final known = {for (final c in collections) c.id};
    return List.unmodifiable([
      for (final b in trash)
        b.collectionId != null && !known.contains(b.collectionId)
            ? b.copyWith(collectionId: null)
            : b,
    ]);
  }

  static List<String> _order(List<String> order, List<Bookmark> bookmarks) {
    if (order.isEmpty) return const [];
    final known = {for (final b in bookmarks) b.id};
    final seen = <String>{};
    return List.unmodifiable([
      for (final id in order)
        if (known.contains(id) && seen.add(id)) id,
    ]);
  }

  /// Reads a stored library or a file. A collection whose parent is not
  /// there (or that is its own ancestor) moves to the top, and an item
  /// filed in a collection that is not there goes to Not sorted: a damaged
  /// tree never locks the person out of their library or refuses a backup.
  factory SaveLibrary.fromJson(Map<String, dynamic> j) {
    if (j['version'] != null && !{1, 2, 3}.contains(j['version']))
      throw const FormatException('Unsupported library version');
    final collections = _repairTree(
      _objects(j['collections'], SaveCollection.fromJson),
    );
    final known = {for (final c in collections) c.id};
    return SaveLibrary(
      tags: _strings(j['tags']),
      bookmarks: [
        for (final b in _objects(j['bookmarks'], Bookmark.fromJson))
          b.collectionId != null && !known.contains(b.collectionId)
              ? b.copyWith(collectionId: null)
              : b,
      ],
      collections: collections,
      smartCollections: _objects(
        j['smartCollections'],
        SmartCollection.fromJson,
      ),
      savedSearches: _objects(j['savedSearches'], SavedSearch.fromJson),
      manualOrder: _strings(j['manualOrder']),
      trash: _objects(j['trash'], Bookmark.fromJson),
      tombstones: _objects(j['tombstones'], Tombstone.fromJson),
    );
  }

  /// [collections] with every missing parent, and every link that closes a
  /// cycle, cleared (that collection moves to the top).
  static List<SaveCollection> _repairTree(List<SaveCollection> collections) {
    final byId = {for (final c in collections) c.id: c};
    for (final c in collections) {
      if (c.parentId != null && !byId.containsKey(c.parentId))
        byId[c.id] = c.copyWith(parentId: null);
    }
    final settled = <String>{};
    for (final start in collections) {
      final path = <String>[];
      String? at = start.id;
      while (at != null && !settled.contains(at)) {
        if (path.contains(at)) {
          // [at] is its own ancestor: the last step back to it is cut.
          final last = path.last;
          byId[last] = byId[last]!.copyWith(parentId: null);
          break;
        }
        path.add(at);
        at = byId[at]!.parentId;
      }
      settled.addAll(path);
    }
    return [for (final c in collections) byId[c.id]!];
  }

  /// Whether anything needs format 3 to be read back.
  bool get usesVersion3 =>
      trash.isNotEmpty ||
      tombstones.isNotEmpty ||
      bookmarks.any((b) => b.kind != 'link' || b.media != null || b.rev != 0);

  Map<String, dynamic> toJson() => {
    'format': 'handy-save',
    'version': usesVersion3 ? version : 2,
    'tags': tags,
    'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
    'collections': collections.map((e) => e.toJson()).toList(),
    'smartCollections': smartCollections.map((e) => e.toJson()).toList(),
    'savedSearches': savedSearches.map((e) => e.toJson()).toList(),
    'manualOrder': manualOrder,
    if (trash.isNotEmpty) 'trash': trash.map((e) => e.toJson()).toList(),
    if (tombstones.isNotEmpty)
      'tombstones': tombstones.map((e) => e.toJson()).toList(),
  };
  SaveLibrary copyWith({
    List<String>? tags,
    List<Bookmark>? bookmarks,
    List<SaveCollection>? collections,
    List<SmartCollection>? smartCollections,
    List<SavedSearch>? savedSearches,
    List<String>? manualOrder,
    List<Bookmark>? trash,
    List<Tombstone>? tombstones,
  }) => SaveLibrary(
    tags: tags ?? this.tags,
    bookmarks: bookmarks ?? this.bookmarks,
    collections: collections ?? this.collections,
    smartCollections: smartCollections ?? this.smartCollections,
    savedSearches: savedSearches ?? this.savedSearches,
    manualOrder: manualOrder ?? this.manualOrder,
    trash: trash ?? this.trash,
    tombstones: tombstones ?? this.tombstones,
  );

  /// Every bookmark id in manual order: the listed ones, then the rest in
  /// the order they were saved.
  List<String> fullManualOrder() {
    final listed = manualOrder.toSet();
    return [
      ...manualOrder,
      for (final b in bookmarks)
        if (!listed.contains(b.id)) b.id,
    ];
  }

  void validate() {
    for (final tag in tags) {
      if (tag.trim().isEmpty) throw const FormatException('Empty tag');
      _bounded(tag, 512, 'tag');
    }
    void unique(Iterable<String> ids) {
      final seen = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) throw const FormatException('Duplicate identifier');
      }
    }

    unique([...bookmarks.map((e) => e.id), ...trash.map((e) => e.id)]);
    for (final b in bookmarks) {
      if (b.deletedAt != null)
        throw const FormatException('A deleted item is not in Trash');
    }
    for (final b in trash) {
      if (b.deletedAt == null)
        throw const FormatException('A Trash item has no deletion time');
    }
    unique(collections.map((e) => e.id));
    unique(smartCollections.map((e) => e.id));
    unique(savedSearches.map((e) => e.id));
    final byId = {for (final c in collections) c.id: c};
    final complete = <String>{};
    for (final c in collections) {
      final seen = <String>{};
      String? parent = c.id;
      while (parent != null) {
        if (complete.contains(parent)) break;
        if (!seen.add(parent)) throw const FormatException('Collection cycle');
        final p = byId[parent];
        if (p == null) throw const FormatException('Missing parent collection');
        parent = p.parentId;
      }
      complete.addAll(seen);
    }
    for (final b in bookmarks) {
      if (b.collectionId != null && !byId.containsKey(b.collectionId))
        throw const FormatException('Missing bookmark collection');
    }
  }
}
