import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

const csv =
    '''id,title,note,excerpt,url,folder,tags,created,cover,highlights,favorite
101,Bún chả Hà Nội,Thử cuối tuần,Công thức 15 phút,https://www.youtube.com/watch?v=buncha,Món ngon,"món-bắc, nhanh",2025-03-01T08:30:00.000Z,https://img.example/c.jpg,,true
102,Hội An 3 ngày,,Lịch trình,https://vnexpress.net/hoi-an,Du lịch/Hội An,,2025-04-02T10:00:00.000Z,,"Đi sớm để tránh đông",false
103,Inbox thing,,,https://example.com/a,Unsorted,,2025-05-03T00:00:00.000Z,,,false
104,Bad,,,not a url,Món ngon,,,,,false
''';

void main() {
  test('a Raindrop CSV keeps folders, tags, notes, excerpts, dates and '
      'favourites', () {
    final p = SavePortable.previewRaindrop(bytes(csv));
    expect(p.validCount, 3);
    expect(p.invalidCount, 1);
    final l = p.library;
    final names = {for (final c in l.collections) c.id: c};
    final food = l.collections.firstWhere((c) => c.name == 'Món ngon');
    final trips = l.collections.firstWhere((c) => c.name == 'Du lịch');
    final hoiAn = l.collections.firstWhere((c) => c.name == 'Hội An');
    expect(hoiAn.parentId, trips.id);
    expect(names, hasLength(3));

    final bun = l.bookmarks.firstWhere((b) => b.title == 'Bún chả Hà Nội');
    expect(bun.collectionId, food.id);
    expect(bun.tags, ['món-bắc', 'nhanh']);
    expect(bun.note, 'Thử cuối tuần');
    expect(bun.description, 'Công thức 15 phút');
    expect(bun.isFavorite, isTrue);
    expect(bun.savedAt, '2025-03-01T08:30:00.000Z');
    expect(bun.thumbnailUrl, isNull, reason: 'covers are never fetched');

    final hoi = l.bookmarks.firstWhere((b) => b.title == 'Hội An 3 ngày');
    expect(hoi.collectionId, hoiAn.id);
    expect(hoi.note, 'Đi sớm để tránh đông');

    final inbox = l.bookmarks.firstWhere((b) => b.title == 'Inbox thing');
    expect(inbox.collectionId, isNull, reason: 'Unsorted is Not sorted');
  });

  test('merging adds only what is new and keeps the library', () {
    final first = SavePortable.previewRaindrop(bytes(csv));
    final library = first.commit(SaveLibrary());
    final again = SavePortable.previewRaindrop(bytes(csv), current: library);
    expect(again.duplicateCount, 3);
    expect(again.fresh(library), isEmpty);
  });

  test('a Raindrop HTML export reads like browser bookmarks', () {
    const html = '''<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
<DT><H3>Món ngon</H3>
<DL><p>
<DT><A HREF="https://www.youtube.com/watch?v=pho" ADD_DATE="1700000000" TAGS="phở">Phở bò</A>
</DL><p>
</DL><p>''';
    final p = SavePortable.previewRaindrop(bytes(html));
    expect(p.validCount, 1);
    expect(p.library.collections.single.name, 'Món ngon');
  });

  test('other CSV files are refused with a clear reason', () {
    expect(
      () => SavePortable.previewRaindrop(bytes('title,url\nA,https://a.com')),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Raindrop'),
        ),
      ),
    );
  });
}
