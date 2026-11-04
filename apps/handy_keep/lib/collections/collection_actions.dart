import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart';
import '../scope.dart';
import 'collection_dialog.dart';

/// Sample data uses this id prefix, so it can be told apart and removed
/// whole; it is never mixed into the person's own ids.
const keepSamplePrefix = 'sample-';
bool isSample(String id) => id.startsWith(keepSamplePrefix);

String kindLabel(BuildContext context, String kind) {
  final k = keepCollectionKind(kind);
  return tr(context, k.en, k.vi);
}

/// "7 owned · 2 on order · 3 wanted", leaving out the zero parts.
String completionLine(BuildContext context, KeepCompletion c) => [
  tr(context, '${c.owned} owned', '${c.owned} đã có'),
  if (c.ordered > 0)
    tr(context, '${c.ordered} on order', '${c.ordered} đang đặt'),
  if (c.wanted > 0) tr(context, '${c.wanted} wanted', '${c.wanted} muốn có'),
].join(' · ');

extension KeepCollections on KeepScope {
  Future<InventoryCollection?> editCollection(
    BuildContext context, {
    InventoryCollection? old,
  }) async {
    final next = await showDialog<InventoryCollection>(
      context: context,
      builder: (_) => CollectionDialog(
        old: old,
        hue: state.collections.length % HandyPalette.count,
      ),
    );
    if (next == null || !context.mounted) return null;
    try {
      await store.commit(saveCollection(state, next));
      return next;
    } catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
      return null;
    }
  }

  /// Removes a collection after a confirmation. Its items stay.
  Future<bool> deleteCollection(
    BuildContext context,
    InventoryCollection c,
  ) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Remove "${c.name}"?', 'Bỏ bộ "${c.name}"?'),
      message: tr(
        context,
        'Its items stay in Keep; they only leave this collection.',
        'Các món vẫn ở trong Keep; chỉ rời khỏi bộ này.',
      ),
      confirmLabel: tr(context, 'Remove', 'Bỏ bộ'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    try {
      await store.commit(removeCollection(state, c.id));
      return true;
    } catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
      return false;
    }
  }

  /// A wanted or ordered item has arrived: the same record, owned today.
  Future<void> gotIt(BuildContext context, InventoryAsset item) async {
    try {
      await store.commit(
        markOwned(state, item.id, purchasedOn: today(), now: timestamp()),
      );
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            '${item.name} is yours now. Add the price or a photo any time.',
            '${item.name} giờ là của bạn. Thêm giá hay ảnh lúc nào cũng được.',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
    }
  }

  /// A small collection to try the screens with, removable in one go.
  Future<void> addSample(BuildContext context) async {
    const id = '${keepSamplePrefix}games';
    if (state.collections.any((c) => c.id == id)) return;
    final at = timestamp();
    final vi = tr(context, 'en', 'vi') == 'vi';
    var next = saveCollection(
      state,
      InventoryCollection(
        id: id,
        name: vi ? 'Board game ở nhà (mẫu)' : 'Board games at home (sample)',
        kind: 'board-games',
        hue: state.collections.length % HandyPalette.count,
        target: 6,
      ),
    );
    final items = [
      ('chess', vi ? 'Cờ tướng gỗ' : 'Xiangqi, wooden set', 'owned', '2'),
      ('go', vi ? 'Cờ vây 19×19' : 'Go board 19×19', 'owned', '2'),
      ('domino', vi ? 'Domino 28 quân' : 'Dominoes, 28 tiles', 'owned', '2–4'),
      ('cards', vi ? 'Bộ bài tây mới' : 'A new deck of cards', 'wanted', '2–8'),
    ];
    next = saveAssets(next, [
      for (final (key, name, status, players) in items)
        createAsset(
          id: '$keepSamplePrefix$key',
          name: name,
          now: at,
          fields: {
            'profile': 'collectible',
            'status': status,
            'collections': [id],
            'fields': {'players': players},
            if (status == 'owned')
              'location': vi ? 'Kệ phòng khách' : 'Living room shelf',
          },
        ),
    ]);
    try {
      await store.commit(next);
    } catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
    }
  }

  /// Removes every sample item and collection; the person's own stay.
  Future<void> removeSample(BuildContext context) async {
    var next = state;
    for (final a in next.assets.where((a) => isSample(a.id)).toList()) {
      next = removeAsset(next, a.id);
    }
    for (final c in next.collections.where((c) => isSample(c.id)).toList()) {
      next = removeCollection(next, c.id);
    }
    try {
      await store.commit(next);
    } catch (e) {
      if (context.mounted) showHandyMessage(context, errorText(context, e));
    }
  }
}
