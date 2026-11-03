import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../view/library_view.dart';
import 'batch_bar.dart';
import 'results_view.dart';

/// One place as its own page (phones, and web links such as
/// `#/collection/<id>`). Leaving puts the shared list back on All links.
class ResultsPage extends StatefulWidget {
  final SaveScope scope;
  final Place place;
  final String? id;

  /// Opens a saved search instead of a plain place.
  final String? searchId;
  final VoidCallback onExport;
  const ResultsPage({
    super.key,
    required this.scope,
    required this.place,
    this.id,
    this.searchId,
    required this.onExport,
  });
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late final view = widget.scope.view;

  @override
  void initState() {
    super.initState();
    final saved = widget.scope.library.savedSearches
        .where((s) => s.id == widget.searchId)
        .firstOrNull;
    saved == null ? view.show(widget.place, widget.id) : view.applySaved(saved);
  }

  @override
  void deactivate() {
    if (widget.searchId != null) {
      view.text = '';
      view.filters = const Filters();
    }
    view.show(Place.all);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: view,
    builder: (context, _) => PopScope(
      // Back first stops selecting, then leaves.
      canPop: !view.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        view.clearSelection();
      },
      child: Scaffold(
        appBar: AppBar(),
        bottomNavigationBar: view.selecting
            ? BatchBar(scope: widget.scope, onExport: widget.onExport)
            : null,
        body: ResultsView(
          scope: widget.scope,
          onDetails: (b) => Navigator.pushNamed(context, '/bookmark/${b.id}'),
          onAdd: () {},
        ),
      ),
    ),
  );
}
