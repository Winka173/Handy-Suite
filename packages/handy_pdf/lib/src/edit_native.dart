import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as img;
import 'package:pdfium_dart/pdfium_dart.dart' as native;
import 'package:pdfrx/pdfrx.dart';
import 'stamps.dart';

const supported = true;

/// One mark for the PDFium worker. [shown] is true when x, y, w, h are
/// points from the shown page's bottom-left corner, false when they are a
/// [PdfBox] (fractions from the top-left).
typedef Mark = ({
  int page,
  bool shown,
  double x,
  double y,
  double w,
  double h,
  String? text,
  int color,
  bool invisible,
  bool fit,
  Uint8List? rgba,
  int pw,
  int ph,
});

Mark markOf(PdfStamp s) => switch (s) {
  PdfImageStamp(:final rgba, :final pixelWidth, :final pixelHeight) => (
    page: s.page,
    shown: false,
    x: s.box.left,
    y: s.box.top,
    w: s.box.width,
    h: s.box.height,
    text: null,
    color: 0,
    invisible: false,
    fit: false,
    rgba: rgba,
    pw: pixelWidth,
    ph: pixelHeight,
  ),
  PdfTextStamp(:final text, :final color, :final invisible, :final fit) => (
    page: s.page,
    shown: false,
    x: s.box.left,
    y: s.box.top,
    w: s.box.width,
    h: s.box.height,
    text: text,
    color: color,
    invisible: invisible,
    fit: fit,
    rgba: null,
    pw: 0,
    ph: 0,
  ),
};

/// The legacy stamp: 18 pt half-transparent grey, 24 pt in from the shown
/// page's bottom-left corner, upright whatever the page's rotation.
Mark watermarkMark(int page, String text) => (
  page: page,
  shown: true,
  x: 24,
  y: 24 - 18 * textLineHeight * textBaseline,
  w: 0,
  h: 18 * textLineHeight,
  text: text,
  color: 0x80808080,
  invisible: false,
  fit: false,
  rgba: null,
  pw: 0,
  ph: 0,
);

/// Draws [marks] onto an assembled destination, never a caller's source
/// document. Text uses the embedded [font] (a TrueType file).
Future<void> applyMarks(
  PdfDocument document,
  List<Mark> marks,
  Uint8List? font,
  CancellationToken? cancellation,
) async {
  cancellation?.check();
  final address = await document.useNativeDocumentHandle((address) => address);
  // Font callbacks belong to PDFium's worker isolate. Creating text on the UI
  // isolate can invoke a callback on the wrong isolate, even when suspended.
  // One call per document so the font is embedded once.
  await PdfrxEntryFunctions.instance.compute(_draw, (
    address: address,
    marks: marks,
    font: font,
    modulePath: Pdfrx.pdfiumModulePath,
  ));
  cancellation?.check();
  await _reload(document);
}

Future<void> _reload(PdfDocument document) =>
    // Explicit pages are required in pdfrx_engine 0.4.7: a null selection
    // reloads only newly added pages. Replace source proxies before encoding.
    document.reloadPages(
      pageNumbersToReload: [for (var i = 1; i <= document.pages.length; i++) i],
    );

void _draw(
  ({int address, List<Mark> marks, Uint8List? font, String? modulePath}) args,
) {
  final pdfium = native.getPdfium(modulePath: args.modulePath);
  final doc = Pointer<native.fpdf_document_t__>.fromAddress(args.address);
  Pointer<Uint8> fontData = nullptr;
  native.FPDF_FONT font = nullptr;
  try {
    if (args.marks.any((m) => m.text != null)) {
      final bytes = args.font;
      if (bytes == null) throw const FormatException('A font is required');
      fontData = malloc<Uint8>(bytes.length);
      fontData.asTypedList(bytes.length).setAll(0, bytes);
      font = pdfium.FPDFText_LoadFont(
        doc,
        fontData,
        bytes.length,
        native.FPDF_FONT_TRUETYPE,
        1,
      );
      if (font == nullptr) {
        throw const FormatException('The font could not be embedded');
      }
    }
    final pages = <int, List<Mark>>{};
    for (final m in args.marks) {
      (pages[m.page] ??= []).add(m);
    }
    for (final MapEntry(key: index, value: marks) in pages.entries) {
      _drawPage(pdfium, doc, index, marks, font);
    }
  } finally {
    if (font != nullptr) pdfium.FPDFFont_Close(font);
    if (fontData != nullptr) malloc.free(fontData);
  }
}

