import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/features/passport/stamp_design.dart';

void main() {
  testWidgets('every stamp shape renders a transparent PNG and a print sheet', (
    t,
  ) async {
    await t.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 30),
        Paint()..color = const Color(0xff336699),
      );
      final photo = await recorder.endRecording().toImage(40, 30);
      for (final shape in stampShapes) {
        for (final withPhoto in [false, true]) {
          final png = await renderStampPng(
            StampDesign(
              shape: shape,
              place: 'Hội An',
              day: '2026-11-02',
              trip: 'Ba ngày ở biển',
              photo: withPhoto ? photo : null,
              zoom: 1.5,
              offset: const Offset(.2, -.1),
            ),
            side: 300,
          );
          final image = await (await ui.instantiateImageCodec(
            png,
          )).getNextFrame();
          expect(image.image.width, 300);
          // The corner is outside every cut: left transparent.
          final pixels = await image.image.toByteData();
          expect(pixels!.getUint8(3), 0);
          image.image.dispose();
          if (shape == 'postage' && withPhoto) {
            final pdf = await stampSheetPdf(png, 'Personal — not official');
            expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
          }
        }
      }
      photo.dispose();
    });
  });
}
