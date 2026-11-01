import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'deck_list.dart';
import 'today_panel.dart';

/// Today: how much is due and the button to start, the two weeks ahead,
/// then the decks. Two columns on wide screens, one on phones.
class RecallHome extends StatelessWidget {
  final RecallScope scope;
  const RecallHome({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) => Scaffold(
      appBar: const HandyTopBar(
        mark: Icons.style_outlined,
        name: 'Handy Recall',
      ),
      body: LayoutBuilder(
        builder: (context, size) {
          const pad = EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            HandySpace.xxl,
          );
          final today = TodayPanel(scope: scope);
          final decks = DeckList(scope: scope);
          if (size.maxWidth < 900) {
            return ListView(
              padding: pad,
              children: [
                HandyContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [today, decks],
                  ),
                ),
              ],
            );
          }
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: HandySpace.contentWide,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 460,
                    child: ListView(padding: pad, children: [today]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: pad.copyWith(top: 0),
                      children: [decks],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
