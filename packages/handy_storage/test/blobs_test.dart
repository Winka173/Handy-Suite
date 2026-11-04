import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/blobs.dart';
import 'package:handy_storage/src/blobs_io.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('blobs'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('bytes come back as written, listed by id, and go on delete', () async {
    final b = FileBlobs('handy-keep', directory: dir);
    final photo = Uint8List.fromList(List.generate(5000, (i) => i % 251));
    await b.write('file:///handy-assets/a.png', photo);
    await b.write('file:///handy-assets/b.jpg', Uint8List.fromList([1, 2]));
    expect(await b.read('file:///handy-assets/a.png'), photo);
    expect(await b.ids(), {
      'file:///handy-assets/a.png',
      'file:///handy-assets/b.jpg',
    });
    await b.delete('file:///handy-assets/b.jpg');
    expect(await b.read('file:///handy-assets/b.jpg'), isNull);
    expect(await b.ids(), {'file:///handy-assets/a.png'});
  });

  test('a damaged entry is refused, not returned', () async {
    final b = FileBlobs('handy-keep', directory: dir);
    await b.write('x', Uint8List.fromList(List.filled(100, 7)));
    final f = Directory('${dir.path}/handy-keep-blobs').listSync().single;
    final data = (f as File).readAsBytesSync();
    data[data.length - 1] ^= 1;
    f.writeAsBytesSync(data);
    expect(() => b.read('x'), throwsFormatException);
    expect(await b.ids(), isEmpty);
  });

  test('ids that could be paths are refused', () {
    expect(() => MemoryBlobs().write('', Uint8List(1)), throwsArgumentError);
    expect(() => localBlobs('not-handy'), throwsArgumentError);
  });
}
