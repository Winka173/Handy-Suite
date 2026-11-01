import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show today;
import '../inventory/whereabouts.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'attention_strip.dart';
import 'box_actions.dart';
import 'empty_list.dart';
import 'filter_bar.dart';
import 'place_section.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state;
    final found = findItems(s, query.text);
    final groups = places(s, found);
    final searching = query.text.trim().isNotEmpty;
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
              itemCount(context, s.assets.length),
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
