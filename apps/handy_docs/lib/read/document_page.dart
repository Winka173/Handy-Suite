import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import 'document_view.dart';
import 'reader_actions.dart';

/// One document over the library, on a phone.
class DocumentPage extends StatefulWidget {
  final ReaderActions actions;
  const DocumentPage({super.key, required this.actions});
  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  bool source = false;
  ReaderDocument? last;

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
    return ListenableBuilder(
      listenable: Listenable.merge([actions.store, actions.busy]),
      builder: (context, _) {
        final store = actions.store;
        final d = store.current ?? last;
        if (d == null) return const SizedBox.shrink();
        if (store.current == null) {
          // Removed or closed: step back to the library.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => mounted ? Navigator.maybePop(context) : null,
          );
        }
        last = d;
        return PopScope(
          canPop: store.saved || store.current == null,
          onPopInvokedWithResult: (popped, _) async {
            if (popped || actions.busy.value) return;
            if (await actions.mayClose(context)) {
              store.close();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              actions: [
                if (store.current != null)
                  DocumentActions(
                    actions: actions,
                    source: source,
                    onSource: (v) => setState(() => source = v),
                  ),
              ],
            ),
            body: DocumentBody(document: d, source: source, saved: store.saved),
          ),
        );
      },
    );
  }
}
