import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'domain_test.dart' show fixture;

void main() {
  test(
    'album strips actual EXIF, private names and captions; private backup retains originals',
    () {
      final image = img.Image(width: 24, height: 16);
      image.exif.imageIfd['Artist'] = 'PRIVATE-ARTIST';
      image.exif.imageIfd['ImageDescription'] = 'PRIVATE-GPS-LOCATION';
      image.exif.gpsIfd.gpsLatitudeRef = 'N';
      image.exif.gpsIfd.gpsLatitude = 10.78;
      image.exif.gpsIfd.gpsLongitudeRef = 'E';
      image.exif.gpsIfd.gpsLongitude = 106.7;
      final original = Uint8List.fromList(img.encodeJpg(image));
      expect(img.decodeJpg(original)!.exif.gpsIfd.hasGPSLatitude, isTrue);
      expect(
        img.decodeJpg(original)!.exif.imageIfd.containsKey(0x013b),
        isTrue,
      );
      final prepared = prepareAsset(
        'PRIVATE-BOOKING.jpg',
        original,
        caption: 'PRIVATE-CAPTION',
      );
      var s = addPreparedAsset(fixture(), prepared);
      s = s.put(
        'notes',
        JournalNote({
          'id': 'note',
          'trip': 't',
          'at': '2026-03-08T01:00:00Z',
          'zone': 'UTC',
          'title': 'PRIVATE-TITLE',
          'body': 'PRIVATE-NOTE',
          'assets': [prepared.asset.key],
        }),
      );
      final album = ZipDecoder().decodeBytes(photoAlbum(s));
      final jpg = album.files.firstWhere((f) => f.name.endsWith('.jpg'));
      final decoded = img.decodeJpg(Uint8List.fromList(jpg.content));
      expect(decoded!.exif.imageIfd.containsKey(0x013b), isFalse);
      expect(decoded.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(decoded.exif.gpsIfd.hasGPSLongitude, isFalse);
      expect(album.files.map((f) => f.name).join(), isNot(contains('PRIVATE')));
      expect(
        utf8.decode(album.findFile('manifest.json')!.content),
        isNot(contains('PRIVATE-CAPTION')),
      );
      expect(jsonEncode(journalDocument(s)), isNot(contains('PRIVATE-NOTE')));
      expect(
        jsonEncode(journalDocument(s, privateText: true)),
        contains('PRIVATE-NOTE'),
      );
      expect(readBackup(fullBackup(s)).files[prepared.asset.path], original);
    },
  );
}
