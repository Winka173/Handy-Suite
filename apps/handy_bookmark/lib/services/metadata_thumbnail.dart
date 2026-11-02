import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as image;
import 'metadata_types.dart';

class _ThumbnailFailure implements Exception {
  const _ThumbnailFailure(this.code);
  final String code;
}

/// Validates and sanitizes encoded pixels without performing any network I/O.
/// Exposed for deterministic verification of the thumbnail safety boundary.
ThumbnailResult sanitizeThumbnail(
  Uint8List bytes, {
  String? contentType,
  CancellationToken? cancellation,
}) {
  try {
    cancellation?.check();
    if (bytes.length > metadataMaxThumbnailBytes) {
      throw const _ThumbnailFailure('responseTooLarge');
    }
    // Only these bounded static raster formats are accepted. SVG is active
    // content and animated images can cause disproportionate allocations.
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final isWebp =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
    final actualMime = isPng
        ? 'image/png'
        : isJpeg
        ? 'image/jpeg'
        : isWebp
        ? 'image/webp'
        : null;
    if (actualMime == null ||
        (contentType != null && actualMime != contentType)) {
      throw const _ThumbnailFailure('invalidImage');
    }
    final image.Decoder decoder = isPng
        ? image.PngDecoder(maxPixels: metadataMaxImagePixels)
        : isJpeg
        ? image.JpegDecoder(maxPixels: metadataMaxImagePixels)
        : (image.WebPDecoder()..maxPixels = metadataMaxImagePixels);
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > metadataMaxImagePixels ||
        info.numFrames != 1) {
      throw const _ThumbnailFailure('imageDimensions');
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const _ThumbnailFailure('invalidImage');
    cancellation?.check();
    // Re-encode verified pixels, stripping untrusted ancillary metadata.
    final thumbnail = decoded.width <= 512 && decoded.height <= 512
        ? decoded
        : image.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 512 : null,
            height: decoded.height > decoded.width ? 512 : null,
          );
    final encoded = Uint8List.fromList(image.encodeJpg(thumbnail, quality: 80));
    if (encoded.length > metadataMaxThumbnailBytes) {
      throw const _ThumbnailFailure('responseTooLarge');
    }
    return ThumbnailResult(bytes: encoded, contentType: 'image/jpeg');
  } catch (error) {
    return ThumbnailResult(
      errorCode: switch (error) {
        _ThumbnailFailure(:final code) => code,
        Cancelled() => 'cancelled',
        _ => 'invalidImage',
      },
    );
  }
}
