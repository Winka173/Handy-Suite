import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark _b(
  String id,
  String url,
  String title, {
  String? col,
  String kind = 'link',
  String source = 'fallback',
}) {
  final u = UrlTools.normalize(url);
  return Bookmark(
    id: id,
    kind: kind,
    originalUrl: kind == 'image' ? '' : u.originalUrl,
    normalizedUrl: kind == 'image' ? '' : u.normalizedUrl,
    platform: kind == 'image' ? 'image' : u.platform,
    contentType: kind == 'image' ? 'image' : u.contentType,
    sourceDomain: kind == 'image' ? '' : u.sourceDomain,
    title: title,
    collectionId: col,
    savedAt: '2026-11-06T10:00:00Z',
    updatedAt: '2026-11-06T10:00:00Z',
    metadataSource: source,
  );
}

void main() {
  final lib = SaveLibrary(
    collections: [
      SaveCollection(id: 'v', name: 'Videos'),
      SaveCollection(id: 'mine', name: 'Mine'),
    ],
    bookmarks: [
      _b('1', 'https://www.youtube.com/watch?v=a', 'Phở bò - YouTube'),
      _b(
        '2',
        'https://www.youtube.com/watch?v=b',
        'Filed already',
        col: 'mine',
      ),
      _b('3', 'https://vnexpress.net/x', 'Tin tức | VnExpress'),
      _b(
        '4',
        'https://www.youtube.com/watch?v=c',
        'Đổi tên - YouTube',
        source: 'user',
      ),
    ],
  );
  final videos = organizePresets.first.copyWith(
    enabled: true,
    collectionId: 'v',
    addTag: 'video',
  );

  test('rules move only unsorted saves, add a tag once, first match wins', () {
    final plan = planOrganize(lib, [
      videos,
      videos.copyWith(collectionId: 'mine'),
    ]);
    final by = {for (final c in plan) c.bookmarkId: c};
    expect(by['1']!.toCollection, 'v');
    expect(by['2']!.toCollection, isNull, reason: 'never move a filed save');
    expect(by['2']!.addTag, 'video');
    expect(by.containsKey('3'), isFalse);
    final after = applyOrganize(lib, plan, '2026-11-07T00:00:00Z');
    final one = after.bookmarks.firstWhere((b) => b.id == '1');
    expect(one.collectionId, 'v');
    expect(one.tags, ['video']);
    expect(
      applyOrganize(
        after,
        planOrganize(after, [videos]),
        '2026-11-07T00:00:00Z',
      ).bookmarks.firstWhere((b) => b.id == '1').tags,
      ['video'],
      reason: 'no duplicate tag',
    );
    expect(after.bookmarks.firstWhere((b) => b.id == '2').collectionId, 'mine');
  });

  test(
    'a rule whose collection is gone only tags; disabled rules do nothing',
    () {
      expect(planOrganize(lib, [videos.copyWith(enabled: false)]), isEmpty);
      final gone = videos.copyWith(collectionId: 'deleted');
      final plan = planOrganize(lib, [gone], ids: ['1']);
      expect(plan.single.toCollection, isNull);
      expect(plan.single.addTag, 'video');
    },
  );

  test(
    'title cleanup drops site names but never touches names the person gave',
    () {
      expect(cleanTitle('Phở bò - YouTube'), 'Phở bò');
      expect(cleanTitle('Tin tức | VnExpress'), 'Tin tức');
      expect(
        cleanTitle('YouTube'),
        'YouTube',
        reason: 'nothing left would be empty',
      );
      final plan = planTitleCleanup(lib, ['1', '3', '4']);
      expect(
        {for (final c in plan) c.$1: c.$3},
        {'1': 'Phở bò', '3': 'Tin tức'},
      );
      final after = applyTitleCleanup(lib, plan, '2026-11-07T00:00:00Z');
      expect(
        after.bookmarks.firstWhere((b) => b.id == '4').title,
        'Đổi tên - YouTube',
      );
    },
  );

  test('rules round-trip through JSON and match titles without accents', () {
    final r = OrganizeRule(
      id: 'r',
      name: 'Phở',
      titleContains: 'pho',
      collectionId: 'v',
    );
    final back = OrganizeRule.fromJson(r.toJson());
    expect(back.titleContains, 'pho');
    expect(back.matches(lib.bookmarks.first), isTrue);
  });
}