void _drawPage(
  native.PDFium pdfium,
  native.FPDF_DOCUMENT doc,
  int index,
  List<Mark> marks,
  native.FPDF_FONT font,
) {
  final page = pdfium.FPDF_LoadPage(doc, index);
  if (page == nullptr) {
    throw const FormatException('Could not open a PDF page to mark');
  }
  final rect = calloc<native.FS_RECTF>();
  final pagePtr = calloc<native.FPDF_PAGE>()..value = page;
  try {
    if (pdfium.FPDF_GetPageBoundingBox(page, rect) == 0) {
      throw const FormatException('Could not measure a PDF page');
    }
    final r = rect.ref;
    final left = math.min(r.left, r.right), right = math.max(r.left, r.right);
    final bottom = math.min(r.top, r.bottom), top = math.max(r.top, r.bottom);
    final rotation = pdfium.FPDFPage_GetRotation(page) * 90;
    final (sw, sh) = shownSize(rotation, right - left, top - bottom);
    final m = shownToPdf(rotation, left, bottom, right, top);
    for (final mark in marks) {
      final x = mark.shown ? mark.x : mark.x * sw;
      final w = mark.shown ? mark.w : mark.w * sw;
      final h = mark.shown ? mark.h : mark.h * sh;
      final y = mark.shown ? mark.y : (1 - mark.y - mark.h) * sh;
      final object = mark.rgba != null
          ? _image(pdfium, doc, pagePtr, mark, x, y, w, h)
          : _text(pdfium, doc, font, mark, x, y, w, h);
      pdfium.FPDFPageObj_Transform(object, m[0], m[1], m[2], m[3], m[4], m[5]);
      if (pdfium.FPDFPage_InsertObject(page, object) == 0) {
        // PDFium owns the object after insertion; otherwise the caller does.
        pdfium.FPDFPageObj_Destroy(object);
        throw const FormatException('Could not place a mark on the page');
      }
    }
    if (pdfium.FPDFPage_GenerateContent(page) == 0) {
      throw const FormatException('Could not save the marked page');
    }
  } finally {
    calloc.free(rect);
    calloc.free(pagePtr);
    pdfium.FPDF_ClosePage(page);
  }
}

native.FPDF_PAGEOBJECT _image(
  native.PDFium pdfium,
  native.FPDF_DOCUMENT doc,
  Pointer<native.FPDF_PAGE> page,
  Mark mark,
  double x,
  double y,
  double w,
  double h,
) {
  final object = pdfium.FPDFPageObj_NewImageObj(doc);
  if (object == nullptr) {
    throw const FormatException('Could not create a picture');
  }
  final bitmap = pdfium.FPDFBitmap_CreateEx(
    mark.pw,
    mark.ph,
    native.FPDFBitmap_BGRA,
    nullptr,
    0,
  );
  try {
    if (bitmap == nullptr) throw const FormatException('Picture too large');
    final stride = pdfium.FPDFBitmap_GetStride(bitmap);
    final buffer = pdfium.FPDFBitmap_GetBuffer(
      bitmap,
    ).cast<Uint8>().asTypedList(stride * mark.ph);
    final rgba = mark.rgba!;
    for (var row = 0; row < mark.ph; row++) {
      for (var col = 0; col < mark.pw; col++) {
        final s = (row * mark.pw + col) * 4, d = row * stride + col * 4;
        buffer[d] = rgba[s + 2];
        buffer[d + 1] = rgba[s + 1];
        buffer[d + 2] = rgba[s];
        buffer[d + 3] = rgba[s + 3];
      }
    }
    if (pdfium.FPDFImageObj_SetBitmap(page, 1, object, bitmap) == 0 ||
        pdfium.FPDFImageObj_SetMatrix(object, w, 0, 0, h, x, y) == 0) {
      throw const FormatException('Could not create a picture');
    }
    return object;
  } catch (_) {
    pdfium.FPDFPageObj_Destroy(object);
    rethrow;
  } finally {
    if (bitmap != nullptr) pdfium.FPDFBitmap_Destroy(bitmap);
  }
}

