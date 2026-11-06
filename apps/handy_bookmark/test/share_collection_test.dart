import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/collections/share_collection.dart';
import 'package:handy_bookmark/services/media_import.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:image/image.dart' as img;
import 'new_flows_test.dart' show OneFile, boot, settle;
import 'widget_test.dart' show tapKey;
import 'package:handy_files/handy_files.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'package:handy_bookmark/scope.dart';
import 'package:handy_bookmark/services/reminders.dart';
import 'package:handy_bookmark/view/library_view.dart';

/// A phone photo that says where and with what it was taken.
Uint8List placedPhoto() {
  final image = img.Image(width: 1200, height: 900);
  img.fill(image, color: img.ColorRgb8(30, 90, 140));
  image.exif.imageIfd['Make'] = img.IfdValueAscii('PhoneMaker');
  image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
  image.exif.imageIfd.orientation = 6;
  return img.encodeJpg(image);
}

bool carriesMetadata(Uint8List jpeg) {
  final e = img.decodeJpg(jpeg)!.exif;
  return e.imageIfd.containsKey(0x010F) || e.gpsIfd.values.isNotEmpty;
}

void main() {
  test('the source photo really carries camera and place data', () {
    expect(carriesMetadata(placedPhoto()), isTrue);
  });

  test('a picture leaving in a page is upright, small and has no metadata', () {
    final out = sharablePicture(placedPhoto())!;
    expect(carriesMetadata(out), isFalse);
    final d = img.decodeJpg(out)!;
    expect((d.width, d.height), (360, 480), reason: 'turned upright, 480 max');
    expect(sharablePicture(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('stored previews carry no metadata either', () {
    final p = preparePicture(placedPhoto(), name: 'IMG_1.jpg');
    expect(carriesMetadata(p.preview), isFalse);
    expect(p.original, isNotEmpty, reason: 'the original stays as it was');
  });

  testWidgets('Share as a page builds one file from the collection only', (
    t,
  ) async {
    final files = OneFile()
      ..next = ImportedBytes('Quán phở.jpg', placedPhoto());
    final (c, _) = await boot(t, files: files);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-photo');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(t);
    await c.update(
      (l) => l.copyWith(
        collections: [SaveCollection(id: 'food', name: 'Món ngon')],
        bookmarks: [
          for (final b in l.bookmarks)
            b.isImage || b.originalUrl == 'https://a.com/one'
                ? b.copyWith(collectionId: 'food')
                : b,
        ],
      ),
    );
    final view = LibraryView(c);
    addTearDown(view.dispose);
    final scope = SaveScope(
      c: c,
      view: view,
      files: OneFile(),
      reminders: SaveReminders(),
      tasks: LinkTasks(c),
    );
    final page = (await t.runAsync(() => scope.sharedPage('food')))!;
    expect(page, contains('<title>Món ngon</title>'));
    expect(page, contains('a.com/one'));
    expect(page, isNot(contains('b.org/two')));
    expect(page, contains('data:image/jpeg;base64,'));
    expect(page, isNot(contains('PhoneMaker')));
  });
}
