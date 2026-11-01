import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_scan/handy_scan.dart';
import 'package:handy_ui/handy_ui.dart';

void main() {
  test(
    'native QR boundary preserves source without URL execution or normalization',
    () {
      for (final value in [
        'https://example.org',
        'WIFI:T:WPA;S:Home;P:secret;;',
        'Tiếng Việt',
        'BEGIN:VCARD\nEND:VCARD',
        'javascript:alert(1)',
        'handy-keep://item/legacy',
      ]) {
        expect(validateScannedQr(value), value);
      }
      for (final value in ['', 'x' * 2001, '€' * 667, 'a\u0000b']) {
        expect(() => validateScannedQr(value), throwsFormatException);
      }
    },
  );
  testWidgets(
    'unsupported platforms provide manual fallback without requesting camera',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        expect(nativeQrScanningSupported, isFalse);
        await tester.pumpWidget(const MaterialApp(home: QrScannerPage()));
        await tester.pumpAndSettle();
        expect(find.textContaining('Paste QR text'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
