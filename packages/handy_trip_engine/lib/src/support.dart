part of '../handy_trip_engine.dart';

class CapturedLocation {
  final Geo geo;
  final double accuracy;
  final DateTime at;
  CapturedLocation(this.geo, this.accuracy, this.at) {
    if (!accuracy.isFinite || accuracy < 0 || accuracy > 1000000)
      throw const FormatException('Invalid location accuracy');
  }
  bool requiresCaution(DateTime now) =>
      accuracy > 100 ||
      now.toUtc().difference(at.toUtc()).abs() > const Duration(minutes: 2);
}

abstract interface class MapProvider {
  bool get hasBasemap;
  Uri navigation(Place place);
}

class NoBasemap implements MapProvider {
  @override
  bool get hasBasemap => false;
  @override
  Uri navigation(Place place) {
    final geo = place.geo,
        query = geo != null ? '${geo.lat},${geo.lon}' : place.address.trim();
    if (query.isEmpty)
      throw const FormatException(
        'Enter coordinates or an explicit address first',
      );
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }
}

class PreparedAsset {
  final MediaAsset asset;
  final Uint8List original, preview;
  PreparedAsset(this.asset, this.original, this.preview);
}

PreparedAsset prepareAsset(
  String name,
  Uint8List bytes, {
  String caption = '',
}) {
  if (bytes.isEmpty || bytes.length > 12000000)
    throw const FormatException('Attachment must be 1 byte to 12 MB');
  final key = newId();
  if (bytes.length >= 5 &&
      ascii.decode(bytes.sublist(0, 5), allowInvalid: true) == '%PDF-') {
    if (!utf8
        .decode(
          bytes.sublist(max(0, bytes.length - 2048)),
          allowMalformed: true,
        )
        .contains('%%EOF'))
      throw const FormatException('Incomplete PDF');
    return PreparedAsset(
      MediaAsset({
        'id': key,
        'path': 'assets/$key.pdf',
        'name': name,
        'caption': caption,
        'mime': 'application/pdf',
        'size': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
      }),
      Uint8List.fromList(bytes).asUnmodifiableView(),
      Uint8List(0),
    );
  }
  final decoder = img.findDecoderForData(bytes),
      info = decoder?.startDecode(bytes);
  if (info == null ||
      info.numFrames != 1 ||
      info.width * info.height > 16000000 ||
      info.width < 1 ||
      info.height < 1)
    throw const FormatException('Unsupported/corrupt image or over 16 MP');
  final picture = img.decodeImage(bytes);
  if (picture == null) throw const FormatException('Could not decode image');
  final oriented = img.bakeOrientation(picture),
      clean = img.Image(
        width: oriented.width,
        height: oriented.height,
        numChannels: 3,
      );
  img.fill(clean, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(clean, oriented);
  final thumb = clean.width > 1280 || clean.height > 1280
      ? img.copyResize(
          clean,
          width: clean.width >= clean.height ? 1280 : null,
          height: clean.height > clean.width ? 1280 : null,
        )
      : clean;
  final preview = Uint8List.fromList(img.encodeJpg(thumb, quality: 86));
  final format = decoder!.format.name, ext = format == 'jpeg' ? 'jpg' : format;
  if (!['jpg', 'png', 'webp'].contains(ext))
    throw const FormatException('Use JPEG, PNG or WebP');
  return PreparedAsset(
    MediaAsset({
      'id': key,
      'path': 'assets/$key.$ext',
      'name': name,
      'caption': caption,
      'mime': ext == 'jpg' ? 'image/jpeg' : 'image/$ext',
      'size': bytes.length,
      'width': picture.width,
      'height': picture.height,
      'sha256': sha256.convert(bytes).toString(),
    }),
    Uint8List.fromList(bytes).asUnmodifiableView(),
    preview.asUnmodifiableView(),
  );
}

Uint8List publicImage(Uint8List original) =>
    prepareAsset('photo', original).preview;
