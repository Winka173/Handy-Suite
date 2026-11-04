import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show today;
import '../inventory/whereabouts.dart';
import '../scope.dart';
import '../ui/words.dart';
import '../collections/shelf.dart';
import 'attention_strip.dart';
import 'box_actions.dart';
import 'empty_list.dart';
import 'filter_bar.dart';
import 'place_section.dart';
import 'value_summary.dart';

/// Search, the day's finding, and every item under the place it is in.
class ListPane extends StatelessWidget {
  final KeepScope scope;
  final TextEditingController query;
  final FocusNode searchFocus;
  final KeepFilter filter;
  final String? box, selected;
  final bool wide;
  final ValueChanged<KeepFilter> onFilter;
  final ValueChanged<String?> onBox;
  final ValueChanged<String> onOpen;
  const ListPane({
    super.key,
    required this.scope,
    required this.query,
    required this.searchFocus,
    required this.filter,
    required this.onFilter,
    required this.onBox,
    required this.onOpen,
    this.box,
    this.selected,
    this.wide = false,
  });

  List<Place> places(KeepState s, List<InventoryAsset> found) {
    if (box != null) {
      return whereabouts(
        s,
        found.where((a) => a.boxId == box),
        emptyBoxes: true,
        byBox: true,
      ).where((p) => p.box?.id == box).toList();
    }
    return switch (filter) {
      KeepFilter.all => whereabouts(
        s,
        found,
        emptyBoxes: query.text.trim().isEmpty,
      ),
      KeepFilter.lent => whereabouts(
        s,
        found.where((a) => a.borrower.isNotEmpty),
      ),
      KeepFilter.boxes => whereabouts(
        s,
        found.where((a) => a.boxId.isNotEmpty),
        emptyBoxes: query.text.trim().isEmpty,
        byBox: true,
      ),
      KeepFilter.loose => whereabouts(s, found.where((a) => a.boxId.isEmpty)),
    };
  }

