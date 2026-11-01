import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'item_view.dart';

/// An item on its own page (phones, and web links like `#/item/<id>`).
class ItemPage extends StatelessWidget {
  final KeepScope scope;
  final String id;
  const ItemPage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) {
      final item = scope.state.assets.where((a) => a.id == id).firstOrNull;
      return Scaffold(
        appBar: AppBar(),
        body: item == null
            ? HandyEmpty(
                title: tr(
                  context,
                  'This item is not in Keep on this device.',
                  'Món này không có trong Keep trên máy này.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(HandySpace.l),
                children: [
                  HandyContent(
                    child: ItemView(
                      scope: scope,
                      item: item,
                      hero: true,
                      onClosed: () => Navigator.maybePop(context),
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
