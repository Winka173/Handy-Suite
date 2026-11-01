import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:handy_core/handy_core.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as native;

const supported = true;

/// Edits only an assembled destination, never a caller's source document.
Future<void> applyWatermark(
  PdfDocument document,
  String text,
  CancellationToken? cancellation,
) async {
  final address = await document.useNativeDocumentHandle((address) => address);
  for (var i = 0; i < document.pages.length; i++) {
    cancellation?.check();
    // Font callbacks belong to PDFium's worker isolate. Creating text on the UI
    // isolate can invoke a callback on the wrong isolate, even when suspended.
    await PdfrxEntryFunctions.instance.compute(_stampPage, (
      address: address,
      index: i,
      text: text,
      modulePath: Pdfrx.pdfiumModulePath,
    ));
  }
  cancellation?.check();
  // Explicit pages are required in pdfrx_engine 0.4.7: a null selection reloads
  // only newly added pages. Replace source proxies before the next encode.
  await document.reloadPages(
    pageNumbersToReload: [for (var i = 1; i <= document.pages.length; i++) i],
  );
}

void _stampPage(
  ({int address, int index, String text, String? modulePath}) args,
) {
  final pdfium = native.getPdfium(modulePath: args.modulePath);
  final font = 'Helvetica'.toNativeUtf8();
  final wideText = calloc<UnsignedShort>(args.text.length + 1);
  try {
    for (var i = 0; i < args.text.length; i++) {
      wideText[i] = args.text.codeUnitAt(i);
    }
    final handle = Pointer<native.fpdf_document_t__>.fromAddress(args.address);
    final page = pdfium.FPDF_LoadPage(handle, args.index);
    if (page == nullptr) {
      throw const FormatException('Could not open PDF page for watermark');
    }
    Pointer<native.fpdf_pageobject_t__> object = nullptr;
    var inserted = false;
    try {
      object = pdfium.FPDFPageObj_NewTextObj(handle, font.cast(), 18);
      if (object == nullptr ||
          pdfium.FPDFText_SetText(object, wideText) == 0 ||
          pdfium.FPDFPageObj_SetFillColor(object, 128, 128, 128, 128) == 0) {
        throw const FormatException('Could not create PDF watermark');
      }
      pdfium.FPDFPageObj_Transform(object, 1, 0, 0, 1, 24, 24);
      inserted = pdfium.FPDFPage_InsertObject(page, object) != 0;
      if (!inserted || pdfium.FPDFPage_GenerateContent(page) == 0) {
        throw const FormatException('Could not save PDF watermark');
      }
    } finally {
      // PDFium owns the object after insertion; otherwise the caller does.
      if (!inserted && object != nullptr) {
        pdfium.FPDFPageObj_Destroy(object);
      }
      pdfium.FPDF_ClosePage(page);
    }
  } finally {
    calloc.free(wideText);
    malloc.free(font);
  }
}
