import 'dart:math' as math;
import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:image/image.dart' as img;

class ImageRegion {
  final double x, y, width, height;
  const ImageRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  void validate() {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1.000000001 ||
        y + height > 1.000000001)
      throw const FormatException('Crop region must be inside the image');
  }
}

ImageRegion cropAspectPreset(
  int imageWidth,
  int imageHeight,
  double targetAspect,
) {
  if (imageWidth < 1 ||
      imageHeight < 1 ||
      imageWidth > 16384 ||
      imageHeight > 16384 ||
      imageWidth * imageHeight > 16000000 ||
      !targetAspect.isFinite ||
      targetAspect < .001 ||
      targetAspect > 1000)
    throw const FormatException('Invalid image dimensions or crop aspect');
  final width = math
      .min(imageWidth, (imageHeight * targetAspect).round())
      .clamp(1, imageWidth);
  final height = (width / targetAspect).round().clamp(1, imageHeight);
  return ImageRegion(
    x: ((imageWidth - width) ~/ 2) / imageWidth,
    y: ((imageHeight - height) ~/ 2) / imageHeight,
    width: width / imageWidth,
    height: height / imageHeight,
  );
}

img.Image mediaBitmap(Uint8List bytes) {
  final decoded = decodeBoundedImage(bytes, allowWebP: true);
  return img.Image.fromBytes(
    width: decoded.width,
    height: decoded.height,
    bytes: decoded.rgba.buffer,
    numChannels: 4,
  );
}

Uint8List mediaPng(img.Image image) {
  if (image.width < 1 ||
      image.height < 1 ||
      image.width > 16384 ||
      image.height > 16384 ||
      image.width * image.height > 16000000)
    throw const FormatException('Image exceeds 16 million pixels');
  final encoded = img.encodePng(image);
  if (encoded.length > 20000000)
    throw const FormatException('Output exceeds 20 MB');
  return encoded;
}

Future<void> _checkpoint(CancellationToken? cancellation) async {
  cancellation?.check();
  await Future<void>.delayed(Duration.zero);
  cancellation?.check();
}

Future<Uint8List> cropImage(
  Uint8List bytes,
  ImageRegion region, {
  CancellationToken? cancellation,
}) async {
  region.validate();
  final source = Uint8List.fromList(bytes);
  await _checkpoint(cancellation);
  final image = mediaBitmap(source);
  final x = (region.x * image.width + 1e-9).floor().clamp(0, image.width - 1),
      y = (region.y * image.height + 1e-9).floor().clamp(0, image.height - 1);
  final right = ((region.x + region.width) * image.width - 1e-9).ceil().clamp(
        x + 1,
        image.width,
      ),
      bottom = ((region.y + region.height) * image.height - 1e-9).ceil().clamp(
        y + 1,
        image.height,
      );
  await _checkpoint(cancellation);
  final output = mediaPng(
    img.copyCrop(image, x: x, y: y, width: right - x, height: bottom - y),
  );
  await _checkpoint(cancellation);
  return output;
}

Future<Uint8List> resizeImage(
  Uint8List bytes, {
  required int width,
  int? height,
  CancellationToken? cancellation,
}) async {
  if (width < 1 ||
      width > 16384 ||
      (height != null && (height < 1 || height > 16384)))
    throw const FormatException('Invalid output dimensions');
  final source = Uint8List.fromList(bytes);
  await _checkpoint(cancellation);
  final image = mediaBitmap(source);
  final h = height ?? math.max(1, (image.height * width / image.width).round());
  if (width * h > 16000000)
    throw const FormatException('Resize exceeds 16 million pixels');
  await _checkpoint(cancellation);
  final output = mediaPng(
    img.copyResize(
      image,
      width: width,
      height: h,
      interpolation: img.Interpolation.average,
    ),
  );
  await _checkpoint(cancellation);
  return output;
}

Future<Uint8List> convertImage(
  Uint8List bytes, {
  String format = 'jpeg',
  int? width,
  int rotation = 0,
  bool flipHorizontal = false,
  bool flipVertical = false,
  int quality = 85,
  CancellationToken? cancellation,
}) async {
  if (!{'jpeg', 'png', 'webp'}.contains(format) ||
      !{0, 90, 180, 270}.contains(rotation) ||
      quality < 1 ||
      quality > 100 ||
      (width != null && (width < 1 || width > 16384)))
    throw const FormatException(
      'Choose PNG/JPEG/WebP, quality 1-100 and rotation 0/90/180/270',
    );
  final source = Uint8List.fromList(bytes);
  await _checkpoint(cancellation);
  var image = mediaBitmap(source);
  if (width != null && width != image.width) {
    final height = math.max(1, (width * image.height / image.width).round());
    if (height > 16384 || width * height > 16000000)
      throw const FormatException('Conversion exceeds 16 million pixels');
    image = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
  }
  await _checkpoint(cancellation);
  if (rotation != 0) image = img.copyRotate(image, angle: rotation);
  if (flipHorizontal) image = img.flipHorizontal(image);
  if (flipVertical) image = img.flipVertical(image);
  await _checkpoint(cancellation);
  final Uint8List output;
  if (format == 'png') {
    output = mediaPng(image);
  } else if (format == 'webp') {
    if (image.width * image.height > 4000000)
      throw const FormatException(
        'WebP encoding limit: 4M pixels; resize or export PNG/JPEG',
      );
    output = img.encodeWebP(
      image,
      lossless: false,
      quality: quality,
      method: 0,
      alphaQuality: 100,
      singleFrame: true,
    );
    if (output.length > 20000000)
      throw const FormatException('Output exceeds 20 MB');
  } else {
    // JPEG has no alpha. Match displayed pixels on an explicit white canvas.
    final opaque = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(opaque, image);
    output = img.encodeJpg(opaque, quality: quality);
    if (output.length > 20000000)
      throw const FormatException('Output exceeds 20 MB');
  }
  await _checkpoint(cancellation);
  final reopened = decodeBoundedImage(output, allowWebP: true);
  if (reopened.width != image.width || reopened.height != image.height)
    throw const FormatException('Converted image verification failed');
  return output;
}

