import 'package:handy_ui/kit.dart';
import 'draft.dart';

/// The Markdown text, filling its pane, with a foot that counts the words,
/// says whether they are saved, and undoes.
class SourcePane extends StatelessWidget {
  final DraftController draft;
  final bool enabled;
  const SourcePane({super.key, required this.draft, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      children: [
        Expanded(
          child: TextField(
            key: const Key('markdown-source'),
            controller: draft.source,
            undoController: draft.undo,
            enabled: enabled,
            expands: true,
            maxLines: null,
            maxLength: 1000000,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            // Geist, not the mono face: it carries every Vietnamese mark.
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.55,
              // Show `->` and `--` as typed: they are Markdown, not arrows.
              fontFeatures: const [
                FontFeature.disable('calt'),
                FontFeature.disable('liga'),
              ],
            ),
            decoration: InputDecoration(
              hintText: tr(
                context,
                '# A title\n\nWrite here. **Bold**, *italic*, - lists, | tables |',
                '# Tiêu đề\n\nViết ở đây. **Đậm**, *nghiêng*, - danh sách, | bảng |',
              ),
              hintMaxLines: 4,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.all(HandySpace.l),
            ),
          ),
        ),
        Divider(height: 1, color: c.rule),
        Padding(
          padding: const EdgeInsets.only(left: HandySpace.l),
          child: ListenableBuilder(
            listenable: Listenable.merge([draft, draft.source, draft.undo]),
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    '${tr(context, '${formatFigure(context, '${draft.words}')} words', '${formatFigure(context, '${draft.words}')} chữ')} · ${draft.dirty ? tr(context, 'not saved', 'chưa lưu') : tr(context, 'saved', 'đã lưu')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Undo', 'Hoàn tác'),
                  onPressed: enabled && draft.undo.value.canUndo
                      ? draft.undo.undo
                      : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: tr(context, 'Redo', 'Làm lại'),
                  onPressed: enabled && draft.undo.value.canRedo
                      ? draft.undo.redo
                      : null,
                  icon: const Icon(Icons.redo),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
