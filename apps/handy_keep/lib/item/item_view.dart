import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show today;
import '../inventory/whereabouts.dart' show itemHue;
import '../scope.dart';
import '../ui/words.dart';
import 'receipts_view.dart';
import 'where_panel.dart';

/// One item: where it is now (the answer), then its dates, receipts and
/// notes. [onClosed] runs after the item is deleted.
class ItemView extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset item;
  final VoidCallback onClosed;
  final bool hero;
  const ItemView({
    this.hero = false,
    super.key,
    required this.scope,
    required this.item,
    required this.onClosed,
  });

  int _days(String date) => DateTime.parse(
    '${date}T00:00:00Z',
  ).difference(DateTime.parse('${today()}T00:00:00Z')).inDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = item;
    final runOut = runOutFor(scope.state, a);
    String dated(String d, String kind) =>
        '${formatDay(context, d)} · ${dueWhen(context, kind, _days(d))}';
    final facts = [
      if (a.purchasedOn.isNotEmpty)
        (
          tr(context, 'Bought on', 'Ngày mua'),
          formatDay(context, a.purchasedOn),
        ),
      if (a.price.isNotEmpty)
        (tr(context, 'Price paid', 'Giá mua'), priceOf(context, a)),
      if (a.warrantyUntil.isNotEmpty)
        (
          tr(context, 'Warranty until', 'Bảo hành đến'),
          dated(a.warrantyUntil, 'warranty'),
        ),
      if (a.maintenanceDue.isNotEmpty)
        (
          tr(context, 'Next service', 'Bảo dưỡng lần tới'),
          dated(a.maintenanceDue, 'maintenance'),
        ),
      if (a.serial.isNotEmpty) (tr(context, 'Serial', 'Số serial'), a.serial),
    ];
    return Column(
      key: const Key('item-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ItemThumb(
              a,
              scope.store.library!.blobs,
              size: 56,
              hero: hero,
              hue: itemHue(scope.state, a),
            ),
            const SizedBox(width: HandySpace.l),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(a.name, style: theme.textTheme.headlineSmall),
              ),
            ),
            IconButton(
              key: const Key('item-edit'),
              tooltip: tr(context, 'Edit', 'Sửa'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => scope.edit(context, item: a),
            ),
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.add_shopping_cart,
                  tr(context, 'Bought again today', 'Vừa mua thêm hôm nay'),
                  () => scope.restock(context, a),
                  key: const Key('item-restock-menu'),
                ),
                HandyMenuItem(
                  Icons.straighten,
                  tr(context, 'Measure from a photo', 'Đo bằng ảnh'),
                  () => scope.measure(context, a),
                  key: const Key('item-measure'),
                ),
                HandyMenuItem(
                  Icons.qr_code_2,
                  tr(context, 'Label and record', 'Nhãn QR và hồ sơ'),
                  () => scope.label(context, InventoryLabel('item', a.id)),
                  key: const Key('item-label'),
                ),
                HandyMenuItem(
                  Icons.delete_outline,
                  tr(context, 'Delete', 'Xóa'),
                  () async {
                    if (await scope.delete(context, a)) onClosed();
                  },
                  key: const Key('item-delete'),
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        WherePanel(scope: scope, item: a),
        if (facts.isNotEmpty) ...[
          HandyLabel(tr(context, 'Details', 'Thông tin')),
          HandyGroup(
            children: [
              // A small grey label over the value, which reads in ink.
              for (final (label, value) in facts)
                ListTile(
                  title: Text(label, style: theme.textTheme.bodySmall),
                  subtitle: Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFeatures: tabular,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (a.restocks.isNotEmpty || runOut != null) ...[
          HandyLabel(tr(context, 'Buying it again', 'Mua lại')),
          HandyGroup(
            children: [
              ListTile(
                key: const Key('item-runout'),
                title: Text(
                  runOut == null
                      ? tr(
                          context,
                          'One more purchase and Keep can tell',
                          'Thêm một lần mua nữa là Keep đoán được',
                        )
                      : tr(
                          context,
                          'Likely to run out ${formatDay(context, runOut.expected)}',
                          'Có lẽ hết khoảng ${formatDay(context, runOut.expected)}',
                        ),
                ),
                subtitle: Text(
                  runOut == null
                      ? tr(
                          context,
                          'Tap "Bought again" each time you buy it, not each time you use it.',
                          'Chạm "Vừa mua thêm" mỗi lần mua, không cần mỗi lần dùng.',
                        )
                      : tr(
                          context,
                          'Bought again about every ${runOut.every} days · ${runOut.purchases} purchases so far',
                          'Thường mua lại sau khoảng ${runOut.every} ngày · đã mua ${runOut.purchases} lần',
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  HandySpace.l,
                  0,
                  HandySpace.l,
                  HandySpace.m,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: const Key('item-restock'),
                    onPressed: () => scope.restock(context, a),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: Text(tr(context, 'Bought again', 'Vừa mua thêm')),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (a.receipts.isNotEmpty) ReceiptsView(scope: scope, item: a),
        if (a.notes.isNotEmpty) ...[
          HandyLabel(tr(context, 'Notes', 'Ghi chú')),
          HandyGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: SelectableText(a.notes),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
