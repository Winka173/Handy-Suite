import 'package:handy_spend_engine/handy_spend_engine.dart';

/// One person's line in the split editor.
class SplitLine {
  final String who;
  final bool included;
  final int units;

  /// The exact amount typed, in minor units, for an exact split.
  final BigInt? amount;
  const SplitLine(
    this.who, {
    this.included = true,
    this.units = 1,
    this.amount,
  });
  SplitLine copyWith({bool? included, int? units, BigInt? amount}) => SplitLine(
    who,
    included: included ?? this.included,
    units: units ?? this.units,
    amount: amount ?? this.amount,
  );
}

/// What the split editor holds before anything is saved: how to divide,
/// who is in it, who paid and the people added on the way.
class SplitDraft {
  final String method, payer;
  final List<SplitLine> lines;
  final List<Person> added;
  const SplitDraft({
    this.method = 'equal',
    this.payer = me,
    this.lines = const [SplitLine(me)],
    this.added = const [],
  });

  /// A draft from a saved split, every line as it was.
  factory SplitDraft.of(CostSplit x) => SplitDraft(
    method: x.method,
    payer: x.payer,
    lines: [
      for (final p in x.parts)
        SplitLine(
          p.who,
          units: x.method == 'shares' ? p.units : 1,
          amount: p.amount,
        ),
    ],
  );

  SplitDraft copyWith({
    String? method,
    String? payer,
    List<SplitLine>? lines,
    List<Person>? added,
  }) => SplitDraft(
    method: method ?? this.method,
    payer: payer ?? this.payer,
    lines: lines ?? this.lines,
    added: added ?? this.added,
  );

  List<SplitLine> get chosen => [
    for (final l in lines)
      if (l.included) l,
  ];

  /// Everyone's share of [total], exact to the minor unit; throws with the
  /// gap when exact amounts do not add up.
  List<SplitPart> parts(BigInt total) => splitParts(total, method, [
    for (final l in chosen) (l.who, l.units, l.amount),
  ]);

  /// For an exact split: typed amounts less the total (zero when right).
  BigInt gap(BigInt total) =>
      chosen.fold(BigInt.zero, (BigInt n, l) => n + (l.amount ?? BigInt.zero)) -
      total;

  /// The saved split, checked by the engine.
  CostSplit build({
    String? id,
    required BigInt total,
    required String currency,
    required String date,
    required String name,
    String? entry,
    String? category,
  }) => CostSplit(
    id: id ?? newId(),
    payer: payer,
    currency: currency,
    date: date,
    name: name,
    method: method,
    total: total,
    parts: parts(total),
    entry: payer == me ? entry : null,
    category: category,
  );
}

/// [s] with the entry [e] saved, [add] receipts attached, [remove] taken
/// off, and its split replaced by [split] (or dropped when [dropSplit]),
/// people added in the split editor included: one change, one Undo.
SpendState applyEntry(
  SpendState s,
  Entry e, {
  List<Receipt> add = const [],
  Set<String> remove = const {},
  CostSplit? split,
  bool dropSplit = false,
  List<Person> people = const [],
}) => s.copy({
  'entries': [
    for (final x in s.entries)
      if (x.id != e.id) x.toJson(),
    e.toJson(),
  ],
  'receipts': [
    for (final r in s.receipts)
      if (!remove.contains(r.id)) r.toJson(),
    ...add.map((r) => r.toJson()),
  ],
  'people': [
    ...s.people.map((p) => p.toJson()),
    for (final p in people)
      if (!s.people.any((x) => x.id == p.id)) p.toJson(),
  ],
  'splits': [
    for (final x in s.splits)
      if (x.entry != e.id || !(dropSplit || split != null)) x.toJson(),
    ?split?.toJson(),
  ],
});
