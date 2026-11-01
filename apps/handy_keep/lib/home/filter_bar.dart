import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';

enum KeepFilter { all, lent, boxes, loose }

/// One row of chips: what to show. A box opened from its label or heading
/// replaces them with a chip that clears it.
class FilterBar extends StatelessWidget {
  final KeepState state;
  final KeepFilter filter;
  final String? box;
  final ValueChanged<KeepFilter> onFilter;
  final VoidCallback onClearBox;
  const FilterBar({
    super.key,
    required this.state,
    required this.filter,
    required this.onFilter,
    required this.onClearBox,
    this.box,
  });
  @override
  Widget build(BuildContext context) {
    if (box != null) {
      final name =
          state.boxes.where((b) => b.id == box).firstOrNull?.name ?? '';
      return Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const Key('box-filter'),
          label: Text(tr(context, 'Only $name', 'Chỉ $name')),
          onDeleted: onClearBox,
          deleteButtonTooltipMessage: tr(
            context,
            'Show everything',
            'Hiện tất cả',
          ),
        ),
      );
    }
    final lent = state.assets.where((a) => a.borrower.isNotEmpty).length;
    final chips = [
      (KeepFilter.all, tr(context, 'All', 'Tất cả')),
      (
        KeepFilter.lent,
        tr(context, 'Lent out', 'Đang cho mượn') + (lent > 0 ? ' $lent' : ''),
      ),
      (KeepFilter.boxes, tr(context, 'By box', 'Theo thùng')),
      (KeepFilter.loose, tr(context, 'Not in a box', 'Chưa vào thùng')),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (f, label) in chips)
            Padding(
              padding: const EdgeInsets.only(right: HandySpace.s),
              child: ChoiceChip(
                key: Key('filter-${f.name}'),
                label: Text(label),
                selected: filter == f,
                showCheckmark: false,
                onSelected: (_) => onFilter(f),
              ),
            ),
        ],
      ),
    );
  }
}