native.FPDF_PAGEOBJECT _text(
  native.PDFium pdfium,
  native.FPDF_DOCUMENT doc,
  native.FPDF_FONT font,
  Mark mark,
  double x,
  double y,
  double w,
  double h,
) {
  final text = mark.text!;
  final object = pdfium.FPDFPageObj_CreateTextObj(
    doc,
    font,
    h / textLineHeight,
  );
  if (object == nullptr) throw const FormatException('Could not create text');
  final wide = calloc<UnsignedShort>(text.length + 1);
  final l = calloc<Float>(), b = calloc<Float>(), r = calloc<Float>();
  final t = calloc<Float>();
  try {
    for (var i = 0; i < text.length; i++) {
      wide[i] = text.codeUnitAt(i);
    }
    final c = mark.color;
    if (pdfium.FPDFText_SetText(object, wide) == 0 ||
        pdfium.FPDFPageObj_SetFillColor(
              object,
              (c >> 16) & 0xff,
              (c >> 8) & 0xff,
              c & 0xff,
              (c >> 24) & 0xff,
            ) ==
            0) {
      throw const FormatException('Could not create text');
    }
    if (mark.invisible) {
      pdfium.FPDFTextObj_SetTextRenderMode(
        object,
        native.FPDF_TEXT_RENDERMODE.FPDF_TEXTRENDERMODE_INVISIBLE,
      );
    }
    if (mark.fit &&
        w > 0 &&
        pdfium.FPDFPageObj_GetBounds(object, l, b, r, t) != 0) {
      final natural = r.value - l.value;
      if (natural > 0.5) {
        pdfium.FPDFPageObj_Transform(object, w / natural, 0, 0, 1, 0, 0);
      }
    }
    pdfium.FPDFPageObj_Transform(object, 1, 0, 0, 1, x, y + h * textBaseline);
    return object;
  } catch (_) {
    pdfium.FPDFPageObj_Destroy(object);
    rethrow;
  } finally {
    calloc.free(wide);
    calloc.free(l);
    calloc.free(b);
    calloc.free(r);
    calloc.free(t);
  }
}

/// What re-encoding the pictures did.
typedef ImageReport = ({int changed, int kept});

/// Re-encodes the pictures of an assembled destination as JPEG at
/// [quality], no sharper than [dpi] at their size on the page. Pictures
/// that are shared between pages, transparent, turned, black-and-white, or
/// that would not get smaller are left exactly as they were.
Future<ImageReport> recompressImages(
  PdfDocument document,
  int quality,
  int dpi,
  CancellationToken? cancellation,
) async {
  cancellation?.check();
  final address = await document.useNativeDocumentHandle((address) => address);
  final shared = await PdfrxEntryFunctions.instance.compute(_sharedImages, (
    address: address,
    modulePath: Pdfrx.pdfiumModulePath,
  ));
  var changed = 0, kept = 0;
  for (var i = 0; i < document.pages.length; i++) {
    cancellation?.check();
    final report = await PdfrxEntryFunctions.instance.compute(_recompressPage, (
      address: address,
      index: i,
      quality: quality,
      dpi: dpi,
      shared: shared,
      modulePath: Pdfrx.pdfiumModulePath,
    ));
    changed += report.changed;
    kept += report.kept;
  }
  cancellation?.check();
  await _reload(document);
  return (changed: changed, kept: kept);
}

/// Pictures drawn more than once (a logo on every page) share one stream;
/// replacing each use would store several copies, so they stay as they are.
Set<int> _sharedImages(({int address, String? modulePath}) args) {
  final pdfium = native.getPdfium(modulePath: args.modulePath);
  final doc = Pointer<native.fpdf_document_t__>.fromAddress(args.address);
  final seen = <int>{}, shared = <int>{};
  for (var i = 0; i < pdfium.FPDF_GetPageCount(doc); i++) {
    final page = pdfium.FPDF_LoadPage(doc, i);
    if (page == nullptr) continue;
    try {
      for (var o = 0; o < pdfium.FPDFPage_CountObjects(page); o++) {
        final object = pdfium.FPDFPage_GetObject(page, o);
        if (pdfium.FPDFPageObj_GetType(object) != native.FPDF_PAGEOBJ_IMAGE) {
          continue;
        }
        final key = _rawKey(pdfium, object);
        if (key != null && !seen.add(key)) shared.add(key);
      }
    } finally {
      pdfium.FPDF_ClosePage(page);
    }
  }
  return shared;
}

