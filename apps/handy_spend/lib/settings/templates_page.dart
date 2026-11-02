import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';

/// How a template reads a file, in a line: columns, dates, marks, signs.
String templateSummary(BuildContext context, Map<String, dynamic> t) {
  final m = StatementMapping.fromJson(
    Map<String, dynamic>.from(t['mapping'] as Map),
  );
  final headers = List<String>.from(t['headers'] as List);
  String col(int i) => i < 0 || i >= headers.length ? '—' : headers[i];
  final dates = switch (m.dateFormat) {
    'dmy' => 'DD/MM/YYYY',
    'mdy' => 'MM/DD/YYYY',
    'excel' => tr(context, 'Excel day numbers', 'số ngày Excel'),
    _ => 'YYYY-MM-DD',
  };
  return [
    tr(context, '${headers.length} columns', '${headers.length} cột'),
    tr(context, 'date “${col(m.date)}”', 'ngày “${col(m.date)}”'),
    m.amount >= 0
        ? tr(context, 'amount “${col(m.amount)}”', 'số tiền “${col(m.amount)}”')
        : tr(
            context,
            'out “${col(m.debit)}”, in “${col(m.credit)}”',
            'ra “${col(m.debit)}”, vào “${col(m.credit)}”',
          ),
    dates,
    tr(context, 'decimal ${m.decimal}', 'thập phân ${m.decimal}'),
    if (m.reverse) tr(context, 'signs flipped', 'đảo dấu'),
  ].join(' · ');
}

/// Saved statement templates: each is found again by its column headers
/// and filled in on the next import with the same headers.
class TemplatesPage extends StatelessWidget {
  final SpendScope scope;
  const TemplatesPage({super.key, required this.scope});

  Future<void> _rename(BuildContext context, Map<String, dynamic> t) =>
      showSpendForm(
        context,
        scope,
        title: tr(context, 'Rename template', 'Đổi tên mẫu'),
        fields: const [SpendField('name', 'Name', 'Tên')],
        initial: {'name': t['name']},
        save: (v) => scope.controller.change(
          (s) => s.copy({
            'profiles': [
              for (final x in s.profiles)
                if (x['id'] == t['id']) {...x, 'name': v['name']} else x,
            ],
          }),
          'rename_template',
        ),
      );

  Future<void> _delete(BuildContext context, Map<String, dynamic> t) =>
      scope.write(
        context,
        () => scope.controller.change(
          (s) => s.copy({
            'profiles': [
              for (final x in s.profiles)
                if (x['id'] != t['id']) x,
            ],
          }),
          'delete_template',
        ),
        done: (c) => tr(
          c,
          'Template “${t['name']}” deleted.',
          'Đã xóa mẫu “${t['name']}”.',
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final list = scope.state.profiles;
      return HandyPage(
        title: tr(context, 'Statement templates', 'Mẫu nhập sao kê'),
        subtitle: tr(
          context,
          'A file with the same column headers is read the same way next time. You can still change anything before importing.',
          'File có cùng tiêu đề cột sẽ được đọc như lần trước. Bạn vẫn sửa được mọi thứ trước khi nhập.',
        ),
        children: [
          if (list.isEmpty)
            HandyEmpty(
              title: tr(context, 'No templates yet', 'Chưa có mẫu nào'),
              message: tr(
                context,
                'Save one on the last step of a statement import.',
                'Lưu mẫu ở bước soát dòng khi nhập sao kê.',
              ),
            )
          else
            HandySection(
              children: [
                for (final t in list)
                  ListTile(
                    key: Key('template-${t['id']}'),
                    title: Text(t['name'] as String),
                    subtitle: Text(templateSummary(context, t)),
                    trailing: HandyMenuButton(
                      items: [
                        HandyMenuItem(
                          Icons.edit_outlined,
                          tr(context, 'Rename', 'Đổi tên'),
                          () => _rename(context, t),
                        ),
                        HandyMenuItem(
                          Icons.delete_outline,
                          tr(context, 'Delete', 'Xóa'),
                          () => _delete(context, t),
                          destructive: true,
                          key: Key('template-delete-${t['id']}'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
