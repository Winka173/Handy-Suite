import 'dart:typed_data';

/// Where a mark sits on a page, as fractions of the page as it is shown
/// (after its rotation), measured from the top-left corner.
class PdfBox {
  final double left, top, width, height;
  const PdfBox(this.left, this.top, this.width, this.height);

  bool get valid =>
      [left, top, width, height].every((v) => v.isFinite) &&
      width > 0.002 &&
      height > 0.002 &&
      left >= -0.001 &&
      top >= -0.001 &&
      left + width <= 1.001 &&
      top + height <= 1.001;

  @override
  String toString() => 'PdfBox($left, $top, $width, $height)';
}

/// Something drawn onto a page of a new copy: a picture or a line of text.
sealed class PdfStamp {
  final int page;
  final PdfBox box;
  const PdfStamp(this.page, this.box);
}

/// A picture (a signature, a seal) in straight, non-premultiplied RGBA
/// pixels. Transparent pixels stay transparent in the PDF.
class PdfImageStamp extends PdfStamp {
  final Uint8List rgba;
  final int pixelWidth, pixelHeight;
  const PdfImageStamp(
    super.page,
    super.box, {
    required this.rgba,
    required this.pixelWidth,
    required this.pixelHeight,
  });
}

/// One line of text. Its size follows the box height; the box width is a
/// guide only, unless [fit] stretches or squeezes the line to fill it.
/// [invisible] text can be found and copied but is never drawn: the hidden
/// layer that makes a scanned page searchable.
class PdfTextStamp extends PdfStamp {
  final String text;

  /// 0xAARRGGBB.
  final int color;
  final bool invisible, fit;
  const PdfTextStamp(
    super.page,
    super.box,
    this.text, {
    this.color = 0xFF1A1A1A,
    this.invisible = false,
    this.fit = false,
  });
}

/// The font size, in points, of text set in a box [boxHeight] points tall,
/// and where its baseline sits above the box's foot. Shared with the page
/// preview so the copy matches what was placed.
const textLineHeight = 1.25, textBaseline = 0.216;

const maxStamps = 200, maxStampPixels = 4000000, maxStampText = 300;

/// Refuses stamps that cannot be drawn faithfully before any work starts.
void validateStamps(List<PdfStamp> stamps, int pages) {
  if (stamps.isEmpty || stamps.length > maxStamps) {
    throw const FormatException('Place 1–200 marks on the pages');
  }
  var pixels = 0;
  for (final s in stamps) {
    if (s.page < 0 || s.page >= pages || !s.box.valid) {
      throw const FormatException('A mark lies outside its page');
    }
    switch (s) {
      case PdfImageStamp(:final rgba, :final pixelWidth, :final pixelHeight):
        pixels += pixelWidth * pixelHeight;
        if (pixelWidth < 1 ||
            pixelHeight < 1 ||
            pixelWidth > 4000 ||
            pixelHeight > 4000 ||
            rgba.length != pixelWidth * pixelHeight * 4 ||
            pixels > maxStampPixels) {
          throw const FormatException(
            'Pictures on the pages are limited to 4 million pixels',
          );
        }
      case PdfTextStamp(:final text):
        if (text.trim().isEmpty ||
            text.length > maxStampText ||
            RegExp(r'[\x00-\x1f\x7f]').hasMatch(text)) {
          throw const FormatException(
            'Text on a page is one line of up to 300 characters',
          );
        }
    }
  }
}

/// The matrix (a, b, c, d, e, f) that maps a point on the page as shown, in
/// points with y up from its bottom-left corner, to the page's own PDF space,
/// whose visible area is [left, bottom, right, top] before a clockwise
/// [rotation] of 0, 90, 180 or 270 degrees.
List<double> shownToPdf(
  int rotation,
  double left,
  double bottom,
  double right,
  double top,
) => switch (rotation % 360) {
  90 => [0, 1, -1, 0, right, bottom],
  180 => [-1, 0, 0, -1, right, top],
  270 => [0, -1, 1, 0, left, top],
  _ => [1, 0, 0, 1, left, bottom],
};

/// The size of the page as shown, for a visible area [width] by [height]
/// points before rotation.
(double, double) shownSize(int rotation, double width, double height) =>
    rotation % 180 == 90 ? (height, width) : (width, height);
