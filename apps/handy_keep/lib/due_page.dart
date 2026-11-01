import 'package:handy_ui/kit.dart';
import 'inventory/keep_store.dart' show today;
import 'inventory/whereabouts.dart';
import 'scope.dart';
import 'ui/words.dart';

/// Every dated thing: what has passed, the next 30 days, and later.
class DuePage extends StatelessWidget {
  final KeepScope scope;
  const DuePage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Dates', 'Đến hạn'))),
      body: dueItems(scope.state, today()).isEmpty
          ? HandyEmpty(
              title: tr(
                context,
                'No dates to watch.',
                'Chưa có mốc nào cần theo dõi.',
              ),
              message: tr(
                context,
                'Return dates, warranty ends and services show here once an item has them.',
                'Hẹn trả, ngày hết bảo hành và lịch bảo dưỡng của từng món sẽ hiện ở đây.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(HandySpace.l),
              children: [
                HandyContent(
                  child: DueList(
                    scope: scope,
                    onOpen: (id) => Navigator.pushNamed(context, '/item/$id'),
                  ),
                ),
              ],
            ),
    ),
  );
}

/// The dates grouped as overdue, the next 30 days and later. The page and
/// the wide home's empty pane both show it; [keyPrefix] tells them apart.
class DueList extends StatelessWidget {
  final KeepScope scope;
  final ValueChanged<String> onOpen;
  final String keyPrefix;
  const DueList({
    super.key,
    required this.scope,
    required this.onOpen,
    this.keyPrefix = 'due',
  });
  @override
  Widget build(BuildContext context) {
    final due = dueItems(scope.state, today());
    final groups = [
      (tr(context, 'Overdue', 'Quá hạn'), due.where((d) => d.days < 0)),
      (
        tr(context, 'Next 30 days', 'Trong 30 ngày tới'),
        due.where((d) => d.days >= 0 && d.days <= 30),
      ),
      (tr(context, 'Later', 'Sau đó'), due.where((d) => d.days > 30)),
    ];
    final c = HandyColors.of(context);
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, rows) in groups)
          if (rows.isNotEmpty) ...[
            HandyLabel(title),
            HandyGroup(
              children: [
                for (final d in rows)
                  ListTile(
                    key: Key('$keyPrefix-${d.item.id}-${d.kind}'),
                    leading: ItemThumb(
                      d.item,
                      scope.store.library!.blobs,
                      hue: itemHue(scope.state, d.item),
                    ),
                    title: Text(d.item.name),
                    subtitle: Text(
                      '${dueKind(context, d.kind)} · ${formatDay(context, d.date)}',
                    ),
                    trailing: Text(
                      dueWhen(context, d.kind, d.days),
                      style: style?.copyWith(
                        color: d.overdue ? c.negative : null,
                        fontWeight: d.overdue ? FontWeight.w500 : null,
                      ),
                    ),
                    onTap: () => onOpen(d.item.id),
                  ),
              ],
            ),
          ],
      ],
    );
  }
}
