import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import 'draft.dart';
import 'preview_pane.dart';
import 'source_pane.dart';

/// Text and page side by side from 900 px; below that, one at a time with
/// a switch between them.
class WriteLayout extends StatelessWidget {
  final DraftController draft;
  final bool busy, preview;
  final MarkdownDocument? document;
  final String? problem;
  final ValueChanged<bool> onPreview, onWide;
  const WriteLayout({
    super.key,
    required this.draft,
    required this.busy,
    required this.preview,
    required this.document,
    required this.problem,
    required this.onPreview,
    required this.onWide,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= 900;
      onWide(wide);
      final source = SourcePane(draft: draft, enabled: !busy);
      final sheet = PreviewPane(document: document, problem: problem);
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: source),
            VerticalDivider(width: 1, color: HandyColors.of(context).rule),
            Expanded(
              child: ColoredBox(
                color: HandyColors.of(context).ground,
                child: sheet,
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.s,
              HandySpace.l,
              0,
            ),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(tr(context, 'Edit', 'Soạn')),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(tr(context, 'Preview', 'Xem trước')),
                ),
              ],
              selected: {preview},
              onSelectionChanged: busy ? null : (v) => onPreview(v.single),
            ),
          ),
          Expanded(
            child: HandySwap(
              child: KeyedSubtree(
                key: ValueKey(preview),
                child: preview ? sheet : source,
              ),
            ),
          ),
        ],
      );
    },
  );
}