  /// What the value line adds up, in the words of the current view.
  String viewLabel(BuildContext context, List<Place> groups, int count) {
    final n = itemCount(context, count);
    if (query.text.trim().isNotEmpty) {
      return tr(context, 'Found · $n', 'Tìm thấy · $n');
    }
    if (box != null) return tr(context, 'In this box · $n', 'Trong thùng · $n');
    final boxes = groups.where((p) => p.box != null).length;
    return switch (filter) {
      KeepFilter.all => tr(context, 'Total value', 'Tổng giá trị'),
      KeepFilter.lent => tr(context, 'Out on loan · $n', 'Đang cho mượn · $n'),
      KeepFilter.boxes => tr(
        context,
        boxes == 1 ? 'Packed in 1 box · $n' : 'Packed in $boxes boxes · $n',
        'Trong $boxes thùng · $n',
      ),
      KeepFilter.loose => tr(
        context,
        'Not in a box · $n',
        'Chưa vào thùng · $n',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state;
    // Wanted and ordered items are not anywhere yet: they live in their
    // collections and the wishlist, not under a place.
    final found = findItems(s, query.text).where((a) => a.owned).toList();
    final groups = places(s, found);
    final searching = query.text.trim().isNotEmpty;
    final shown = [for (final p in groups) ...p.items];
    // Values show once anything has a price; until then, no nagging.
    final priced = valueOf(s.assets).hasPrices;
    final packing = filter == KeepFilter.boxes || box != null;
    final due = !searching && filter == KeepFilter.all && box == null
        ? attention(s, today())
        : const <DueItem>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  tr(context, 'Things at home', 'Đồ trong nhà'),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
            Text(
              itemCount(context, s.assets.where((a) => a.owned).length),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
            if (wide) ...[
              const SizedBox(width: HandySpace.l),
              FilledButton.icon(
                key: const Key('item-new'),
                onPressed: () => scope.edit(context, box: box ?? ''),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Add item', 'Thêm đồ')),
              ),
            ],
            const SizedBox(width: HandySpace.xs),
            HandyMenuButton(
              key: const Key('keep-list-menu'),
              tooltip: tr(context, 'More for this list', 'Thêm cho danh sách'),
              items: [
                HandyMenuItem(
                  Icons.add_photo_alternate_outlined,
                  tr(context, 'Add from photos', 'Thêm từ ảnh'),
                  () => scope.batchAdd(context, box: box ?? ''),
                  key: const Key('batch-add'),
                ),
                HandyMenuItem(
                  Icons.table_view_outlined,
                  searching || filter != KeepFilter.all || box != null
                      ? tr(
                          context,
                          'Save these ${shown.length} as CSV',
                          'Lưu ${shown.length} món này ra CSV',
                        )
                      : tr(
                          context,
                          'Save the list as CSV',
                          'Lưu danh sách ra CSV',
                        ),
                  shown.isEmpty ? null : () => scope.exportCsv(context, shown),
                  key: const Key('export-csv'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        TextField(
          key: const Key('keep-search'),
          controller: query,
          focusNode: searchFocus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr(
              context,
              'Find a thing, a place or a person',
              'Tìm món đồ, chỗ để hay người mượn',
            ),
            suffixIcon: searching
                ? IconButton(
                    tooltip: tr(context, 'Clear search', 'Xóa tìm kiếm'),
                    icon: const Icon(Icons.close),
                    onPressed: query.clear,
                  )
                : null,
          ),
        ),
        if (s.assets.isNotEmpty || s.boxes.isNotEmpty) ...[
          const SizedBox(height: HandySpace.m),
          FilterBar(
            state: s,
            filter: filter,
            box: box,
            onFilter: onFilter,
            onClearBox: () => onBox(null),
          ),
        ],
        if (!searching && filter == KeepFilter.all && box == null)
          CollectionShelf(scope: scope),
        if (priced && s.assets.isNotEmpty)
          ValueSummary(
            label: viewLabel(context, groups, shown.length),
            value: valueOf(shown),
            lead: packing || filter == KeepFilter.lent,
          ),
        HandyReveal(
          // Wide screens show every date in the empty pane instead.
          child: due.isEmpty || wide
              ? const SizedBox(width: double.infinity)
              : AttentionStrip(
                  due: due,
                  onOpen: onOpen,
                  onAll: () => Navigator.pushNamed(context, '/due'),
                ),
        ),
        // A new view (filter or box) fades in; typing a search does not.
        HandySwap(
          child: Column(
            key: ValueKey('${filter.name}-$box'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (groups.isEmpty) ...[
                const SizedBox(height: HandySpace.xl),
                emptyList(context, scope, filter, query.text.trim(), searching),
              ],
              for (final p in groups)
                PlaceSection(
                  key: ValueKey(p.key),
                  place: p,
                  hue: placeHue(s, p.key),
                  // Packing shows every box's worth, even "no price yet";
                  // elsewhere only places with a price say anything.
                  value: !priced || p.items.isEmpty
                      ? null
                      : switch (valueOf(p.items)) {
                          final v when packing || v.hasPrices => v,
                          _ => null,
                        },
                  blobs: scope.store.library!.blobs,
                  selected: selected,
                  onOpen: (a) => onOpen(a.id),
                  onFocusBox: box == null ? (b) => onBox(b.id) : null,
                  boxActions: (b) => boxActions(
                    context,
                    scope,
                    b,
                    onDeleted: () {
                      if (box == b.id) onBox(null);
                    },
                  ),
                  hero: !wide,
                ),
            ],
          ),
        ),
        if (filter == KeepFilter.boxes && box == null && !searching) ...[
          const SizedBox(height: HandySpace.xl),
          OutlinedButton.icon(
            key: const Key('box-new'),
            onPressed: () => scope.editBox(context),
            icon: const Icon(Icons.add_box_outlined),
            label: Text(tr(context, 'Add a box', 'Thêm thùng')),
          ),
        ],
      ],
    );
  }
}
