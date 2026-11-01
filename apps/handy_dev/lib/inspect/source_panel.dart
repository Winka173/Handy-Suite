import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';

/// Where the payload goes: a code field with paste, open and clear.
class SourcePanel extends StatelessWidget {
  final TextEditingController input;
  final FocusNode focus;
  final HandyFiles files;
  final VoidCallback onChanged;

  /// Saves the source as a draft; null hides it (empty or sensitive).
  final VoidCallback? onSaveDraft;
  const SourcePanel({
    super.key,
    required this.input,
    required this.focus,
    required this.files,
    required this.onChanged,
    this.onSaveDraft,
  });

  void set(String text) {
    input.text = text;
    onChanged();
    focus.requestFocus();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) set(data!.text!);
  }

  Future<void> open(BuildContext context) async {
    try {
      final file = await files.importText();
      if (file != null) set(file.text);
    } catch (_) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(context, 'Could not read that file.', 'Chưa đọc được file này.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.xs,
              HandySpace.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Source', 'Nguồn'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (onSaveDraft != null)
                  IconButton(
                    key: const Key('dev-save-draft'),
                    tooltip: tr(context, 'Save as draft', 'Lưu nháp'),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                    onPressed: onSaveDraft,
                  ),
                IconButton(
                  key: const Key('source-paste'),
                  tooltip: tr(context, 'Paste', 'Dán'),
                  icon: const Icon(Icons.content_paste, size: 20),
                  onPressed: paste,
                ),
                IconButton(
                  key: const Key('source-open'),
                  tooltip: tr(context, 'Open a file', 'Mở file'),
                  icon: const Icon(Icons.file_open_outlined, size: 20),
                  onPressed: () => open(context),
                ),
                IconButton(
                  key: const Key('source-clear'),
                  tooltip: tr(context, 'Clear', 'Xóa'),
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: input.text.isEmpty ? null : () => set(''),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              0,
              HandySpace.l,
              HandySpace.m,
            ),
            child: TextField(
              key: const Key('dev-input'),
              controller: input,
              focusNode: focus,
              autofocus: true,
              minLines: 6,
              maxLines: 16,
              onChanged: (_) => onChanged(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'GeistMono',
                package: 'handy_ui',
                height: 1.5,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: tr(
                  context,
                  'Paste JSON, a JWT, YAML, CSV, a cURL command…',
                  'Dán JSON, JWT, YAML, CSV, lệnh cURL…',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
