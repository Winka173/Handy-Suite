import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';

/// Categories for spending and for income, sub-categories under their
/// parent. Each keeps one colour everywhere.
class CategoriesPage extends StatelessWidget {
  final SpendScope scope;
  const CategoriesPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final all = scope.state.categories;
      List<Widget> group(String kind) {
        final roots = all.where((c) => c.kind == kind && c.parent == null);
        return [
          for (final r in roots) ...[
            _tile(context, r, 0),
            for (final child in all.where((c) => c.parent == r.id))
              _tile(context, child, 1),
          ],
          for (final orphan in all.where(
            (c) =>
                c.kind == kind &&
                c.parent != null &&
                !all.any((p) => p.id == c.parent),
          ))
            _tile(context, orphan, 0),
        ];
      }

      final spend = group('expense'), income = group('income');
      return HandyPage(
        title: tr(context, 'Categories', 'Danh mục'),
        actions: [
          IconButton(
            key: const Key('category-add'),
            tooltip: tr(context, 'Add category', 'Thêm danh mục'),
            onPressed: () => openCategoryEditor(context, scope),
            icon: const Icon(Icons.add),
          ),
        ],
        children: [
          HandySection(
            title: tr(context, 'Spending', 'Chi'),
            children: spend.isEmpty ? [_none(context)] : spend,
          ),
          HandySection(
            title: tr(context, 'Income', 'Thu'),
            children: income.isEmpty ? [_none(context)] : income,
          ),
        ],
      );
    },
  );

  Widget _none(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HandySpace.l),
    child: Text(tr(context, 'None yet.', 'Chưa có.')),
  );

  Widget _tile(BuildContext context, Category c, int depth) => ListTile(
    key: Key('category-row-${c.id}'),
    contentPadding: EdgeInsetsDirectional.only(
      start: HandySpace.l + depth * HandySpace.xl,
      end: HandySpace.l,
    ),
    leading: HandyDot(scope.categoryHue(c.id), size: 10),
    minLeadingWidth: 12,
    title: Text(
      c.name,
      style: TextStyle(
        color: c.archived ? HandyColors.of(context).muted : null,
      ),
    ),
    subtitle: c.archived ? Text(tr(context, 'archived', 'đã lưu trữ')) : null,
    onTap: () => openCategoryEditor(context, scope, c),
  );
}

Future<bool> openCategoryEditor(
  BuildContext context,
  SpendScope scope, [
  Category? x,
]) {
  final s = scope.state;
  return showSpendForm(
    context,
    scope,
    title: x == null ? tr(context, 'New category', 'Danh mục mới') : x.name,
    fields: [
      const SpendField('name', 'Name', 'Tên'),
      SpendField(
        'kind',
        'For',
        'Dùng cho',
        kind: FieldKind.choice,
        options: {
          'expense': kindLabel(context, 'expense'),
          'income': kindLabel(context, 'income'),
        },
      ),
      SpendField(
        'parent',
        'Inside',
        'Nằm trong',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(
            context,
            'Nothing, it is a main category',
            'Không, đây là danh mục chính',
          ),
          for (final p in s.categories.where(
            (p) => p.id != x?.id && p.parent == null,
          ))
            p.id: p.name,
        },
      ),
      if (x != null)
        const SpendField(
          'archived',
          'Archive',
          'Lưu trữ',
          kind: FieldKind.toggle,
          helpEn: 'Hidden when recording; past entries keep it.',
          helpVi: 'Ẩn khi ghi mới; giao dịch cũ vẫn giữ.',
        ),
    ],
    initial: {
      'name': x?.name ?? '',
      'kind': x?.kind ?? 'expense',
      'parent': x?.parent ?? '',
      'archived': x?.archived ?? false,
    },
    save: (v) async {
      final next = Category(
        id: x?.id ?? newId(),
        name: v['name'] as String,
        kind: v['kind'] as String,
        parent: (v['parent'] as String).isEmpty ? null : v['parent'] as String,
        // Colour and icon are kept as they were; the app draws identity
        // from the category's place in the list.
        color: x?.color ?? '#3A6FD8',
        icon: x?.icon ?? 'category',
        archived: v['archived'] == true,
      );
      await scope.controller.change(
        (s) => s.copy({
          'categories': [
            for (final a in s.categories)
              if (a.id != next.id) a.toJson(),
            next.toJson(),
          ],
        }),
        'save_category',
      );
    },
  );
}
