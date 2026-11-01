import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/privacy.dart';
import 'package:handy_spend/controller.dart';
import 'controller_test.dart' show TestSpendStore;

class TestAuthentication extends SpendPrivacy {
  bool success = false;
  @override
  bool get supported => true;
  @override
  Future<bool> unlock(String reason) async => success;
}

void main() {
  testWidgets(
    'device lock cancel stays closed; successful OS response reveals data',
    (tester) async {
      final store = TestSpendStore();
      store.value = store.value.copy({
        'settings': {'deviceLock': true, 'lockSeconds': 0},
      });
      final controller = SpendController(open: () async => store);
      await controller.load();
      final auth = TestAuthentication();
      await tester.pumpWidget(
        SpendPrivacyGate(
          controller: controller,
          authentication: auth,
          child: const MaterialApp(
            home: Scaffold(body: Text('Private ledger')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private ledger'), findsNothing);
      await tester.tap(find.byKey(const Key('spend-unlock')));
      await tester.pumpAndSettle();
      expect(find.text('Private ledger'), findsNothing);
      auth.success = true;
      await tester.tap(find.byKey(const Key('spend-unlock')));
      await tester.pumpAndSettle();
      expect(find.text('Private ledger'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  test(
    'dropped file stream is bounded, wrong extensions/directories refused',
    () async {
      final file = DropItemFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'statement.csv',
        path: 'statement.csv',
      );
      expect((await readDroppedStatement(file)).bytes, [1, 2, 3]);
      await expectLater(
        readDroppedStatement(
          DropItemFile.fromData(Uint8List(1), name: 'script.exe'),
        ),
        throwsFormatException,
      );
      await expectLater(
        readDroppedStatement(
          DropItemFile.fromData(
            Uint8List(12000001),
            name: 'big.xlsx',
            path: 'big.xlsx',
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