int? _rawKey(native.PDFium pdfium, native.FPDF_PAGEOBJECT object) {
  final size = pdfium.FPDFImageObj_GetImageDataRaw(object, nullptr, 0);
  if (size <= 0 || size > 40000000) return null;
  final buffer = malloc<Uint8>(size);
  try {
    pdfium.FPDFImageObj_GetImageDataRaw(object, buffer.cast(), size);
    // FNV-1a over the stored bytes, with the length.
    var hash = 0x811c9dc5 ^ size;
    for (final byte in buffer.asTypedList(size)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return hash * 64 + (size & 63);
  } finally {
    malloc.free(buffer);
  }
}

ImageReport _recompressPage(
  ({
    int address,
    int index,
    int quality,
    int dpi,
    Set<int> shared,
    String? modulePath,
  })
  args,
) {
  final pdfium = native.getPdfium(modulePath: args.modulePath);
  final doc = Pointer<native.fpdf_document_t__>.fromAddress(args.address);
  final page = pdfium.FPDF_LoadPage(doc, args.index);
  if (page == nullptr) return (changed: 0, kept: 0);
  final pagePtr = calloc<native.FPDF_PAGE>()..value = page;
  final matrix = calloc<native.FS_MATRIX>();
  final meta = calloc<native.FPDF_IMAGEOBJ_METADATA>();
  var changed = 0, kept = 0;
  try {
    for (var o = 0; o < pdfium.FPDFPage_CountObjects(page); o++) {
      final object = pdfium.FPDFPage_GetObject(page, o);
      if (pdfium.FPDFPageObj_GetType(object) != native.FPDF_PAGEOBJ_IMAGE) {
        continue;
      }
      final jpeg = _smaller(pdfium, doc, page, object, matrix, meta, args);
      if (jpeg == null || !_loadJpeg(pdfium, pagePtr, object, jpeg)) {
        kept++;
        continue;
      }
      changed++;
    }
    if (changed > 0 && pdfium.FPDFPage_GenerateContent(page) == 0) {
      throw const FormatException('Could not save a smaller page');
    }
    return (changed: changed, kept: kept);
  } finally {
    calloc.free(pagePtr);
    calloc.free(matrix);
    calloc.free(meta);
    pdfium.FPDF_ClosePage(page);
  }
}

/// The picture as a smaller JPEG, or null when it must stay as it is.
Uint8List? _smaller(
  native.PDFium pdfium,
  native.FPDF_DOCUMENT doc,
  native.FPDF_PAGE page,
  native.FPDF_PAGEOBJECT object,
  Pointer<native.FS_MATRIX> matrix,
  Pointer<native.FPDF_IMAGEOBJ_METADATA> meta,
  ({
    int address,
    int index,
    int quality,
    int dpi,
    Set<int> shared,
    String? modulePath,
  })
  args,
) {
  if (pdfium.FPDFPageObj_GetMatrix(object, matrix) == 0 ||
      pdfium.FPDFImageObj_GetImageMetadata(object, page, meta) == 0) {
    return null;
  }
  final m = matrix.ref, info = meta.ref;
  // Turned or skewed pictures, 1-bit scans and tiny marks stay untouched.
  if (m.b.abs() > 1e-4 || m.c.abs() > 1e-4) return null;
  if (info.bits_per_pixel < 8 || info.width < 64 || info.height < 64) {
    return null;
  }
  if (info.width * info.height > 25000000) return null;
  final raw = pdfium.FPDFImageObj_GetImageDataRaw(object, nullptr, 0);
  if (raw <= 0) return null;
  final key = _rawKey(pdfium, object);
  if (key == null || args.shared.contains(key)) return null;
  if (_transparent(pdfium, doc, page, object)) return null;
  final bitmap = pdfium.FPDFImageObj_GetBitmap(object);
  if (bitmap == nullptr) return null;
  img.Image picture;
  try {
    final format = pdfium.FPDFBitmap_GetFormat(bitmap);
    final width = pdfium.FPDFBitmap_GetWidth(bitmap);
    final height = pdfium.FPDFBitmap_GetHeight(bitmap);
    final stride = pdfium.FPDFBitmap_GetStride(bitmap);
    final channels = switch (format) {
      native.FPDFBitmap_Gray => 1,
      native.FPDFBitmap_BGR => 3,
      native.FPDFBitmap_BGRx => 4,
      _ => 0,
    };
    if (channels == 0) return null;
    final pixels = pdfium.FPDFBitmap_GetBuffer(
      bitmap,
    ).cast<Uint8>().asTypedList(stride * height);
    picture = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(pixels).buffer,
      rowStride: stride,
      numChannels: channels,
      order: switch (channels) {
        3 => img.ChannelOrder.bgr,
        4 => img.ChannelOrder.bgra,
        _ => null,
      },
    );
    if (channels == 4) {
      picture = picture.convert(numChannels: 3);
    }
  } finally {
    pdfium.FPDFBitmap_Destroy(bitmap);
  }
  // Points on the page to pixels at the chosen sharpness.
  final target = math.max(
    1,
    (m.a.abs() / 72 * args.dpi).ceil().clamp(1, picture.width),
  );
  if (target < picture.width * 0.95) {
    picture = img.copyResize(
      picture,
      width: target,
      interpolation: img.Interpolation.average,
    );
  }
  final jpeg = img.encodeJpg(picture, quality: args.quality);
  // Keep the original unless the new picture saves at least a tenth.
  return jpeg.length < raw * 0.9 ? jpeg : null;
}

