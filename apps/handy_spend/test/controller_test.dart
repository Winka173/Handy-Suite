import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend/data/store.dart';

class TestSpendStore implements SpendStore {
  SpendState value = SpendState();
  bool fail = false;
  @override
  Future<SpendState> read() async => value;
  @override
  Future<void> commit(SpendState state, {required int expectedRevision}) async {
    if (fail) throw StateError('test storage full');
    if (value.revision != expectedRevision) throw StateError('stale');
    state.validate();
    value = state;
  }

  @override
  Future<String> integrity() async => 'ok';
}

void main() {
  test(
    'restored audit history is preserved alongside the local audit trail',
    () async {
      final store = TestSpendStore(),
          c = SpendController(open: () async => store);
      await c.load();
      await c.change(
        (s) => s.copy({
          'audit': [
            {'id': 'restored-event', 'action': 'historical'},
          ],
        }),
        'restore_backup',
      );
      expect(c.state!.audit.map((e) => e['id']), contains('restored-event'));
      expect(c.state!.audit, hasLength(2));
      c.dispose();
    },
  );
  test(
    'failed write preserves memory, queue recovers, Undo retains audit trail',
    () async {
      final store = TestSpendStore(),
          controller = SpendController(open: () async => store);
      await controller.load();
      store.fail = true;
      SpendState change(SpendState s) => s.copy({
        'accounts': [
          Account(
            id: 'cash',
            name: 'Cash',
            currency: 'VND',
            opening: BigInt.from(100),
            asOf: '2024-01-01',
          ).toJson(),
        ],
      });
      await expectLater(
        controller.change(change, 'create_account'),
        throwsStateError,
      );
      expect(controller.state!.accounts, isEmpty);
      expect(controller.state!.audit, isEmpty);
      store.fail = false;
      await controller.change(change, 'create_account');
      expect(controller.state!.accounts, hasLength(1));
      expect(controller.state!.audit, hasLength(1));
      await controller.undo();
      expect(controller.state!.accounts, isEmpty);
      expect(controller.state!.revision, 2);
      expect(controller.state!.audit, hasLength(2));
      controller.dispose();
    },
  );
}
