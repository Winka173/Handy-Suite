part of '../handy_tools_engine.dart';

/// Most entries a draw takes; more is a spreadsheet's job.
const drawEntryLimit = 500;

/// The entries of a typed or pasted list: one per line (or per comma or
/// semicolon when the text is one line), trimmed, blanks dropped. Repeats are
/// kept as written: a name entered twice has two chances.
List<String> drawEntries(String text) {
  _bounded(text, 50000);
  final lines = text.contains('\n')
      ? text.split(RegExp(r'\r?\n'))
      : text.split(RegExp(r'[,;]'));
  final out = [
    for (final l in lines)
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (out.length > drawEntryLimit) {
    throw const FormatException(
      'Up to $drawEntryLimit entries / Tối đa $drawEntryLimit mục',
    );
  }
  return out;
}

math.Random _drawRandom(math.Random? random) => random ?? math.Random.secure();

/// [count] entries picked without replacement, in the order they came out.
List<String> drawLots(List<String> entries, int count, {math.Random? random}) {
  if (count < 1 || count > entries.length) {
    throw FormatException(
      'Pick 1 to ${entries.length} / Chọn từ 1 đến ${entries.length}',
    );
  }
  final pool = [...entries], r = _drawRandom(random);
  return [
    for (var i = 0; i < count; i++) pool.removeAt(r.nextInt(pool.length)),
  ];
}

/// Every entry dealt into [teams] teams whose sizes differ by at most one;
/// inside a team, names keep the order they were drawn in.
List<List<String>> drawTeams(
  List<String> entries,
  int teams, {
  math.Random? random,
}) {
  if (teams < 2 || teams > entries.length) {
    throw FormatException(
      'Teams: 2 to ${entries.length} / Số đội: 2 đến ${entries.length}',
    );
  }
  final order = drawLots(entries, entries.length, random: random);
  return [
    for (var t = 0; t < teams; t++)
      [for (var i = t; i < order.length; i += teams) order[i]],
  ];
}

/// Heads (true) or tails.
bool flipCoin({math.Random? random}) => _drawRandom(random).nextBool();

/// Dice written as `NdM` (`2d6`, `d20`; 1-20 dice, 2-100 sides): each roll.
List<int> rollDice(String spec, {math.Random? random}) {
  final m = RegExp(r'^\s*(\d*)\s*[dD]\s*(\d+)\s*$').firstMatch(spec);
  final n = m == null ? null : (m[1]!.isEmpty ? 1 : int.parse(m[1]!)),
      sides = m == null ? null : int.parse(m[2]!);
  if (n == null ||
      sides == null ||
      n < 1 ||
      n > 20 ||
      sides < 2 ||
      sides > 100) {
    throw const FormatException(
      'Dice like 2d6: 1-20 dice, 2-100 sides / Xúc xắc dạng 2d6',
    );
  }
  final r = _drawRandom(random);
  return [for (var i = 0; i < n; i++) r.nextInt(sides) + 1];
}
