import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../shell/search_box.dart';
import '../view/library_view.dart';
import 'batch_bar.dart';
import 'deep_matches.dart';
import 'results_view.dart';

/// Search: everything saved, with the search field focused. Leaving
/// clears the words and filters, so Home is as it was.
class FindPage extends StatefulWidget {
  final SaveScope scope;
  final VoidCallback onExport;
  const FindPage({super.key, required this.scope, required this.onExport});
  @override
  State<FindPage> createState() => _FindPageState();
}

class _FindPageState extends State<FindPage> {
  late final view = widget.scope.view;
  final focus = FocusNode();
  late final deep = DeepIndex(widget.scope.c);

  @override
  void initState() {
    super.initState();
    view.show(Place.all);
    deep.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  @override
  void deactivate() {
    view.text = '';
    view.filters = const Filters();
    view.show(Place.all);
    super.deactivate();
  }

  @override
  void dispose() {
    focus.dispose();
    deep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: view,
    builder: (context, _) => PopScope(
      canPop: !view.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) view.clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'Search', 'Tìm'))),
        bottomNavigationBar: view.selecting
            ? BatchBar(scope: widget.scope, onExport: widget.onExport)
            : null,
        body: ResultsView(
          key: const Key('find'),
          scope: widget.scope,
          onDetails: (b) => Navigator.pushNamed(context, '/bookmark/${b.id}'),
          onAdd: () {},
          leading: [
            SearchBox(view: view, focus: focus),
            const SizedBox(height: HandySpace.l),
          ],
          trailing: [DeepMatches(scope: widget.scope, index: deep)],
        ),
      ),
    ),
  );
}
