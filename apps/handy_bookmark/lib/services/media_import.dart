import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:image/image.dart' as img;

/// A picture ready to store: its record, the original bytes exactly as
/// given (the person's own file, never re-encoded), and a small preview.
class PreparedPicture {
  final MediaRef ref;
  final Uint8List original, preview;
  const PreparedPicture(this.ref, this.original, this.preview);
}

/// Pictures larger than this many pixels are refused before decoding, so a
/// tiny file that claims huge dimensions cannot exhaust memory.
const maxPicturePixels = 50 * 1000 * 1000;

/// The longest edge of a preview.
const previewEdge = 640;

String? pictureMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF)
    return 'image/jpeg';
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47 &&
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A)
    return 'image/png';
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP')
    return 'image/webp';
  return null;
}

/// Checks and prepares [bytes] (run it on a background isolate). Throws a
/// FormatException with a bilingual message for anything unusable.
PreparedPicture preparePicture(Uint8List bytes, {String name = ''}) {
  if (bytes.isEmpty) throw const FormatException('Empty file / Tệp trống');
  if (bytes.length > MediaRef.maxBytes)
    throw const FormatException('Pictures up to 25 MB / Ảnh tối đa 25 MB');
  final mime = pictureMime(bytes);
  final decoder = switch (mime) {
    'image/jpeg' => img.JpegDecoder(),
    'image/png' => img.PngDecoder(),
    'image/webp' => img.WebPDecoder(),
    _ => null,
  };
  if (decoder == null)
    throw const FormatException(
      'Use a JPEG, PNG or WebP picture / Dùng ảnh JPEG, PNG hoặc WebP',
    );
  const broken = FormatException(
    'This picture is damaged or too large / Ảnh hỏng hoặc quá lớn',
  );
  // The decoder's own refusals (bad headers, its pixel cap) become ours.
  img.DecodeInfo? info;
  try {
    info = decoder.startDecode(bytes);
  } catch (_) {
    throw broken;
  }
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width > 20000 ||
      info.height > 20000 ||
      info.width * info.height > maxPicturePixels)
    throw const FormatException(
      'This picture is damaged or too large / Ảnh hỏng hoặc quá lớn',
    );
  img.Image? decoded;
  try {
    decoded = decoder.decode(bytes, frame: 0);
  } catch (_) {
    throw broken;
  }
  if (decoded == null)
    throw const FormatException('This picture is damaged / Ảnh bị hỏng');
  // Turn it the way the camera meant, for the preview and the size shown.
  final upright = img.bakeOrientation(decoded);
  final scale =
      previewEdge /
      (upright.width > upright.height ? upright.width : upright.height);
  final small = scale < 1
      ? img.copyResize(
          upright,
          width: (upright.width * scale).round().clamp(1, previewEdge),
          height: (upright.height * scale).round().clamp(1, previewEdge),
          interpolation: img.Interpolation.average,
        )
      : upright;
  // JPEG has no transparency: put see-through pictures on white once.
  final flat = small.hasAlpha ? _onWhite(small) : small;
  // The preview is what leaves the device in a shared page: no camera,
  // place or time data rides along (the original keeps its own bytes).
  flat.exif = img.ExifData();
  var quality = 82;
  var preview = img.encodeJpg(flat, quality: quality);
  while (preview.length > 600 * 1024 && quality > 40) {
    quality -= 12;
    preview = img.encodeJpg(flat, quality: quality);
  }
  return PreparedPicture(
    MediaRef(
      id: sha256.convert(bytes).toString(),
      mime: mime!,
      width: upright.width,
      height: upright.height,
      bytes: bytes.length,
      name: _cleanName(name),
    ),
    bytes,
    Uint8List.fromList(preview),
  );
}

img.Image _onWhite(img.Image source) {
  final out = img.Image(width: source.width, height: source.height);
  img.fill(out, color: img.ColorRgb8(255, 255, 255));
  return img.compositeImage(out, source);
}

String _cleanName(String name) {
  final base = name.split(RegExp(r'[\\/]')).last.trim();
  return base.length > 255 ? base.substring(0, 255) : base;
}

/// A title worth keeping from a file name; camera and screenshot names
/// ("IMG_2041.jpg", "Screenshot_20261106-0912.png") give none.
String pictureTitle(String name) {
  final base = _cleanName(
    name,
  ).replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '');
  if (base.isEmpty ||
      RegExp(
        r'^(img|dsc|dcim|pxl|mvimg|screenshot|screen shot|ảnh chụp màn hình|photo|image|pic|wp|signal|zalo|fb|received)[-_ ]?[\d(_-]',
        caseSensitive: false,
      ).hasMatch(base) ||
      RegExp(r'^[\d_ -]+$').hasMatch(base))
    return '';
  return base.length > 200 ? base.substring(0, 200) : base;
}
