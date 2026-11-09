import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'detail_view.dart';

/// A saved item on its own page (phones, medium widths, `#/bookmark/<id>`).
class BookmarkPage extends StatelessWidget {
  final SaveScope scope;
  final String id;
  const BookmarkPage({super.key, required this.scope, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(scrolledUnderElevation: 0),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.xs,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: [
        // Wider on a tablet or a computer, where it lays out in two columns.
        HandyContent(
          maxWidth: 1200,
          child: DetailView(
            scope: scope,
            id: id,
            wide: true,
            onClosed: () => Navigator.maybePop(context),
          ),
        ),
      ],
    ),
  );
}
