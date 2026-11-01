import 'package:handy_core/handy_core.dart';
import 'package:pdfrx/pdfrx.dart';

const supported = false;

Future<void> applyWatermark(
  PdfDocument document,
  String text,
  CancellationToken? cancellation,
) async {
  throw const FormatException('PDF watermark requires a native app');
}
