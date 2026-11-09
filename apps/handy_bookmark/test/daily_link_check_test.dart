import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark/ui/visual.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'link_tasks_test.dart' as lt show boot, idOf;
import 'new_flows_test.dart' show boot, settle;

final day = DateTime(2026, 11, 10, 9);

void main() {
  test('the day\'s check marks broken links, never deletes them, and runs '
      'once a day', () async {
    final (c, net, _) = await lt.boot();
    net.probes['https://b.org/gone'] = [const LinkProbe(status: 404)];
    final tasks = LinkTasks(c, hostSpacing: Duration.zero);
    final r = await tasks.dailyCheck(now: day);
    expect(r!.quiet, isTrue);
    expect(r.done, 4);
    expect(c.library!.bookmarks, hasLength(4));
    final gone = c.library!.bookmarks.firstWhere(
      (b) => b.id == lt.idOf(c, 'https://b.org/gone'),
    );
    expect(gone.linkCheck!.status, 'gone');
    expect(linkDead(gone), isTrue);
    expect(c.preferences['linkCheckDay'], '2026-11-10');
    // Something to tell, so its report stays (quiet: no notification).
    expect(tasks.last?.broken, greaterThan(0));
    // Not again the same day.
    net.asked.clear();
    expect(
      await tasks.dailyCheck(now: day.add(const Duration(hours: 5))),
      isNull,
    );
    expect(net.asked, isEmpty);
    // The next day: everything was checked this week, so nothing is asked.
    expect(
      await tasks.dailyCheck(now: day.add(const Duration(days: 1))),
      isNull,
    );
    expect(net.asked, isEmpty);
    expect(c.preferences['linkCheckDay'], '2026-11-11');
    tasks.dispose();
    c.dispose();
  });

  test(
    'offline, the day\'s check marks nothing and tries again later',
    () async {
      final (c, net, _) = await lt.boot();
      for (final b in c.library!.bookmarks) {
        net.probes[b.originalUrl] = [const LinkProbe(error: 'timeout')];
      }
      final tasks = LinkTasks(c, hostSpacing: Duration.zero);
      await tasks.dailyCheck(now: day);
      expect(c.library!.bookmarks.every((b) => b.linkCheck == null), isTrue);
      expect(c.preferences['linkCheckDay'], isNull);
      expect(tasks.last, isNull);
      tasks.dispose();
      c.dispose();
    },
  );

  test('it follows "Read pages after saving" until set on its own, and picks '
      'never-checked links first', () async {
    expect(LinkTasks.dailyAllowed({}), isTrue);
    expect(LinkTasks.dailyAllowed({'automaticMetadata': false}), isFalse);
    expect(
      LinkTasks.dailyAllowed({
        'automaticMetadata': false,
        'dailyLinkCheck': true,
      }),
      isTrue,
    );
    final (c, net, _) = await lt.boot();
    await c.update(
      (l) => l,
      prefs: {...c.preferences, 'dailyLinkCheck': false},
    );
    final tasks = LinkTasks(c, hostSpacing: Duration.zero);
    expect(await tasks.dailyCheck(now: day), isNull);
    expect(net.asked, isEmpty);
    LinkCheck at(String when) => LinkCheck(status: 'ok', checkedAt: when);
    final l = c.library!;
    final [a, b, cc, d] = l.bookmarks;
    final picked = LinkTasks.dailyPick(
      l.copyWith(
        bookmarks: [
          a.copyWith(linkCheck: at('2026-10-01T00:00:00Z')),
          b.copyWith(linkCheck: at('2026-11-09T00:00:00Z')),
          cc,
          d.copyWith(linkCheck: at('2026-09-01T00:00:00Z')),
        ],
      ),
      day,
    );
    expect(picked, [cc.id, d.id, a.id]);
    tasks.dispose();
    c.dispose();
  });

  testWidgets('a broken link\'s card says so in words', (t) async {
    final (c, _) = await boot(t);
    final first = c.library!.bookmarks.first;
    await c.update(
      (l) => l.copyWith(
        bookmarks: [
          for (final b in l.bookmarks)
            b.id == first.id
                ? b.copyWith(
                    linkCheck: LinkCheck(
                      status: 'gone',
                      httpStatus: 404,
                      checkedAt: '2026-11-10T00:00:00Z',
                    ),
                  )
                : b,
        ],
      ),
    );
    await settle(t);
    final recent = find.byKey(ValueKey('recent-${first.id}'));
    await t.ensureVisible(recent);
    await settle(t);
    expect(find.byKey(Key('mark-broken-${first.id}')), findsOneWidget);
    expect(find.text('Gone'), findsWidgets);
  });
}
