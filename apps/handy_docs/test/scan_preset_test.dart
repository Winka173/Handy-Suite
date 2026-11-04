import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'helpers.dart';
import 'scan_test.dart' show scan, saved;
import 'session_test.dart' show samplePng;

void main() {
  testWidgets('a receipt is saved in grey at a higher contrast', (
    tester,
  ) async {
    final docs = await scan(tester);
    docs.files.next = ImportedBytes('Receipt.png', samplePng());
    await tapKey(tester, 'scan-import');
    await tapKey(tester, 'scan-preset-receipt');
    expect(find.text('Saved in grey: smaller, and text stands out.'), findsOne);
    await tapKey(tester, 'save-scan-page');
    final page = decodeScanImage(saved(docs).single.png);
    for (var i = 0; i < page.rgba.length; i += 4) {
      expect(page.rgba[i], page.rgba[i + 1]);
      expect(page.rgba[i + 1], page.rgba[i + 2]);
    }
  });
}
