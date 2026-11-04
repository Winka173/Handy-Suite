part of '../handy_inventory.dart';

/// When an item that gets used up is likely to run out, learned from the
/// days it was bought: nobody marks each use.
class KeepRunOut {
  final InventoryAsset asset;

  /// The last day it was bought, the day it is expected to run out, and
  /// the usual days between two purchases.
  final String last, expected;
  final int every;

  /// Purchases the estimate rests on (two or more).
  final int purchases;
  const KeepRunOut(
    this.asset,
    this.last,
    this.expected,
    this.every,
    this.purchases,
  );

  /// Days from [today] until [expected]; negative once it has passed.
  int daysLeft(String today) => DateTime.parse(
    '${expected}T00:00:00Z',
  ).difference(DateTime.parse('${today}T00:00:00Z')).inDays;
}

String _plainName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Run-out estimates for items bought at least twice, at most half a year
/// apart, soonest first. An
/// item's purchases are its purchase day, the days it was bought again, and
/// the purchase days of other items with the same name (several packs of
/// the same thing saved one by one).
///
/// Only things that get used up: an item set to another profile (a
/// collectible, a lasting asset, a custom one) is left out, so two figures
/// of the same name never "run out". Items without a profile keep being
/// read from their purchases, as before profiles existed.
List<KeepRunOut> runOutEstimates(KeepState state) {
  final counted = [
    for (final a in state.assets)
      if (!a._data.containsKey('profile') || a.profile == 'consumable') a,
  ];
  final byName = <String, Set<String>>{};
  for (final a in counted) {
    final days = byName.putIfAbsent(_plainName(a.name), () => {});
    if (a.purchasedOn.isNotEmpty) days.add(a.purchasedOn);
    days.addAll(a.restocks);
  }
  final out = <KeepRunOut>[];
  final seen = <String>{};
  // The newest item of a name stands for the name.
  final newest = [...counted]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  for (final a in newest) {
    final name = _plainName(a.name);
    if (!seen.add(name)) continue;
    final days = byName[name]!.toList()..sort();
    if (days.length < 2) continue;
    final gaps = [
      for (var i = 1; i < days.length; i++)
        DateTime.parse(
          '${days[i]}T00:00:00Z',
        ).difference(DateTime.parse('${days[i - 1]}T00:00:00Z')).inDays,
    ]..sort();
    // The middle gap, so one late or early purchase does not swing it.
    final every = gaps[gaps.length ~/ 2];
    // Bought again within half a year: something used up, not a TV
    // replaced years later.
    if (every < 1 || every > 180) continue;
    final last = days.last;
    final expected = DateTime.parse(
      '${last}T00:00:00Z',
    ).add(Duration(days: every)).toIso8601String().substring(0, 10);
    out.add(KeepRunOut(a, last, expected, every, days.length));
  }
  out.sort((x, y) => x.expected.compareTo(y.expected));
  return out;
}

/// [state] with item [id] bought again on [day]: the one tap the run-out
/// estimate learns from. A day already recorded is not counted twice.
KeepState restockAsset(KeepState state, String id, String day, {String? now}) {
  final a = _asset(state, id);
  return saveAsset(
    state,
    a.copyWith({
      'restocks': [...a.restocks, day],
      'updatedAt': now ?? _now(),
    }),
  );
}

/// The estimate that covers [asset] (by its name), if there is one.
KeepRunOut? runOutFor(KeepState state, InventoryAsset asset) => runOutEstimates(
  state,
).where((r) => _plainName(r.asset.name) == _plainName(asset.name)).firstOrNull;
