import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:handy_scan/handy_scan.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/handy_ui.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bundled native decoder reopens generated QR PNG without camera or network',
    (tester) async {
      final directory = await Directory.systemTemp.createTemp(
        'handy-qr-integration-',
      );
      final file = File('${directory.path}/qr.png');
      final controller = MobileScannerController(autoStart: false);
      try {
        for (final value in [
          'handy-keep://item/legacy-item_1',
          'WIFI:T:WPA;S:Home;P:local-password;;',
          'Tiếng Việt thử nghiệm',
        ]) {
          await file.writeAsBytes(qrPng(value), flush: true);
          final capture = await controller.analyzeImage(
            file.path,
            formats: [BarcodeFormat.qrCode],
          );
          expect(capture, isNotNull);
          expect(
            capture!.barcodes.map((b) => validateScannedQr(b.rawValue!)),
            contains(value),
          );
        }
        await file.writeAsString('not an image', flush: true);
        try {
          final invalid = await controller.analyzeImage(
            file.path,
            formats: [BarcodeFormat.qrCode],
          );
          expect(invalid == null || invalid.barcodes.isEmpty, isTrue);
        } on MobileScannerBarcodeException catch (error) {
          expect(error.toString(), contains('not an image'));
        } on MobileScannerException {
          /* Native decoder visibly rejects a corrupt file. */
        }
      } finally {
        await controller.dispose();
        if (await file.exists()) await file.delete();
        await directory.delete();
      }
    },
  );
  if (const bool.fromEnvironment('DENIED_QR_CAMERA'))
    testWidgets('denied camera is actionable and Back cancels without result', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScannerPage()),
                  );
                },
                child: const Text('Start camera'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start camera'));
      for (
        var attempt = 0;
        attempt < 80 &&
            find.byKey(const Key('qr-camera-retry')).evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('qr-camera-retry')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('tools-qr-camera-denied');
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Start camera'), findsOneWidget);
    });
}
