import 'package:handy_ui/kit.dart';

/// Asks for a name and commits it before closing. A failed save keeps the
/// dialog and what was typed, so retry is one tap.
Future<void> askName(
  BuildContext context, {
  required String title,
  required Future<void> Function(String name) commit,
  String initial = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => _NameDialog(title: title, initial: initial, commit: commit),
);

class _NameDialog extends StatefulWidget {
  final String title, initial;
  final Future<void> Function(String name) commit;
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.commit,
  });
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final name = TextEditingController(text: widget.initial);
  bool busy = false;
  String error = '';

  Future<void> save() async {
    if (busy || name.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.commit(name.text.trim());
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
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('collection-name'),
          controller: name,
          autofocus: true,
          maxLength: 200,
          enabled: !busy,
          onSubmitted: (_) => save(),
          decoration: InputDecoration(
            hintText: tr(context, 'Name', 'Tên'),
            counterText: '',
          ),
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: HandySpace.m),
          HandyNotice(error, tone: HandyTone.error),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: Text(tr(context, 'Cancel', 'Hủy')),
      ),
      FilledButton(
        key: const Key('collection-save'),
        onPressed: busy ? null : save,
        child: Text(tr(context, 'Save', 'Lưu')),
      ),
    ],
  );
}
