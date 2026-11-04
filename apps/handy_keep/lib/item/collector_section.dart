import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import 'asset_editor.dart';

/// Collections, wishlist state and collector fields. Shown only when the
/// person has a collection or the item is not owned, so a household item's
/// form stays as short as before.
class CollectorSection extends StatelessWidget {
  final AssetEditorState editor;
  const CollectorSection({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final e = editor;
    final collections = e.widget.collections;
    if (collections.isEmpty && e.status == 'owned') {
      return const SizedBox.shrink();
    }
    final kinds = {
      for (final c in collections)
        if (e.collectionIds.contains(c.id)) keepCollectionKind(c.kind),
    };
    final ownKeys = {for (final k in kinds) ...k.fields.keys, ...e.own.keys};
    String ownLabel(String key) {
      for (final k in kinds) {
        if (k.fields[key] case (final en, final vi)) return tr(context, en, vi);
      }
      return key;
    }

    Widget text(String key, String label, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(top: HandySpace.l),
      child: HandyField(
        label: label,
        child: TextField(
          key: Key('item-$key'),
          controller: c,
          enabled: !e.locked,
          maxLength: key == 'link' ? 2000 : 200,
          onChanged: (_) => e.touch(() {}),
          decoration: const InputDecoration(counterText: ''),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (collections.isNotEmpty) ...[
          HandyLabel(tr(context, 'Collections', 'Bộ sưu tập')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final c in collections)
                FilterChip(
                  key: Key('item-collection-${c.id}'),
                  label: Text(c.name),
                  selected: e.collectionIds.contains(c.id),
                  onSelected: e.locked
                      ? null
                      : (on) => e.touch(
                          () => on
                              ? e.collectionIds.add(c.id)
                              : e.collectionIds.remove(c.id),
                        ),
                ),
            ],
          ),
        ],
        if (e.collectionIds.isNotEmpty || e.status != 'owned') ...[
          const SizedBox(height: HandySpace.l),
          SegmentedButton<String>(
            key: const Key('item-status'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'owned',
                label: Text(tr(context, 'Have it', 'Đã có')),
              ),
              ButtonSegment(
                value: 'ordered',
                label: Text(tr(context, 'On order', 'Đang đặt')),
              ),
              ButtonSegment(
                value: 'wanted',
                label: Text(tr(context, 'Want it', 'Muốn có')),
              ),
            ],
            selected: {e.status},
            onSelectionChanged: e.locked
                ? null
                : (v) => e.touch(() => e.status = v.first),
          ),
        ],
        if (e.status != 'owned') ...[
          const SizedBox(height: HandySpace.l),
          HandyField(
            label: tr(context, 'Priority', 'Mức ưu tiên'),
            child: DropdownButtonFormField<String>(
              key: const Key('item-priority'),
              initialValue: e.priority,
              isExpanded: true,
              items: [
                for (final (v, en, vi) in const [
                  ('', 'None', 'Không đặt'),
                  ('high', 'High', 'Cao'),
                  ('medium', 'Medium', 'Vừa'),
                  ('low', 'Low', 'Thấp'),
                ])
                  DropdownMenuItem(value: v, child: Text(tr(context, en, vi))),
              ],
              onChanged: e.locked
                  ? null
                  : (v) => e.touch(() => e.priority = v ?? ''),
            ),
          ),
          text(
            'budget',
            tr(
              context,
              'Budget (${e.currency})',
              'Ngân sách (${e.currency == 'VND' ? 'đ' : e.currency})',
            ),
            e.budget,
          ),
          text(
            'link',
            tr(context, 'Where to find it', 'Mua ở đâu (link)'),
            e.link,
          ),
        ],
        if (e.collectionIds.isNotEmpty) ...[
          HandyLabel(tr(context, 'Collector details', 'Thông tin sưu tầm')),
          for (final (key, en, vi) in const [
            ('series', 'Series', 'Dòng / series'),
            ('number', 'Number in the series', 'Số trong dòng'),
          ])
            text(key, tr(context, en, vi), e.collector[key]!),
          if (!e.moreCollector)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('item-more-collector'),
                  onPressed: () => e.touch(() => e.moreCollector = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    tr(
                      context,
                      'More collector details',
                      'Thêm thông tin sưu tầm',
                    ),
                  ),
                ),
              ),
            )
          else ...[
            for (final (key, en, vi) in const [
              ('variant', 'Variant', 'Phiên bản'),
              ('edition', 'Edition', 'Lần phát hành'),
              ('condition', 'Condition', 'Tình trạng'),
            ])
              text(key, tr(context, en, vi), e.collector[key]!),
            for (final key in ownKeys)
              text('own-$key', ownLabel(key), e.ownField(key)),
          ],
        ],
      ],
    );
  }
}
