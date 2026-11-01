import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../item/item_view.dart';
import '../scope.dart';

/// The right-hand pane on wide screens. Picking another item fades the pane
/// over instead of swapping it in one frame.
class DetailPane extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset? item;
  final VoidCallback onClosed;
  const DetailPane({
    super.key,
    required this.scope,
    required this.item,
    required this.onClosed,
  });
  @override
  Widget build(BuildContext context) {
    final a = item;
    return HandySwap(
      child: a == null
          ? HandyEmpty(
              key: const ValueKey('none'),
              title: tr(
                context,
                'Pick a thing to see where it is',
                'Chọn một món để xem nó đang ở đâu',
              ),
            )
          : ListView(
              key: ValueKey(a.id),
              padding: const EdgeInsets.all(HandySpace.xl),
              children: [
                HandyContent(
                  child: ItemView(scope: scope, item: a, onClosed: onClosed),
                ),
              ],
            ),
    );
  }
}
