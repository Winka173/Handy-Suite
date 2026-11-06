import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../library/results_view.dart';
import '../scope.dart';
import 'rename.dart';
import 'share_item.dart';

/// The "…" on a card or a row: Open details first, then Rename, Share,
/// Move and Delete. Keeps the `details-<id>` key the list always had.
class ItemMenuButton extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onDetails;
  final double width, height;
  const ItemMenuButton({
    super.key,
    required this.bookmark,
    required this.onDetails,
    this.width = 48,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final b = bookmark;
    // The list that shows this item owns the actions on it.
    SaveScope? scope() =>
        context.findAncestorWidgetOfExactType<ResultsView>()?.scope;
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label, {
      bool danger = false,
    }) => PopupMenuItem<String>(
      key: Key('item-$value'),
      value: value,
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 20, color: danger ? p.danger : p.muted),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: danger ? p.danger : p.ink),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: width,
      height: height,
      child: PopupMenuButton<String>(
        key: Key('details-${b.id}'),
        tooltip: tr(context, 'More for this item', 'Thao tác với mục này'),
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: Icon(Icons.more_horiz, color: p.muted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
        ),
        onSelected: (value) {
          final s = scope();
          final current = s?.find(b.id) ?? b;
          switch (value) {
            case 'details':
              onDetails();
            case 'rename':
              s?.rename(context, current);
            case 'share':
              s?.shareItem(context, current);
            case 'move':
              s?.move(context, current);
            case 'delete':
              s?.delete(context, current);
          }
        },
        itemBuilder: (context) => [
          item(
            'details',
            Icons.article_outlined,
            tr(context, 'Open details', 'Xem chi tiết'),
          ),
          if (scope() != null) ...[
            item(
              'rename',
              Icons.drive_file_rename_outline,
              tr(context, 'Rename', 'Đổi tên'),
            ),
            if (b.hasUrl || b.isImage)
              item(
                'share',
                Icons.ios_share_rounded,
                tr(context, 'Share', 'Chia sẻ'),
              ),
            item(
              'move',
              Icons.drive_file_move_outline,
              tr(context, 'Move', 'Chuyển'),
            ),
            item(
              'delete',
              Icons.delete_outline,
              tr(context, 'Delete', 'Xóa'),
              danger: true,
            ),
          ],
        ],
      ),
    );
  }
}
