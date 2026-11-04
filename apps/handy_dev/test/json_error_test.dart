import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

void main() {
  testWidgets('broken JSON says where, and the source is selected there', (
    tester,
  ) async {
    await start(tester);
    const text = '{\n  "a": 1,\n  "b": 2,\n}';
    await paste(tester, text);
    final error = find.byKey(const Key('dev-error'));
    expect(error, findsOneWidget);
    expect(
      find.descendant(
        of: error,
        matching: find.textContaining(
          'Line 4, column 1: remove the comma before it',
        ),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'dev-error-show');
    final field = tester.widget<TextField>(find.byKey(const Key('dev-input')));
    expect(field.controller!.selection.baseOffset, text.lastIndexOf('}'));
  });

  testWidgets('a tree row copies its JSON Pointer and its value', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await start(tester);
    await paste(tester, '{"order": {"a/b": [{"sku": "A-17"}]}}');
    await tapKey(tester, r'tree-row-$.order');
    final row = find.byKey(const Key(r"tree-row-$.order['a/b']"));
    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tree-copy-pointer')));
    await tester.pumpAndSettle();
    expect(copied, '/order/a~1b');

    await tester.longPress(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tree-copy-value')));
    await tester.pumpAndSettle();
    expect(copied, '[\n  {\n    "sku": "A-17"\n  }\n]');
  });
}
