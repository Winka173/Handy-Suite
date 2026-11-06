import 'models.dart';
import 'search.dart';

/// One Auto-organize rule: when a save matches, put it in a collection
/// and/or add a tag. Rules never move a save the person already filed,
/// never rename, and never reach the network.
class OrganizeRule {
  final String id, name;
  final bool enabled;

  /// Platforms ('youtube') or sites ('shopee.vn'); empty: any source.
  final List<String> sources;

  /// 'link' or 'image'; null: either.
  final String? kind;

  /// Words the title must contain (case and accents ignored); null: any.
  final String? titleContains;
  final String? collectionId, addTag;
  const OrganizeRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.sources = const [],
    this.kind,
    this.titleContains,
    this.collectionId,
    this.addTag,
  });

  factory OrganizeRule.fromJson(Map<String, dynamic> j) => OrganizeRule(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    enabled: j['enabled'] != false,
    sources: [for (final s in j['sources'] as List? ?? const []) '$s'],
    kind: j['kind'] as String?,
    titleContains: j['titleContains'] as String?,
    collectionId: j['collectionId'] as String?,
    addTag: j['addTag'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'sources': sources,
    'kind': ?kind,
    'titleContains': ?titleContains,
    'collectionId': ?collectionId,
    'addTag': ?addTag,
  };

  OrganizeRule copyWith({
    bool? enabled,
    String? collectionId,
    String? addTag,
  }) => OrganizeRule(
    id: id,
    name: name,
    enabled: enabled ?? this.enabled,
    sources: sources,
    kind: kind,
    titleContains: titleContains,
    collectionId: collectionId ?? this.collectionId,
    addTag: addTag ?? this.addTag,
  );

  bool matches(Bookmark b) {
    if (kind == 'image' && !b.isImage) return false;
    if (kind == 'link' && b.isImage) return false;
    if (sources.isNotEmpty) {
      final domain = b.sourceDomain.replaceFirst(RegExp(r'^www\.'), '');
      final hit = sources.any(
        (s) => s == b.platform || domain == s || domain.endsWith('.$s'),
      );
      if (!hit) return false;
    }
    final words = titleContains?.trim();
    if (words != null && words.isNotEmpty) {
      if (!foldSearch(b.title).contains(foldSearch(words))) return false;
    }
    return true;
  }
}

/// Ready-made rules (no destination until the person picks one).
const organizePresets = [
  OrganizeRule(
    id: 'videos',
    name: 'Videos',
    sources: ['youtube', 'tiktok', 'vimeo', 'youtu.be'],
    enabled: false,
  ),
  OrganizeRule(
    id: 'shopping',
    name: 'Shopping',
    sources: [
      'shopee',
      'lazada',
      'tiki',
      'amazon',
      'shopee.vn',
      'lazada.vn',
      'tiki.vn',
    ],
    enabled: false,
  ),
  OrganizeRule(
    id: 'development',
    name: 'Development',
    sources: ['github', 'stackoverflow', 'github.com', 'stackoverflow.com'],
    enabled: false,
  ),
  OrganizeRule(id: 'pictures', name: 'Pictures', kind: 'image', enabled: false),
];

/// One planned change, shown before anything is written.
class OrganizeChange {
  final String bookmarkId, ruleId;
  final String? toCollection, addTag;
  const OrganizeChange({
    required this.bookmarkId,
    required this.ruleId,
    this.toCollection,
    this.addTag,
  });
}

/// What [rules] would do to [ids] (all live saves when null): the first
/// enabled matching rule wins; a save already in a collection is never
/// moved, a tag already there is not added again; a rule whose collection
/// no longer exists only tags.
List<OrganizeChange> planOrganize(
  SaveLibrary l,
  List<OrganizeRule> rules, {
  Iterable<String>? ids,
}) {
  final only = ids?.toSet();
  final known = {for (final c in l.collections) c.id};
  final out = <OrganizeChange>[];
  for (final b in l.bookmarks) {
    if (b.isArchived || (only != null && !only.contains(b.id))) continue;
    for (final r in rules) {
      if (!r.enabled || !r.matches(b)) continue;
      final move = b.collectionId == null && known.contains(r.collectionId)
          ? r.collectionId
          : null;
      final tag =
          r.addTag != null &&
              r.addTag!.trim().isNotEmpty &&
              !b.tags.contains(r.addTag!.trim())
          ? r.addTag!.trim()
          : null;
      if (move != null || tag != null)
        out.add(
          OrganizeChange(
            bookmarkId: b.id,
            ruleId: r.id,
            toCollection: move,
            addTag: tag,
          ),
        );
      break;
    }
  }
  return out;
}

/// Applies planned changes; nothing else about a save changes.
SaveLibrary applyOrganize(
  SaveLibrary l,
  List<OrganizeChange> changes,
  String now,
) {
  final by = {for (final c in changes) c.bookmarkId: c};
  return l.copyWith(
    tags: {
      ...l.tags,
      for (final c in changes)
        if (c.addTag != null) c.addTag!,
    }.toList(),
    bookmarks: [
      for (final b in l.bookmarks)
        if (by[b.id] case final c?)
          b.copyWith(
            collectionId: c.toCollection ?? b.collectionId,
            tags: c.addTag == null ? b.tags : [...b.tags, c.addTag!],
            updatedAt: now,
          )
        else
          b,
    ],
  );
}

/// Site names that pages append to their titles.
const titleNoise = [
  ' - YouTube',
  ' | YouTube',
  ' - TikTok',
  ' | TikTok',
  ' | Facebook',
  ' - Facebook',
  ' | Instagram',
  ' • Instagram',
  ' | Shopee Việt Nam',
  ' | Shopee Vietnam',
  ' | Lazada.vn',
  ' | Tiki',
  ' - GitHub',
  ' · GitHub',
  ' - Stack Overflow',
  ' | VnExpress',
  ' - VnExpress',
];

/// A title without the site's name tacked on at the end.
String cleanTitle(String title) {
  var t = title.trim();
  for (final n in titleNoise) {
    if (t.toLowerCase().endsWith(n.toLowerCase()) && t.length > n.length + 2) {
      t = t.substring(0, t.length - n.length).trim();
    }
  }
  return t;
}

/// Titles that would change, as (id, before, after); names the person
/// gave are left alone.
List<(String, String, String)> planTitleCleanup(
  SaveLibrary l,
  Iterable<String> ids,
) {
  final only = ids.toSet();
  return [
    for (final b in l.bookmarks)
      if (only.contains(b.id) && b.metadataSource != 'user')
        if (cleanTitle(b.title) case final after when after != b.title)
          (b.id, b.title, after),
  ];
}

SaveLibrary applyTitleCleanup(
  SaveLibrary l,
  List<(String, String, String)> changes,
  String now,
) {
  final by = {for (final c in changes) c.$1: c.$3};
  return l.copyWith(
    bookmarks: [
      for (final b in l.bookmarks)
        if (by[b.id] case final t?) b.copyWith(title: t, updatedAt: now) else b,
    ],
  );
}