/// True when the picture has a soft mask or transparent pixels: a JPEG
/// replacement would lose them.
bool _transparent(
  native.PDFium pdfium,
  native.FPDF_DOCUMENT doc,
  native.FPDF_PAGE page,
  native.FPDF_PAGEOBJECT object,
) {
  final rendered = pdfium.FPDFImageObj_GetRenderedBitmap(doc, page, object);
  if (rendered == nullptr) return true;
  try {
    if (pdfium.FPDFBitmap_GetFormat(rendered) != native.FPDFBitmap_BGRA) {
      return false;
    }
    final width = pdfium.FPDFBitmap_GetWidth(rendered);
    final height = pdfium.FPDFBitmap_GetHeight(rendered);
    final stride = pdfium.FPDFBitmap_GetStride(rendered);
    final pixels = pdfium.FPDFBitmap_GetBuffer(
      rendered,
    ).cast<Uint8>().asTypedList(stride * height);
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < width; col++) {
        if (pixels[row * stride + col * 4 + 3] != 255) return true;
      }
    }
    return false;
  } finally {
    pdfium.FPDFBitmap_Destroy(rendered);
  }
}

typedef _Read =
    Int Function(
      Pointer<Void>,
      UnsignedLong,
      Pointer<UnsignedChar>,
      UnsignedLong,
    );

bool _loadJpeg(
  native.PDFium pdfium,
  Pointer<native.FPDF_PAGE> page,
  native.FPDF_PAGEOBJECT object,
  Uint8List jpeg,
) {
  final data = malloc<Uint8>(jpeg.length);
  final access = calloc<native.FPDF_FILEACCESS>();
  final read = NativeCallable<_Read>.isolateLocal((
    Pointer<Void> _,
    int position,
    Pointer<UnsignedChar> buffer,
    int size,
  ) {
    final count = math.min(size, jpeg.length - position);
    if (count <= 0) return 0;
    buffer
        .cast<Uint8>()
        .asTypedList(count)
        .setAll(
          0,
          data.asTypedList(jpeg.length).sublist(position, position + count),
        );
    return 1;
  }, exceptionalReturn: 0);
  try {
    data.asTypedList(jpeg.length).setAll(0, jpeg);
    access.ref.m_FileLen = jpeg.length;
    access.ref.m_GetBlock = read.nativeFunction;
    return pdfium.FPDFImageObj_LoadJpegFileInline(page, 1, object, access) != 0;
  } finally {
    read.close();
    calloc.free(access);
    malloc.free(data);
  }
}
