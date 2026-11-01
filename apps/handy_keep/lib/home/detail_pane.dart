import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../due_page.dart';
import '../inventory/keep_store.dart' show today;
import '../inventory/whereabouts.dart' show dueItems;
import '../item/item_view.dart';
import '../scope.dart';

/// The right-hand pane on wide screens: the chosen item, or, with nothing
/// chosen, every date to watch (the narrow home shows them as a strip).
/// Picking another item fades the pane over instead of swapping it in one
/// frame.
class DetailPane extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset? item;
  final VoidCallback onClosed;
  final ValueChanged<String> onOpen;
  const DetailPane({
    super.key,
    required this.scope,
    required this.item,
    required this.onClosed,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final a = item;
    final dated = dueItems(scope.state, today()).isNotEmpty;
    final Widget body;
    if (a != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dated)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('pane-dates'),
                onPressed: onClosed,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(tr(context, 'Dates to watch', 'Cần để ý')),
              ),
            ),
          ItemView(scope: scope, item: a, onClosed: onClosed),
        ],
      );
    } else if (dated) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Dates to watch', 'Cần để ý'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: HandySpace.s),
          DueList(scope: scope, onOpen: onOpen, keyPrefix: 'pane-due'),
        ],
      );
    } else {
      return HandySwap(
        child: HandyEmpty(
          key: const ValueKey('none'),
          title: tr(
            context,
            'Pick a thing to see where it is',
            'Chọn một món để xem nó đang ở đâu',
          ),
        ),
      );
    }
    return HandySwap(
      child: ListView(
        key: ValueKey(a?.id ?? 'dates'),
        padding: const EdgeInsets.all(HandySpace.xl),
        children: [HandyContent(child: body)],
      ),
    );
  }
}
