import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/share_inbox.dart';
import 'controller_test.dart' show TestStore, TestInbox;
import 'pictures_test.dart' show png;

/// A share queue whose pictures live in memory instead of private files.
class PictureInbox extends TestInbox {
  final files = <String, Uint8List>{};
  @override
  Future<Uint8List> readImage(String path) async =>
      files[path] ?? (throw StateError('missing $path'));
}

SharedLink pictureShare(
  String id,
  List<String> paths, {
  String text = '',
  String? title,
}) => SharedLink(id, text, title, [
  for (final p in paths) (path: p, mime: 'image/png', name: p.split('/').last),
]);

Future<SaveController> open(TestStore store, PictureInbox inbox) async {
  final c = SaveController(open: () async => store, shares: inbox);
  await c.initialize();
  return c;
}

void main() {
  test('shared screenshots become picture items, then the delivery is '
      'acknowledged', () async {
    final store = TestStore(), inbox = PictureInbox();
    inbox.files['/q/a.d/0'] = png(320, 640);
    inbox.files['/q/a.d/1'] = png(640, 320);
    inbox.pending = [
      pictureShare('a', ['/q/a.d/0', '/q/a.d/1']),
    ];
    final c = await open(store, inbox);
    await c.drain();
    final items = c.library!.bookmarks;
    expect(items, hasLength(2));
    expect(items.every((b) => b.kind == 'image'), isTrue);
    expect(items.every((b) => b.media != null), isTrue);
    expect(store.ownedMedia, hasLength(2));
    expect(inbox.acknowledgments, ['a']);
    expect(c.invalidShares, isEmpty);
    c.dispose();
  });

  test('a picture shared with a link keeps both', () async {
    final store = TestStore(), inbox = PictureInbox();
    inbox.files['/q/b.d/0'] = png(200, 200);
    inbox.pending = [
      pictureShare(
        'b',
        ['/q/b.d/0'],
        text: 'Xem menu https://example.com/menu',
        title: 'Quán phở',
      ),
    ];
    final c = await open(store, inbox);
    await c.drain();
    final kinds = [for (final b in c.library!.bookmarks) b.kind];
    expect(kinds, containsAll(['image', 'link']));
    expect(inbox.acknowledgments, ['b']);
    c.dispose();
  });

  test('a picture that cannot be read keeps the delivery and saves nothing '
      'from it', () async {
    final store = TestStore(), inbox = PictureInbox();
    inbox.files['/q/c.d/0'] = png(200, 200);
    inbox.files['/q/c.d/1'] = Uint8List.fromList('not a picture'.codeUnits);
    inbox.pending = [
      pictureShare('c', ['/q/c.d/0', '/q/c.d/1']),
    ];
    final c = await open(store, inbox);
    await c.drain();
    expect(c.library!.bookmarks, isEmpty);
    expect(inbox.acknowledgments, isEmpty);
    expect(inbox.pending, hasLength(1), reason: 'the queue still holds it');
    expect(c.invalidShares.single.id, 'c');
    c.dispose();
  });

  test('sharing the same screenshot twice keeps one item', () async {
    final store = TestStore(), inbox = PictureInbox();
    final bytes = png(300, 300);
    inbox.files['/q/d.d/0'] = bytes;
    inbox.files['/q/e.d/0'] = Uint8List.fromList(bytes);
    inbox.pending = [
      pictureShare('d', ['/q/d.d/0']),
      pictureShare('e', ['/q/e.d/0']),
    ];
    final c = await open(store, inbox);
    await c.drain();
    expect(c.library!.bookmarks, hasLength(1));
    expect(inbox.acknowledgments, ['d', 'e']);
    c.dispose();
  });
}
