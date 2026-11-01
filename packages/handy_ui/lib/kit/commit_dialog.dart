import 'package:flutter/material.dart';
import 'l10n.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart';

/// A small form that closes only after [onCommit] has written. A failed write
/// keeps the dialog and what was typed, and says why.
class HandyCommitDialog extends StatefulWidget {
  final String title, saveLabel;
  final Key saveKey;
  final List<Widget> Function(BuildContext context, bool busy) fields;
  final Future<void> Function() onCommit;
  const HandyCommitDialog({
    super.key,
    required this.title,
    required this.saveLabel,
    required this.saveKey,
    required this.fields,
    required this.onCommit,
  });
  @override
  State<HandyCommitDialog> createState() => _HandyCommitDialogState();
}

class _HandyCommitDialogState extends State<HandyCommitDialog> {
  bool busy = false;
  String error = '';

  Future<void> save() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.onCommit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...widget.fields(context, busy),
            HandyReveal(
              child: error.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: HandySpace.l),
                      child: HandyNotice(error, tone: HandyTone.error),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: widget.saveKey,
          onPressed: busy ? null : save,
          child: Text(widget.saveLabel),
        ),
      ],
    ),
  );
}
