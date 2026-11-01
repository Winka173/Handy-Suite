import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'request_editor.dart';
import 'request_list.dart';
import 'workspace.dart';

/// Requests: the list beside the editor on wide screens; on phones one at a
/// time, the editor pushed over the list and Back returning to it.
class RequestsArea extends StatelessWidget {
  final Workspace ws;
  final HandyFiles files;
  const RequestsArea({super.key, required this.ws, required this.files});

  void newRequest(BuildContext context) => ws.openDraft(
    ApiRequest(
      id: Workspace.newId('r'),
      name: tr(context, 'New request', 'Request mới'),
      url: 'https://',
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ws,
    builder: (context, _) {
      if (ws.loading) return const Center(child: CircularProgressIndicator());
      if (ws.loadError != null) {
        return Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: HandyEmpty(
            title: tr(
              context,
              'Saved requests could not be opened.',
              'Chưa mở được request đã lưu.',
            ),
            message: tr(
              context,
              'Nothing was changed on disk.',
              'Không có gì bị thay đổi trên đĩa.',
            ),
            action: FilledButton(
              onPressed: ws.load,
              child: Text(tr(context, 'Try again', 'Thử lại')),
            ),
          ),
        );
      }
      final r = ws.request;
      final list = RequestList(
        ws: ws,
        files: files,
        onNew: () => newRequest(context),
      );
      return LayoutBuilder(
        builder: (context, size) {
          final wide = size.maxWidth >= 900;
          final editor = r == null
              ? Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: HandyEmpty(
                    title: tr(
                      context,
                      'Choose a request, or start a new one.',
                      'Chọn một request, hoặc tạo request mới.',
                    ),
                    action: FilledButton.icon(
                      onPressed: () => newRequest(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr(context, 'New request', 'Request mới')),
                    ),
                  ),
                )
              : RequestEditor(
                  key: ValueKey(r.id),
                  ws: ws,
                  request: r,
                  onBack: wide ? null : () => ws.select(null),
                );
          if (!wide)
            return PopScope(
              canPop: r == null,
              onPopInvokedWithResult: (_, _) => ws.select(null),
              child: r == null ? list : editor,
            );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: list),
              VerticalDivider(width: 1, color: HandyColors.of(context).border),
              Expanded(child: editor),
            ],
          );
        },
      );
    },
  );
}