class WatermarkSpec {
  final String? text;
  final Uint8List? _logo;
  Uint8List? get logo => _logo == null ? null : Uint8List.fromList(_logo);
  final double opacity, relativeWidth;
  final String position;
  WatermarkSpec.text(
    String value, {
    this.opacity = 0.6,
    this.position = 'bottom-right',
    this.relativeWidth = 0.3,
  }) : text = value,
       _logo = null;
  WatermarkSpec.logo(
    Uint8List bytes, {
    this.opacity = 0.6,
    this.position = 'bottom-right',
    this.relativeWidth = 0.2,
  }) : text = null,
       _logo = Uint8List.fromList(bytes);
  void validate() {
    if (!opacity.isFinite ||
        opacity <= 0 ||
        opacity > 1 ||
        !relativeWidth.isFinite ||
        relativeWidth < 0.05 ||
        relativeWidth > 0.9 ||
        ![
          'top-left',
          'top-right',
          'center',
          'bottom-left',
          'bottom-right',
        ].contains(position))
      throw const FormatException('Invalid watermark options');
    if (text != null &&
        (text!.isEmpty ||
            text!.length > 100 ||
            text!.runes.any((r) => r < 32 || r > 126)))
      throw const FormatException(
        'Text watermark supports 1–100 printable ASCII characters; use a PNG logo for other scripts',
      );
  }
}

Future<Uint8List> watermarkImage(
  Uint8List bytes,
  WatermarkSpec spec, {
  CancellationToken? cancellation,
}) async {
  spec.validate();
  final source = Uint8List.fromList(bytes);
  await _checkpoint(cancellation);
  final image = mediaBitmap(source);
  final target = math.max(1, (image.width * spec.relativeWidth).round());
  img.Image mark;
  if (spec.text != null) {
    final text = spec.text!, naturalWidth = text.length * 24;
    mark = img.Image(
      width: math.max(1, naturalWidth),
      height: 48,
      numChannels: 4,
    );
    img.drawString(
      mark,
      text,
      font: img.arial24,
      x: 0,
      y: 0,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
  } else {
    mark = mediaBitmap(spec._logo!);
  }
  final w = math.min(target, image.width),
      h = math.max(1, (mark.height * w / mark.width).round());
  final scale = math.min(1, image.height / h),
      finalW = math.max(1, (w * scale).round()),
      finalH = math.max(1, (h * scale).round());
  mark = img.copyResize(mark, width: finalW, height: finalH);
  final margin = math.min(
        12,
        math.min(image.width - finalW, image.height - finalH),
      ),
      centered = spec.position == 'center';
  final x = centered
      ? (image.width - finalW) ~/ 2
      : spec.position.endsWith('right')
      ? image.width - finalW - margin
      : margin;
  final y = centered
      ? (image.height - finalH) ~/ 2
      : spec.position.startsWith('top')
      ? margin
      : image.height - finalH - margin;
  for (var row = 0; row < mark.height; row++) {
    if (row % 32 == 0) await _checkpoint(cancellation);
    for (var col = 0; col < mark.width; col++) {
      final source = mark.getPixel(col, row),
          dest = image.getPixel(x + col, y + row),
          a = source.aNormalized * spec.opacity,
          da = dest.aNormalized,
          oa = a + da * (1 - a);
      if (oa == 0) continue;
      double blend(num s, num d) => (s * a + d * da * (1 - a)) / oa;
      dest.setRgba(
        blend(source.r, dest.r),
        blend(source.g, dest.g),
        blend(source.b, dest.b),
        oa * 255,
      );
    }
  }
  final output = mediaPng(image);
  await _checkpoint(cancellation);
  return output;
}

class WatermarkResult {
  final int index;
  final Uint8List? bytes;
  final String? error;
  const WatermarkResult(this.index, this.bytes, this.error);
}

Future<List<WatermarkResult>> watermarkBatch(
  List<Uint8List> inputs,
  WatermarkSpec spec, {
  CancellationToken? cancellation,
  void Function(int, int)? onProgress,
}) async {
  spec.validate();
  if (inputs.isEmpty ||
      inputs.length > 50 ||
      inputs.fold<int>(0, (n, b) => n + b.length) > 60000000)
    throw const FormatException('Batch limit: 50 images / 60 MB');
  final sources = [for (final input in inputs) Uint8List.fromList(input)],
      results = <WatermarkResult>[];
  var totalOutput = 0;
  for (var i = 0; i < sources.length; i++) {
    cancellation?.check();
    try {
      final bytes = await watermarkImage(
        sources[i],
        spec,
        cancellation: cancellation,
      );
      totalOutput += bytes.length;
      if (totalOutput > 60000000)
        throw const FormatException('Batch output exceeds 60 MB');
      results.add(WatermarkResult(i, bytes, null));
    } on Cancelled {
      rethrow;
    } on FormatException catch (e) {
      results.add(WatermarkResult(i, null, e.message));
    } on Object {
      results.add(WatermarkResult(i, null, 'Image processing failed'));
    }
    onProgress?.call(i + 1, sources.length);
  }
  return List.unmodifiable(results);
}
