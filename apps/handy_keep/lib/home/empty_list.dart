import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'filter_bar.dart';

/// What an empty list says: no match (add it), nothing yet (start with a
/// box), or a filter with nothing in it.
Widget emptyList(
  BuildContext context,
  KeepScope scope,
  KeepFilter filter,
  String name,
  bool searching,
) {
  if (searching) {
    return HandyEmpty(
      title: tr(context, 'Nothing called “$name”', 'Không thấy “$name”'),
      message: tr(
        context,
        'Search looks at names, places, boxes, borrowers and notes.',
        'Tìm theo tên, chỗ để, thùng, người mượn và ghi chú.',
      ),
      action: FilledButton.tonal(
        key: const Key('add-from-search'),
        onPressed: () => scope.edit(context, name: name),
        child: Text(tr(context, 'Add “$name”', 'Thêm “$name”')),
      ),
    );
  }
  return switch (filter) {
    KeepFilter.all when scope.state.assets.isEmpty => HandyEmpty(
      title: tr(
        context,
        'Write down the first thing and where it lives',
        'Ghi lại món đầu tiên và chỗ cất nó',
      ),
      message: tr(
        context,
        'Moving house? Start with the boxes, then pack things into them.',
        'Sắp chuyển nhà? Tạo thùng trước rồi xếp đồ vào.',
      ),
      // "Add item" is already the screen's one filled button.
      action: OutlinedButton(
        key: const Key('add-first-box'),
        onPressed: () => scope.editBox(context),
        child: Text(tr(context, 'Add a box', 'Thêm thùng')),
      ),
    ),
    KeepFilter.lent => HandyEmpty(
      title: tr(
        context,
        'Nothing is lent out.',
        'Không có món nào đang cho mượn.',
      ),
    ),
    KeepFilter.boxes => HandyEmpty(
      title: tr(context, 'No boxes yet.', 'Chưa có thùng nào.'),
    ),
    _ => HandyEmpty(
      title: tr(
        context,
        'Everything is in a box.',
        'Món nào cũng đã vào thùng.',
      ),
    ),
  };
}
