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
  }) : id = _id(id),
       tags = List.unmodifiable(tags),
       savedAt = _date(savedAt),
       updatedAt = _date(updatedAt),
       lastOpenedAt = lastOpenedAt == null ? null : _date(lastOpenedAt),
       reminderAt = reminderAt == null ? null : _date(reminderAt) {
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
    return Bookmark.fromJson(j);
  }
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
  final List<String> tags;
  final List<Bookmark> bookmarks;
  final List<SaveCollection> collections;
  final List<SmartCollection> smartCollections;
  final List<SavedSearch> savedSearches;
  SaveLibrary({
    List<String> tags = const [],
    List<Bookmark> bookmarks = const [],
    List<SaveCollection> collections = const [],
    List<SmartCollection> smartCollections = const [],
    List<SavedSearch> savedSearches = const [],
  }) : tags = List.unmodifiable(tags.toSet()),
       bookmarks = List.unmodifiable(bookmarks),
       collections = List.unmodifiable(collections),
       smartCollections = List.unmodifiable(smartCollections),
       savedSearches = List.unmodifiable(savedSearches) {
    validate();
  }
  factory SaveLibrary.fromJson(Map<String, dynamic> j) {
    if (j['version'] != null && j['version'] != 1)
      throw const FormatException('Unsupported library version');
    return SaveLibrary(
      tags: _strings(j['tags']),
      bookmarks: _objects(j['bookmarks'], Bookmark.fromJson),
      collections: _objects(j['collections'], SaveCollection.fromJson),
      smartCollections: _objects(
        j['smartCollections'],
        SmartCollection.fromJson,
      ),
      savedSearches: _objects(j['savedSearches'], SavedSearch.fromJson),
    );
  }
  Map<String, dynamic> toJson() => {
    'format': 'handy-save',
    'version': 1,
    'tags': tags,
    'bookmarks': bookmarks.map((e) => e.toJson()).toList(),
    'collections': collections.map((e) => e.toJson()).toList(),
    'smartCollections': smartCollections.map((e) => e.toJson()).toList(),
    'savedSearches': savedSearches.map((e) => e.toJson()).toList(),
  };
  SaveLibrary copyWith({
    List<String>? tags,
    List<Bookmark>? bookmarks,
    List<SaveCollection>? collections,
    List<SmartCollection>? smartCollections,
    List<SavedSearch>? savedSearches,
  }) => SaveLibrary(
    tags: tags ?? this.tags,
    bookmarks: bookmarks ?? this.bookmarks,
    collections: collections ?? this.collections,
    smartCollections: smartCollections ?? this.smartCollections,
    savedSearches: savedSearches ?? this.savedSearches,
  );
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

    unique(bookmarks.map((e) => e.id));
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
