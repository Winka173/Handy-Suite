import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart' show foldAccents;

/// Where a thing is right now, most specific first: with a borrower, packed in
/// a box, at a written location, or nowhere recorded.
enum PlaceKind { borrower, box, location, none }

/// One group of the home list. [key] is stable across rebuilds.
class Place {
  final PlaceKind kind;
  final String key, name;

  /// The box's own location, when the place is a box.
  final String detail;
  final InventoryBox? box;
  final List<InventoryAsset> items;
  const Place(
    this.kind,
    this.key,
    this.name, {
    this.detail = '',
    this.box,
    this.items = const [],
  });
}

/// The place an item belongs to right now. With [byBox], the box wins over
/// a loan (the box view while packing).
Place placeOf(
  InventoryAsset a,
  Map<String, InventoryBox> boxes, {
  bool byBox = false,
}) {
  if (a.borrower.isNotEmpty && !(byBox && boxes.containsKey(a.boxId))) {
    return Place(PlaceKind.borrower, 'with:${_fold(a.borrower)}', a.borrower);
  }
  final box = boxes[a.boxId];
  if (box != null) {
    return Place(
      PlaceKind.box,
      'box:${box.id}',
      box.name,
      detail: box.location,
      box: box,
    );
  }
  if (a.location.isNotEmpty) {
    return Place(PlaceKind.location, 'at:${_fold(a.location)}', a.location);
  }
  return const Place(PlaceKind.none, 'none', '');
}

/// Items grouped by where they are: borrowers, then boxes, then locations,
/// then the unrecorded ones. Names sort without regard to accents.
List<Place> whereabouts(
  KeepState state,
  Iterable<InventoryAsset> items, {
  bool emptyBoxes = false,
  bool byBox = false,
}) {
  final boxes = {for (final b in state.boxes) b.id: b};
  final groups = <String, (Place, List<InventoryAsset>)>{};
  for (final a in items) {
    final p = placeOf(a, boxes, byBox: byBox);
    (groups[p.key] ??= (p, <InventoryAsset>[])).$2.add(a);
  }
  if (emptyBoxes) {
    for (final b in state.boxes) {
      groups['box:${b.id}'] ??= (
        Place(PlaceKind.box, 'box:${b.id}', b.name, detail: b.location, box: b),
        <InventoryAsset>[],
      );
    }
  }
  final result = [
    for (final (p, list) in groups.values)
      Place(
        p.kind,
        p.key,
        p.name,
        detail: p.detail,
        box: p.box,
        items: list..sort((a, b) => _fold(a.name).compareTo(_fold(b.name))),
      ),
  ];
  result.sort((a, b) {
    final kind = a.kind.index.compareTo(b.kind.index);
    return kind != 0 ? kind : _fold(a.name).compareTo(_fold(b.name));
  });
  return result;
}

/// A place's identity colour (`HandyPalette` index). It comes from every
/// place the household has, in the list's own order, so a place keeps its
/// colour whatever the filter or the search shows.
int placeHue(KeepState state, String key) {
  final keys = <String>{
    for (final byBox in [false, true])
      for (final p in whereabouts(
        state,
        state.assets,
        emptyBoxes: true,
        byBox: byBox,
      ))
        p.key,
  }.toList();
  final index = keys.indexOf(key);
  return index < 0 ? 0 : index;
}

/// The colour of where [a] is right now.
int itemHue(KeepState state, InventoryAsset a) =>
    placeHue(state, placeOf(a, {for (final b in state.boxes) b.id: b}).key);

/// Every word of [query] appears in the item, its box or its borrower;
/// accents and case are ignored, so "may khoan" finds "Máy khoan".
List<InventoryAsset> findItems(KeepState state, String query) {
  final words = _fold(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return state.assets;
  final boxes = {for (final b in state.boxes) b.id: b};
  return state.assets.where((a) {
    final b = boxes[a.boxId];
    final hay = _fold(
      [
        a.name,
        a.location,
        a.serial,
        a.borrower,
        a.notes,
        b?.name ?? '',
        b?.location ?? '',
      ].join(' '),
    );
    return words.every(hay.contains);
  }).toList();
}

/// Places already in use, for the location suggestions in the editor.
List<String> knownLocations(KeepState state) {
  final seen = <String, String>{};
  for (final l in [
    ...state.assets.map((a) => a.location),
    ...state.boxes.map((b) => b.location),
  ]) {
    if (l.isNotEmpty) seen.putIfAbsent(_fold(l), () => l);
  }
  return seen.values.toList()..sort((a, b) => _fold(a).compareTo(_fold(b)));
}

/// A dated thing to look at: a return, a warranty end or a service.
class DueItem {
  final InventoryAsset item;
  final String kind, date;

  /// Days from today; negative when it has passed.
  final int days;
  const DueItem(this.item, this.kind, this.date, this.days);
  bool get overdue => days < 0;
}

/// Every dated item, soonest first. [today] is `YYYY-MM-DD`.
List<DueItem> dueItems(KeepState state, String today) {
  final byId = {for (final a in state.assets) a.id: a};
  final base = DateTime.parse('${today}T00:00:00Z');
  int days(String d) =>
      DateTime.parse('${d}T00:00:00Z').difference(base).inDays;
  return [
    for (final r in getKeepReminders(state, today))
      DueItem(byId[r.assetId]!, r.kind, r.date, days(r.date)),
    // Things that get used up, when the purchases so far say so.
    for (final r in runOutEstimates(state))
      DueItem(r.asset, 'runout', r.expected, days(r.expected)),
  ]..sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.item.id.compareTo(b.item.id);
  });
}

/// What needs attention now: anything overdue or within [window] days.
/// A run-out shows from a week before.
List<DueItem> attention(KeepState state, String today, {int window = 30}) =>
    dueItems(
      state,
      today,
    ).where((d) => d.days <= (d.kind == 'runout' ? 7 : window)).toList();

String _fold(String s) => foldAccents(s.toLowerCase());
