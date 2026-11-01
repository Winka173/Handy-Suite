import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import '../code_highlighter.dart';
import '../ui/paper.dart';

/// The draft as it will print: dark ink on a white sheet in both themes.
/// Pictures are never fetched and links never open; a link shows where it
/// would go.
class PreviewPane extends StatelessWidget {
  final MarkdownDocument? document;
  final String? problem;
  const PreviewPane({super.key, this.document, this.problem});

  @override
  Widget build(BuildContext context) {
    if (problem != null) {
      return Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: HandyNotice(problem!, tone: HandyTone.warning),
      );
    }
    final doc = document;
    if (doc == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(HandySpace.l),
      child: PaperSheet(
        child: MarkdownBody(
          key: const Key('markdown-preview'),
          data: doc.source,
          selectable: true,
          syntaxHighlighter: LocalCodeHighlighter(dark: false),
          imageBuilder: (_, _, alt) => Text(
            '[${tr(context, 'Image blocked', 'Ảnh bị chặn')}${alt == null || alt.isEmpty ? '' : ': $alt'}]',
          ),
          onTapLink: (_, href, _) => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr(context, 'Link destination', 'Đích liên kết')),
              content: SelectableText(href ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Close', 'Đóng')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
