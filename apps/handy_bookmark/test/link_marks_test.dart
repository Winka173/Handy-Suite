import 'package:handy_bookmark/design/identity.dart';
import 'package:handy_bookmark/design/theme.dart';
import 'package:handy_ui/kit.dart';
import 'pro_looks_test.dart' show saveAccentForTest;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/ui/item_marks.dart';
import 'package:handy_bookmark/ui/visual.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

Bookmark _with(LinkCheck? check) => Bookmark(
  id: 'a' * 32,
  originalUrl: 'https://www.facebook.com/reel/1',
  normalizedUrl: 'https://facebook.com/reel/1',
  platform: 'facebook',
  contentType: 'video',
  sourceDomain: 'facebook.com',
  title: 'A reel',
  savedAt: '2026-11-01T00:00:00Z',
  updatedAt: '2026-11-01T00:00:00Z',
  linkCheck: check,
);

LinkCheck _check(String status, {int? http, String? reason}) => LinkCheck(
  status: status,
  checkedAt: '2026-11-14T00:00:00Z',
  httpStatus: http,
  reason: reason,
  movedTo: status == 'moved' ? 'https://www.facebook.com/reel/2' : null,
);

void main() {
  testWidgets('only a page known to be gone or moved is marked; a site that '
      'refused the check is not', (t) async {
    Future<bool> marked(LinkCheck check) async {
      await t.pumpWidget(
        MaterialApp(
          theme: bookmarkTheme(
            buildHandyTheme(
              saveAccentForTest,
              Brightness.light,
              bookmarkIdentity,
            ),
          ),
          home: Scaffold(body: ItemCornerMarks(_with(check))),
        ),
      );
      return find.byKey(Key('mark-broken-${'a' * 32}')).evaluate().isNotEmpty;
    }

    // Facebook answers an automatic check with 400/403/429 or a sign-in
    // page while the link opens fine in a browser.
    expect(
      await marked(_check('unreachable', http: 403, reason: 'http')),
      isFalse,
    );
    expect(
      await marked(_check('unreachable', http: 429, reason: 'http')),
      isFalse,
    );
    expect(await marked(_check('unreachable', reason: 'timeout')), isFalse);
    expect(await marked(_check('ok', http: 200)), isFalse);
    expect(await marked(_check('gone', http: 404)), isTrue);
    expect(await marked(_check('moved', http: 200)), isTrue);
  });

  test('only a gone page is greyed out', () {
    expect(linkDead(_with(_check('gone', http: 404))), isTrue);
    expect(
      linkDead(_with(_check('unreachable', http: 403, reason: 'http'))),
      isFalse,
    );
    expect(linkDead(_with(_check('moved'))), isFalse);
    expect(linkDead(_with(null)), isFalse);
  });
}
