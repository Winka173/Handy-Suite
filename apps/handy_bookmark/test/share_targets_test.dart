import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'package:handy_bookmark/services/share_targets.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'controller_test.dart' show TestStore, TestInbox;

Future<(SaveController, TestInbox)> _open() async {
  final inbox = TestInbox();
  final c = SaveController(open: () async => TestStore(), shares: inbox);
  await c.initialize();
  await c.update(
    (l) => l.copyWith(
      collections: [
        SaveCollection(id: 'food', name: 'Good food', position: 0),
        SaveCollection(id: 'trips', name: 'Trips', position: 1),
        SaveCollection(id: 'read', name: 'Read later', position: 2),
        SaveCollection(id: 'home', name: 'Home', position: 3),
        SaveCollection(id: 'work', name: 'Work', position: 4),
      ],
    ),
  );
  return (c, inbox);
}

void main() {
  test('the share sheet offers the collections saved into most recently, '
      'then the rest in order, four at most', () async {
    final (c, _) = await _open();
    expect(shareTargets(c.library!).map((x) => x.id), [
      'food',
      'trips',
      'read',
      'home',
    ]);

    await c.quickSave('https://a.com/1', collectionId: 'work');
    await c.quickSave('https://a.com/2', collectionId: 'read');
    expect(shareTargets(c.library!).map((x) => x.id), [
      'read',
      'work',
      'food',
      'trips',
    ]);
    expect(shareTargets(c.library!, max: 2), hasLength(2));
    c.dispose();
  });

  test('a share sent to a collection is saved into it; an unsorted copy '
      'moves in; a collection that is gone falls back to Not sorted', () async {
    final (c, inbox) = await _open();
    await c.quickSave('https://b.com/old');
    inbox.pending = [
      const SharedLink('one', 'https://b.com/new', 'New', [], 'food'),
      const SharedLink('two', 'https://b.com/old', null, [], 'trips'),
      const SharedLink('three', 'https://b.com/lost', null, [], 'deleted'),
    ];
    await c.drain();
    String? into(String url) => c.library!.bookmarks
        .firstWhere((b) => b.originalUrl == url)
        .collectionId;
    expect(into('https://b.com/new'), 'food');
    expect(into('https://b.com/old'), 'trips');
    expect(into('https://b.com/lost'), isNull);
    expect(c.library!.bookmarks, hasLength(3), reason: 'no duplicate');
    expect(inbox.acknowledgments, ['one', 'two', 'three']);
    c.dispose();
  });

  test('a link already in a collection is not moved by a share', () async {
    final (c, inbox) = await _open();
    await c.quickSave('https://c.com/x', collectionId: 'home');
    inbox.pending = [
      const SharedLink('one', 'https://c.com/x', null, [], 'food'),
    ];
    await c.drain();
    expect(c.library!.bookmarks.single.collectionId, 'home');
    c.dispose();
  });
}
