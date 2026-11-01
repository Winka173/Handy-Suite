import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/form.dart';

/// "Payee contains … → category". Used when recording and importing; the
/// first rule that matches wins, and every import is reviewed first.
class RulesPage extends StatelessWidget {
  final SpendScope scope;
  const RulesPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final rules = scope.state.rules;
      return HandyPage(
        title: tr(context, 'Category rules', 'Quy tắc danh mục'),
        subtitle: tr(
          context,
          'The first rule whose words appear in the payee picks the category.',
          'Quy tắc đầu tiên có chữ khớp với đối tác sẽ chọn danh mục.',
        ),
        actions: [
          IconButton(
            key: const Key('rule-add'),
            tooltip: tr(context, 'Add rule', 'Thêm quy tắc'),
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
          ),
        ],
        children: [
          HandySection(
            children: [
              if (rules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: Text(
                    tr(
                      context,
                      'No rules yet. Example: "Grab" → Getting around.',
                      'Chưa có quy tắc. Ví dụ: "Grab" → Đi lại.',
                    ),
                  ),
                ),
              for (final r in rules)
                ListTile(
                  key: Key('rule-${r['id']}'),
                  title: Text('"${r['contains']}"'),
                  subtitle: Text(
                    '→ ${scope.category(r['category'] as String?)?.name ?? tr(context, 'missing category', 'danh mục không còn')}',
                  ),
                  trailing: IconButton(
                    tooltip: tr(context, 'Delete rule', 'Xóa quy tắc'),
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => scope.write(
                      context,
                      () => scope.controller.change(
                        (s) => s.copy({
                          'rules': [
                            for (final x in s.rules)
                              if (x['id'] != r['id']) x,
                          ],
                        }),
                        'delete_rule',
                      ),
                      done: (c) => tr(c, 'Rule deleted.', 'Đã xóa quy tắc.'),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _add(BuildContext context) => showSpendForm(
    context,
    scope,
    title: tr(context, 'New rule', 'Quy tắc mới'),
    fields: [
      const SpendField(
        'contains',
        'When the payee contains',
        'Khi đối tác có chữ',
        helpEn: 'Accents and case do not matter.',
        helpVi: 'Không phân biệt dấu và chữ hoa.',
      ),
      SpendField(
        'category',
        'Use the category',
        'Dùng danh mục',
        kind: FieldKind.choice,
        options: {
          for (final c in scope.state.categories.where((c) => !c.archived))
            c.id: c.name,
        },
      ),
    ],
    initial: {'contains': '', 'category': ''},
    save: (v) => scope.controller.change(
      (s) => s.copy({
        'rules': [
          ...s.rules,
          {
            'id': newId(),
            'contains': (v['contains'] as String).trim(),
            'category': v['category'],
          },
        ],
      }),
      'save_rule',
    ),
  );
}
