import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'workspace.dart';

/// Edits the environment in use, or a new one. Values are `KEY=value`
/// lines; only the names are ever written to disk.
Future<void> editEnvironment(BuildContext context, Workspace ws) =>
    showDialog<void>(
      context: context,
      builder: (_) => _EnvironmentDialog(ws: ws, current: ws.env),
    );

Map<String, String> parseVariables(String text) => {
  for (final line in text.split('\n'))
    if (line.contains('=') && line.trim().isNotEmpty)
      line.substring(0, line.indexOf('=')).trim(): line
          .substring(line.indexOf('=') + 1)
          .trim(),
};

class _EnvironmentDialog extends StatefulWidget {
  final Workspace ws;
  final ApiEnvironment? current;
  const _EnvironmentDialog({required this.ws, this.current});
  @override
  State<_EnvironmentDialog> createState() => _EnvironmentDialogState();
}

class _EnvironmentDialogState extends State<_EnvironmentDialog> {
  late final name = TextEditingController(text: widget.current?.name ?? '');
  late final vars = TextEditingController(
    text:
        widget.current?.values.entries
            .map((e) => '${e.key}=${e.value}')
            .join('\n') ??
        'baseUrl=https://',
  );
  String error = '';

  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message
              : tr(
                  context,
                  'Could not save. Try again.',
                  'Chưa lưu được. Hãy thử lại.',
                ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.ws, id = widget.current?.id ?? Workspace.newId('e');
    return AlertDialog(
      title: Text(
        widget.current == null
            ? tr(context, 'New environment', 'Environment mới')
            : widget.current!.name,
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HandyField(
              label: tr(context, 'Name', 'Tên'),
              child: TextField(
                key: const Key('env-name'),
                controller: name,
                maxLength: 200,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
            HandyField(
              label: tr(context, 'Variables', 'Biến'),
              help: tr(
                context,
                'One KEY=value per line. Use as {{KEY}}. Values stay in this session only.',
                'Mỗi dòng một KEY=giá trị. Dùng dạng {{KEY}}. Giá trị chỉ giữ trong phiên này.',
              ),
              child: TextField(
                key: const Key('env-vars'),
                controller: vars,
                minLines: 4,
                maxLines: 10,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'GeistMono',
                  package: 'handy_ui',
                ),
              ),
            ),
            if (error.isNotEmpty) HandyNotice(error, tone: HandyTone.error),
          ],
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => run(() async {
              await ws.commit(removeEnvironment(ws.value, id));
              ws.useEnvironment(null);
            }),
            child: Text(
              tr(context, 'Delete', 'Xóa'),
              style: TextStyle(color: HandyColors.of(context).negative),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('env-save'),
          onPressed: () => run(() async {
            await ws.commit(
              saveEnvironment(
                ws.value,
                ApiEnvironment(
                  id: id,
                  name: name.text.trim(),
                  values: parseVariables(vars.text),
                ),
              ),
            );
            ws.useEnvironment(id);
          }),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    );
  }
}
