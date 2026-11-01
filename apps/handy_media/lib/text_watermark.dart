import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:handy_core/handy_core.dart';

/// Render Unicode using the same local Flutter font fallback as the app.
/// The existing logo compositor applies sizing, positioning, alpha and batching.
Future<Uint8List> renderTextWatermark(
  String text, {
  CancellationToken? cancellation,
}) async {
  if (text.trim().isEmpty ||
      text.runes.length > 100 ||
      text.runes.any((r) => r < 32 || r >= 127 && r <= 159)) {
    throw const FormatException(
      'Watermark requires 1–100 printable characters',
    );
  }
  cancellation?.check();
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xffffffff),
        fontSize: 64,
        height: 1.3,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  );
  ui.Image? image;
  ui.Picture? picture;
  try {
    painter.layout(maxWidth: 8192);
    final width = painter.width.ceil() + 8, height = painter.height.ceil() + 8;
    if (painter.didExceedMaxLines ||
        width > 8192 ||
        height > 512 ||
        width * height > 4000000) {
      throw const FormatException('Watermark text exceeds rendering limits');
    }
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(4, 4));
    picture = recorder.endRecording();
    image = await picture.toImage(width, height);
    cancellation?.check();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    cancellation?.check();
    if (data == null)
      throw const FormatException('Could not render watermark text');
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image?.dispose();
    picture?.dispose();
    painter.dispose();
  }
}
