import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:pdfrx/pdfrx.dart';
import 'stamps.dart';

const supported = false;

typedef Mark = Object;
typedef ImageReport = ({int changed, int kept});

Mark markOf(PdfStamp s) => s;
Mark watermarkMark(int page, String text) => text;

Never _native() =>
    throw const FormatException('Editing PDF content requires a native app');

Future<void> applyMarks(
  PdfDocument document,
  List<Mark> marks,
  Uint8List? font,
  CancellationToken? cancellation,
) async => _native();

Future<ImageReport> recompressImages(
  PdfDocument document,
  int quality,
  int dpi,
  CancellationToken? cancellation,
) async => _native();
