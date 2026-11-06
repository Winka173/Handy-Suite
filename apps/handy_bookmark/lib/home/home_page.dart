import 'package:handy_ui/kit.dart';
import '../library/batch_bar.dart';
import '../library/results_view.dart';
import '../scope.dart';
import '../shell/places_list.dart';
import '../shell/search_box.dart';
import '../view/library_view.dart';
import '../shell/share_issues.dart';
import 'triage_strip.dart';
import '../links/task_strip.dart';
import 'link_capture.dart';

/// The phone's home: find a link, file what is new, or go to a place.
/// Typing turns the home into results; clearing brings it back.
class SaveHomePage extends StatelessWidget {
  final SaveScope scope;
  final FocusNode searchFocus;
  final VoidCallback onAdd, onExport;
  final Future<void> Function({bool clipboard}) onAddFrom;
  SaveHomePage({
    super.key,
    required this.scope,
    required this.searchFocus,
    required Future<void> Function({bool clipboard}) onAdd,
    required this.onExport,
  }) : onAddFrom = onAdd,
       onAdd = (() => onAdd());

  void openPlace(BuildContext context, Place p, [String? id]) =>
      Navigator.pushNamed(context, switch (p) {
        Place.collection => '/collection/$id',
        Place.smart => '/smart/$id',
        Place.tag => '/tag/${Uri.encodeComponent(id!)}',
        _ => '/place/${p.name}',
      });

  @override
  Widget build(BuildContext context) {
    final v = scope.view;
    return ListenableBuilder(
      listenable: v,
      builder: (context, _) {
        final searching = v.text.trim().isNotEmpty;
        return Scaffold(
          appBar: const HandyTopBar(
            mark: Icons.bookmark_outline,
            name: 'Handy Bookmark',
          ),
          bottomNavigationBar: v.selecting
              ? BatchBar(scope: scope, onExport: onExport)
              : HandyBottomBar(
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('save-paste'),
                        onPressed: () => onAddFrom(clipboard: true),
                        icon: const Icon(Icons.content_paste),
                        label: Text(tr(context, 'Paste', 'Dán link')),
                      ),
                      const SizedBox(width: HandySpace.m),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('save-add'),
                          onPressed: onAdd,
                          icon: const Icon(Icons.add_link),
                          label: Text(tr(context, 'Add links', 'Thêm link')),
                        ),
                      ),
                    ],
                  ),
                ),
          body: searching
              ? ResultsView(
                  scope: scope,
                  onDetails: (b) =>
                      Navigator.pushNamed(context, '/bookmark/${b.id}'),
                  onAdd: onAdd,
                  leading: [
                    SearchBox(view: v, focus: searchFocus),
                    const SizedBox(height: HandySpace.l),
                  ],
                )
              : ListView(
                  key: const Key('save-home'),
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    HandySpace.l,
                    HandySpace.l,
                    HandySpace.xxl,
                  ),
                  children: [
                    LinkCapture(scope: scope),
                    SearchBox(view: v, focus: searchFocus),
                    ShareIssues(controller: scope.c),
                    TaskStrip(
                      tasks: scope.tasks,
                      onBroken: () {
                        scope.tasks.dismiss();
                        openPlace(context, Place.broken);
                      },
                    ),
                    TriageStrip(
                      controller: scope.c,
                      onFile: scope.file,
                      onOpen: (b) =>
                          Navigator.pushNamed(context, '/bookmark/${b.id}'),
                      onAll: () => openPlace(context, Place.inbox),
                    ),
                    const SizedBox(height: HandySpace.xl),
                    PlacesList(
                      scope: scope,
                      marking: false,
                      onPick: (p, [id]) => openPlace(context, p, id),
                      onFocus: () => Navigator.pushNamed(context, '/focus'),
                      onSearch: (s) =>
                          Navigator.pushNamed(context, '/search/${s.id}'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
