import 'dart:math';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:test/test.dart';

void main() {
  test('entries come one per line, or split by commas on one line', () {
    expect(drawEntries(' An \n\nBình\nAn\n'), ['An', 'Bình', 'An']);
    expect(drawEntries('An, Bình; Chi'), ['An', 'Bình', 'Chi']);
    expect(drawEntries('   '), isEmpty);
    expect(
      () => drawEntries(List.filled(501, 'x').join('\n')),
      throwsFormatException,
    );
  });
  test('a draw picks without repeats and refuses impossible counts', () {
    final names = ['An', 'Bình', 'Chi', 'Dũng', 'Em'];
    for (var seed = 0; seed < 50; seed++) {
      final picked = drawLots(names, 3, random: Random(seed));
      expect(picked.toSet(), hasLength(3));
      expect(names, containsAll(picked));
    }
    expect(drawLots(names, 5, random: Random(1)).toSet(), names.toSet());
    expect(() => drawLots(names, 0), throwsFormatException);
    expect(() => drawLots(names, 6), throwsFormatException);
  });
  test('teams use everyone once and differ in size by at most one', () {
    final names = [for (var i = 0; i < 11; i++) 'P$i'];
    final teams = drawTeams(names, 3, random: Random(7));
    expect(teams.map((t) => t.length).toList()..sort(), [3, 4, 4]);
    expect(teams.expand((t) => t).toSet(), names.toSet());
    expect(() => drawTeams(names, 1), throwsFormatException);
    expect(() => drawTeams(['a'], 2), throwsFormatException);
  });
  test('every face of a die and both sides of a coin turn up', () {
    final r = Random(3);
    final faces = <int>{};
    for (var i = 0; i < 400; i++) {
      faces.addAll(rollDice('d6', random: r));
    }
    expect(faces, {1, 2, 3, 4, 5, 6});
    expect(rollDice('3d20', random: r), hasLength(3));
    final coins = {for (var i = 0; i < 50; i++) flipCoin(random: r)};
    expect(coins, {true, false});
    for (final bad in ['0d6', '21d6', '2d1', '2d101', 'six', '']) {
      expect(() => rollDice(bad), throwsFormatException, reason: bad);
    }
  });
}
