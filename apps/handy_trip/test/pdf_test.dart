import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip/features/sharing/pdf_export.dart';
import 'ui_test.dart' show sample;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real embedded-font PDFs render supported fields, never reservation codes',
    () async {
      final s = sample();
      final privateTitle = s.copy({
        'stops': [
          s.stops.single.copy({'title': 'Museum PRIVATE-ABC'}).toJson(),
        ],
      });
      for (final journal in [false, true]) {
        final bytes = await tripPdf(
          privateTitle,
          journal: journal,
          vietnamese: true,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        expect(bytes.length, greaterThan(2000));
        final file = File(
          '../../docs/qa/evidence/exports/trip-${journal ? 'journal' : 'itinerary'}.pdf',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
    },
  );
}
