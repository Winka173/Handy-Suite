import 'package:flutter_test/flutter_test.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'memories_test.dart' show memories;

Json stamp([Map<String, Object?> more = const {}]) => {
  'style': 'travel-double-stars',
  'ink': 0xff0284c7,
  'place': 'Hội An',
  'trip': true,
  'zoom': 1.5,
  'dx': .2,
  'dy': -.1,
  'rotation': -6,
  'wear': .3,
  'saved': '2026-11-04T08:00:00Z',
  ...more,
};

void main() {
  final now = DateTime.utc(2026, 11, 4);

  test('a saved stamp stays on its visit and through a full backup', () {
    final s0 = memories();
    final photo = s0.visits.firstWhere((v) => v.key == 'first').assets.first;
    final s = saveStamp(s0, 'first', stamp({'photo': photo}), now: now);
    expect(stampedVisits(s).map((v) => v.key), ['first']);
    final back = readBackup(fullBackup(s));
    final saved = back.visits.firstWhere((v) => v.key == 'first').stamp!;
    expect(saved['style'], 'travel-double-stars');
    expect(saved['photo'], photo);
    expect(saved['zoom'], 1.5);
    // Replacing keeps one stamp per visit; removing leaves the visit.
    final again = saveStamp(
      s,
      'first',
      stamp({'style': 'minimal-circle'}),
      now: now,
    );
    expect(stampedVisits(again).single.stamp!['style'], 'minimal-circle');
    final gone = removeStamp(again, 'first', now: now);
    expect(stampedVisits(gone), isEmpty);
    expect(gone.visits.map((v) => v.key), contains('first'));
  });

  test('stamp values out of range and foreign photos are refused', () {
    final s = memories();
    for (final bad in <Map<String, Object?>>[
      {'style': 'Bad Style'},
      {'zoom': 9},
      {'rotation': 40},
      {'ink': -1},
      {'trip': 'yes'},
    ]) {
      expect(
        () => saveStamp(s, 'first', stamp(bad), now: now),
        throwsFormatException,
        reason: '$bad',
      );
    }
    expect(
      () => saveStamp(s, 'second', stamp({'photo': 'someone-else'}), now: now),
      throwsFormatException,
    );
  });
}
