import 'models.dart';

enum SaveSort {
  newest,
  oldest,
  updated,
  title,
  domain,
  mostOpened,
  recentlyOpened,
  reminder,

  /// The person's own order (`SaveLibrary.manualOrder`).
  manual,
}

class SearchQuery {
  final String text;
  final String? platform, contentType, collectionId;
  final List<String> tags;
  final bool? isFavorite, isPinned, isArchived, isRead;

  /// True: only links whose last check found a problem.
  final bool? linkIssue;
  final SaveSort sort;
  final String? savedAfter, savedBefore, openedAfter, openedBefore;
  SearchQuery({
    this.text = '',
    this.platform,
    this.contentType,
    this.collectionId,
    List<String> tags = const [],
    this.isFavorite,
    this.isPinned,
    this.isArchived,
    this.isRead,
    this.linkIssue,
    this.sort = SaveSort.newest,
    this.savedAfter,
    this.savedBefore,
    this.openedAfter,
    this.openedBefore,
  }) : tags = List.unmodifiable(tags);
  factory SearchQuery.fromJson(Map<String, dynamic> j) => SearchQuery(
    text: j['text'] as String? ?? '',
    platform: j['platform'] as String?,
    contentType: j['contentType'] as String?,
    collectionId: j['collectionId'] as String?,
    tags: List<String>.from(j['tags'] as List? ?? []),
    isFavorite: j['isFavorite'] as bool?,
    isPinned: j['isPinned'] as bool?,
    isArchived: j['isArchived'] as bool?,
    isRead: j['isRead'] as bool?,
    linkIssue: j['linkIssue'] as bool?,
    sort: SaveSort.values.firstWhere(
      (v) => v.name == j['sort'],
      orElse: () => SaveSort.newest,
    ),
    savedAfter: j['savedAfter'] as String?,
    savedBefore: j['savedBefore'] as String?,
    openedAfter: j['openedAfter'] as String?,
    openedBefore: j['openedBefore'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'text': text,
    'platform': platform,
    'contentType': contentType,
    'collectionId': collectionId,
    'tags': tags,
    'isFavorite': isFavorite,
    'isPinned': isPinned,
    'isArchived': isArchived,
    'isRead': isRead,
    if (linkIssue != null) 'linkIssue': linkIssue,
    'sort': sort.name,
    'savedAfter': savedAfter,
    'savedBefore': savedBefore,
    'openedAfter': openedAfter,
    'openedBefore': openedBefore,
  };
  bool matches(Bookmark b, {String collectionName = ''}) {
    if (openedAfter != null &&
        (b.lastOpenedAt == null ||
            DateTime.parse(
              b.lastOpenedAt!,
            ).isBefore(DateTime.parse(openedAfter!))))
      return false;
    if (openedBefore != null &&
        (b.lastOpenedAt == null ||
            DateTime.parse(
              b.lastOpenedAt!,
            ).isAfter(DateTime.parse(openedBefore!))))
      return false;
    if (platform != null && b.platform != platform ||
        contentType != null && b.contentType != contentType ||
        collectionId != null && b.collectionId != collectionId ||
        isFavorite != null && b.isFavorite != isFavorite ||
        isPinned != null && b.isPinned != isPinned ||
        isArchived != null && b.isArchived != isArchived ||
        isRead != null && b.isRead != isRead)
      return false;
    if (linkIssue != null && (b.linkCheck?.broken ?? false) != linkIssue)
      return false;
    if (savedAfter != null &&
            DateTime.parse(b.savedAt).isBefore(DateTime.parse(savedAfter!)) ||
        savedBefore != null &&
            DateTime.parse(b.savedAt).isAfter(DateTime.parse(savedBefore!)))
      return false;
    final tagSet = b.tags.map((t) => t.toLowerCase()).toSet();
    if (!tags.every((t) => tagSet.contains(t.toLowerCase()))) return false;
    final haystack = '${_text(b)}\n${collectionName.toLowerCase()}';
    return text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .every(haystack.contains);
  }
}

String _text(Bookmark b) => [
  b.title,
  b.description ?? '',
  b.note,
  b.originalUrl,
  b.normalizedUrl,
  b.sourceDomain,
  b.author ?? '',
  b.siteName ?? '',
  b.platform,
  ...b.tags,
].join('\n').toLowerCase();

List<Bookmark> searchBookmarks(
  SaveLibrary library,
  SearchQuery query, {
  SmartCollection? smartCollection,
}) {
  final collectionNames = {for (final c in library.collections) c.id: c.name};
  final result = library.bookmarks
      .where(
        (b) =>
            query.matches(
              b,
              collectionName: collectionNames[b.collectionId] ?? '',
            ) &&
            (smartCollection == null || smartCollection.matches(b)),
      )
      .toList();
  final manual = query.sort == SaveSort.manual
      ? {for (final (i, id) in library.fullManualOrder().indexed) id: i}
      : const <String, int>{};
  int compare(Bookmark a, Bookmark b) => switch (query.sort) {
    SaveSort.newest => b.savedAt.compareTo(a.savedAt),
    SaveSort.oldest => a.savedAt.compareTo(b.savedAt),
    SaveSort.updated => b.updatedAt.compareTo(a.updatedAt),
    SaveSort.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    SaveSort.domain => a.sourceDomain.compareTo(b.sourceDomain),
    SaveSort.mostOpened => b.openedCount.compareTo(a.openedCount),
    SaveSort.recentlyOpened => (b.lastOpenedAt ?? '').compareTo(
      a.lastOpenedAt ?? '',
    ),
    SaveSort.reminder => (a.reminderAt ?? '9999').compareTo(
      b.reminderAt ?? '9999',
    ),
    SaveSort.manual => manual[a.id]!.compareTo(manual[b.id]!),
  };
  result.sort((a, b) {
    final c = compare(a, b);
    return c == 0 ? a.id.compareTo(b.id) : c;
  });
  return result;
}

extension SmartCollectionMatching on SmartCollection {
  bool matches(Bookmark b, {DateTime? now}) {
    final time = now ?? DateTime.now().toUtc();
    return mode == 'all'
        ? rules.every((r) => r.matches(b, now: time))
        : rules.any((r) => r.matches(b, now: time));
  }
}

extension SmartRuleMatching on SmartRule {
  bool matches(Bookmark b, {DateTime? now}) {
    final actual = field == 'text' ? _text(b) : b.toJson()[field];
    final a = actual?.toString().toLowerCase(),
        v = value?.toString().toLowerCase();
    bool equals() => actual is List
        ? actual.any((e) => e.toString().toLowerCase() == v)
        : a == v;
    switch (operator) {
      case 'withinDays':
        final date = DateTime.tryParse(actual?.toString() ?? '');
        if (date == null) return false;
        final age = (now ?? DateTime.now().toUtc()).toUtc().difference(
          date.toUtc(),
        );
        return !age.isNegative &&
            age <=
                Duration(
                  microseconds: ((value as num) * Duration.microsecondsPerDay)
                      .round(),
                );
      case 'equals':
        return equals();
      case 'notEquals':
        return !equals();
      case 'exists':
        return (actual != null && (actual is! String || actual.isNotEmpty)) ==
            (value != false);
      case 'contains':
        return v != null &&
            (actual is List
                ? actual.any((e) => e.toString().toLowerCase().contains(v))
                : a?.contains(v) == true);
      case 'before':
      case 'after':
        final x = DateTime.tryParse(actual?.toString() ?? ''),
            y = DateTime.tryParse(value?.toString() ?? '');
        return x != null &&
            y != null &&
            (operator == 'before' ? x.isBefore(y) : x.isAfter(y));
      case 'greaterThan':
      case 'lessThan':
        final x = num.tryParse(a ?? ''), y = num.tryParse(v ?? '');
        return x != null &&
            y != null &&
            (operator == 'greaterThan' ? x > y : x < y);
      default:
        return false;
    }
  }
}
