// Windows: "Find private details" through the real recogniser
// (Windows.Media.Ocr via package:handy_scan).
//
//   flutter test --no-pub integration_test/windows_ocr_test.dart -d windows
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media/guide/text_reader.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:integration_test/integration_test.dart';

/// A plain settings-like screen with private details written on it.
Future<Uint8List> picture() async {
  const w = 900.0, h = 520.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
  var y = 40.0;
  for (final line in [
    'Account settings',
    'Email: lan.nguyen@example.com',
    'Phone: 0912 345 678',
    'City: Da Nang',
  ]) {
    TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(fontSize: 40, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: w - 80)
      ..paint(canvas, Offset(40, y));
    y += 110;
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the recogniser finds the email and the phone number', (t) async {
    const reader = DeviceTextReader();
    expect(reader.supported, isTrue);
    final png = (await t.runAsync(picture))!;
    final List<OcrLine> lines;
    try {
      lines = (await t.runAsync(() => reader.read(png)))!;
    } on TextReaderUnavailable catch (e) {
      markTestSkipped(
        'No Windows OCR language installed (languageMissing=${e.languageMissing})',
      );
      return;
    }
    expect(lines, isNotEmpty);
    final found = findSensitiveAreas(lines, imageWidth: 900, imageHeight: 520);
    final kinds = {for (final f in found) f.kind};
    expect(kinds, containsAll([SensitiveKind.email, SensitiveKind.phone]));
    final email = found.firstWhere((f) => f.kind == SensitiveKind.email);
    // On the second line, right of its label.
    expect(email.area.y, inInclusiveRange(.2, .4));
    expect(email.area.x, greaterThan(.15));
    expect(email.area.x + email.area.width, lessThanOrEqualTo(1));
    // "Da Nang" and the heading are not proposed.
    expect(found.length, 2);
  });
}
