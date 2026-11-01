import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_media_engine/src/exif.dart';
import 'package:image/image.dart' as img;
import 'images_test.dart' show fixture, chunk;

Uint8List tiff([Endian endian = Endian.little]) {
  final bytes = Uint8List(158), data = ByteData.sublistView(bytes);
  bytes[0] = bytes[1] = endian == Endian.little ? 73 : 77;
  void u16(int at, int value) => data.setUint16(at, value, endian);
  void u32(int at, int value) => data.setUint32(at, value, endian);
  void entry(int at, int id, int type, int count, int value) {
    u16(at, id);
    u16(at + 2, type);
    u32(at + 4, count);
    u32(at + 8, value);
  }

  u16(2, 42);
  u32(4, 8);
  u16(8, 3);
  entry(10, 0x10f, 2, 6, 50);
  entry(22, 0x112, 3, 1, 0);
  u16(30, 1);
  entry(34, 0x8825, 4, 1, 56);
  bytes.setRange(50, 56, [72, 97, 110, 100, 121, 0]);
  u16(56, 4);
  entry(58, 1, 2, 2, 0);
  bytes[66] = 83;
  entry(70, 2, 5, 3, 110);
  entry(82, 3, 2, 2, 0);
  bytes[90] = 69;
  entry(94, 4, 5, 3, 134);
  for (var i = 0; i < 3; i++) {
    u32(110 + i * 8, [10, 30, 0][i]);
    u32(114 + i * 8, 1);
    u32(134 + i * 8, [106, 40, 30][i]);
    u32(138 + i * 8, 1);
  }
  return bytes;
}

Uint8List pngWithExif(Uint8List exif) {
  final png = fixture();
  return Uint8List.fromList([
    ...png.sublist(0, png.length - 12),
    ...chunk('eXIf', exif),
    ...png.sublist(png.length - 12),
  ]);
}

void main() {
  for (final endian in [Endian.little, Endian.big]) {
    test(
      'TIFF ${endian == Endian.little ? 'II' : 'MM'} reads Make/orientation and signed GPS',
      () {
        final result = inspectExifTiff(tiff(endian));
        expect(result.tags['IFD0.Make'], 'Handy');
        expect(result.tags['IFD0.Orientation'], '1');
        expect(result.latitude, closeTo(-10.5, 1e-8));
        expect(result.longitude, closeTo(106.675, 1e-8));
        expect(result.hasGps, isTrue);
      },
    );
  }
  test(
    'PNG EXIF/GPS view then remove retains original PNG bytes and no location tags',
    () {
      final original = fixture(),
          png = pngWithExif(tiff()),
          view = inspectImageMetadata(png);
      expect(view.hasExif, isTrue);
      expect(view.gpsPossible, isTrue);
      expect(view.latitude, -10.5);
      expect(view.tags['GPS.LatitudeRef'], 'S');
      final clean = stripImageMetadata(png);
      expect(clean, original);
      expect(inspectImageMetadata(clean).tags, isEmpty);
      expect(inspectImageMetadata(clean).latitude, isNull);
    },
  );
  test(
    'JPEG EXIF/GPS view then removal preserves original compressed image bytes',
    () {
      final original = img.encodeJpg(mediaBitmap(fixture())),
          exif = tiff(),
          length = exif.length + 8;
      final jpeg = Uint8List.fromList([
            255,
            216,
            255,
            225,
            length >> 8,
            length & 255,
            69,
            120,
            105,
            102,
            0,
            0,
            ...exif,
            ...original.sublist(2),
          ]),
          view = inspectImageMetadata(jpeg);
      expect(view.hasExif, isTrue);
      expect(view.longitude, closeTo(106.675, 1e-8));
      expect(view.tags['IFD0.Make'], 'Handy');
      expect(stripImageMetadata(jpeg), original);
    },
  );
  test(
    'TIFF rejects loops, out-of-range pointers, count bombs and zero denominator',
    () {
      final loop = tiff();
      ByteData.sublistView(loop).setUint32(46, 8, Endian.little);
      expect(() => inspectExifTiff(loop), throwsFormatException);
      final outside = tiff();
      ByteData.sublistView(outside).setUint32(18, 999999, Endian.little);
      expect(() => inspectExifTiff(outside), throwsFormatException);
      final count = tiff();
      ByteData.sublistView(count).setUint32(14, 0xffffffff, Endian.little);
      expect(() => inspectExifTiff(count), throwsFormatException);
      final zero = tiff();
      ByteData.sublistView(zero).setUint32(114, 0, Endian.little);
      expect(() => inspectExifTiff(zero), throwsFormatException);
      final duplicate = tiff();
      ByteData.sublistView(duplicate).setUint16(22, 0x10f, Endian.little);
      expect(() => inspectExifTiff(duplicate), throwsFormatException);
    },
  );
  test('unreadable EXIF is reported and can still be safely removed', () {
    final png = pngWithExif(
          Uint8List.fromList([73, 73, 42, 0, 255, 255, 255, 255]),
        ),
        view = inspectImageMetadata(png);
    expect(view.hasExif, isTrue);
    expect(view.warnings, isNotEmpty);
    expect(view.latitude, isNull);
    expect(stripImageMetadata(png), fixture());
  });
}
