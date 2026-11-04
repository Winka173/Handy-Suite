import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'collection_actions.dart';

/// Everything wanted or on order, the highest priority first. Its one job:
/// "it arrived" turns the same record into an owned item.
class WishlistPage extends StatelessWidget {
  final KeepScope scope;
  const WishlistPage({super.key, required this.scope});

  static const _rank = {'high': 0, 'medium': 1, 'low': 2, '': 3};

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) {
      final s = scope.state;
      final names = {for (final c in s.collections) c.id: c.name};
      final items = s.assets.where((a) => !a.owned).toList()
        ..sort((a, b) {
          final p = _rank[a.priority]!.compareTo(_rank[b.priority]!);
          return p != 0 ? p : a.name.compareTo(b.name);
        });
      String line(InventoryAsset a) => [
        a.status == 'ordered'
            ? tr(context, 'On order', 'Đang đặt')
            : tr(context, 'Wanted', 'Muốn có'),
        if (a.priority.isNotEmpty)
          switch (a.priority) {
            'high' => tr(context, 'high priority', 'ưu tiên cao'),
            'medium' => tr(context, 'medium priority', 'ưu tiên vừa'),
            _ => tr(context, 'low priority', 'ưu tiên thấp'),
          },
        if (a.budget.isNotEmpty)
          tr(
            context,
            'budget ${money(context, a.budgetCurrency, a.budget)}',
            'ngân sách ${money(context, a.budgetCurrency, a.budget)}',
          ),
        ...a.collections.map((c) => names[c] ?? ''),
      ].where((t) => t.isNotEmpty).join(' · ');
      return HandyPage(
        title: tr(context, 'Wishlist', 'Muốn có'),
        children: [
          if (items.isEmpty)
            HandyEmpty(
              title: tr(context, 'Nothing wanted now', 'Chưa muốn có gì'),
              message: tr(
                context,
                'In a collection, "Want one" adds what you are still looking for.',
                'Trong một bộ sưu tập, "Muốn có" thêm món bạn còn đang tìm.',
              ),
            )
          else
            HandyGroup(
              children: [
                for (final a in items)
                  HandyTile(
                    key: Key('wish-${a.id}'),
                    title: a.name,
                    subtitle: line(a),
                    onTap: () => Navigator.pushNamed(context, '/item/${a.id}'),
                    trailing: TextButton(
                      key: Key('wish-got-${a.id}'),
                      onPressed: () => scope.gotIt(context, a),
                      child: Text(tr(context, 'Got it', 'Đã có')),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
