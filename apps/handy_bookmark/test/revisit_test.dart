import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/services/revisit.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark item(
  String id,
  DateTime saved, {
  bool read = false,
  bool archived = false,
}) {
  final u = UrlTools.normalize('https://example.com/$id');
  return Bookmark(
    id: id,
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    title: id,
    savedAt: saved.toUtc().toIso8601String(),
    updatedAt: saved.toUtc().toIso8601String(),
    isRead: read,
    isArchived: archived,
  );
}

void main() {
  // Friday 6 November 2026, 10:00 local.
  final now = DateTime(2026, 11, 6, 10);

  test(
    'counts only recent saves still unread, and picks the next Sunday 19:00',
    () {
      final plan = planRevisit([
        item('new', now.subtract(const Duration(days: 2))),
        item('read', now.subtract(const Duration(days: 1)), read: true),
        item('archived', now.subtract(const Duration(days: 1)), archived: true),
        item('old', now.subtract(const Duration(days: 30))),
      ], now: now);
      expect(plan!.count, 1);
      expect(plan.at, DateTime(2026, 11, 8, 19));
    },
  );

  test('nothing waiting means no nudge at all', () {
    expect(
      planRevisit([
        item('read', now, read: true),
        item('old', now.subtract(const Duration(days: 20))),
      ], now: now),
      isNull,
    );
  });

  test('the chosen day and hour; today only if the hour is still ahead', () {
    final saved = [item('a', now)];
    expect(
      planRevisit(saved, now: now, weekday: DateTime.friday, hour: 18)!.at,
      DateTime(2026, 11, 6, 18),
    );
    expect(
      planRevisit(saved, now: now, weekday: DateTime.friday, hour: 9)!.at,
      DateTime(2026, 11, 13, 9),
    );
  });

  test('the words carry a count, never a title', () {
    expect(
      revisitText(3, vietnamese: true),
      '3 mục bạn lưu gần đây còn chưa xem.',
    );
    expect(
      revisitText(1, vietnamese: false),
      'One thing you saved recently is still waiting.',
    );
  });
}
