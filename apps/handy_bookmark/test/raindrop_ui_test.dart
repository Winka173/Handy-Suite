import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'widget_test.dart' show tapKey;

const csv =
    'id,title,note,excerpt,url,folder,tags,created,cover,highlights,favorite\n'
    '1,Phở Thìn,,Phở bò tái lăn,https://maps.example/pho-thin,Món ngon/Hà Nội,phở,2025-01-02T03:04:05.000Z,,,true\n'
    '2,Đọc sau,,,https://example.org/article,Unsorted,,2025-01-03T03:04:05.000Z,,,false\n';

void main() {
  testWidgets('Raindrop: preview, then folders arrive as nested collections '
      'with Undo', (t) async {
    final files = OneFile()
      ..next = ImportedBytes(
        'raindrop.csv',
        Uint8List.fromList(utf8.encode(csv)),
      );
    final (c, _) = await boot(t, size: const Size(1440, 900), files: files);
    await tapKey(t, 'open-settings');
    await tapKey(t, 'set-advanced-data');
    await tapKey(t, 'save-import-raindrop');
    await settle(t, 300);
    expect(find.text('Bring in 2 links from Raindrop?'), findsOneWidget);
    await t.tap(find.byKey(const Key('raindrop-add')));
    await settle(t);
    final l = c.library!;
    expect(l.bookmarks, hasLength(5));
    final city = l.collections.firstWhere((x) => x.name == 'Hà Nội');
    final food = l.collections.firstWhere((x) => x.name == 'Món ngon');
    expect(city.parentId, food.id);
    final pho = l.bookmarks.firstWhere((b) => b.title == 'Phở Thìn');
    expect(pho.collectionId, city.id);
    expect(pho.isFavorite, isTrue);
    expect(pho.tags, ['phở']);
    expect(find.text('2 links added from Raindrop.'), findsOneWidget);
  });
}
