import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'card_editor.dart';

/// The question, with the one tool that turns selected words into a cloze:
/// a button under the field, the same item in the selection menu, and
/// Ctrl+Shift+C (Ctrl+Shift+Alt+C for another blank of the last cloze).
class QuestionField extends StatelessWidget {
  final CardEditorState editor;
  const QuestionField({super.key, required this.editor});
  @override
  Widget build(BuildContext context) {
    final e = editor;
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final numbers = e.clozes;
    final label = tr(context, 'Make a cloze', 'Tạo ô điền khuyết');
    return HandyField(
      label: tr(context, 'Question', 'Câu hỏi'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyC,
                control: true,
                shift: true,
              ): e.wrapCloze,
              const SingleActivator(
                LogicalKeyboardKey.keyC,
                control: true,
                shift: true,
                alt: true,
              ): () =>
                  e.wrapCloze(same: true),
            },
            child: TextField(
              key: const Key('card-front'),
              controller: e.front,
              focusNode: e.frontFocus,
              enabled: !e.busy,
              autofocus: e.widget.card == null,
              minLines: 2,
              maxLines: 8,
              onChanged: (_) => e.touch(() {}),
              contextMenuBuilder: (context, state) =>
                  AdaptiveTextSelectionToolbar.buttonItems(
                    anchors: state.contextMenuAnchors,
                    buttonItems: [
                      if (!state.textEditingValue.selection.isCollapsed)
                        ContextMenuButtonItem(
                          label: tr(context, 'Cloze', 'Điền khuyết'),
                          onPressed: () {
                            ContextMenuController.removeAny();
                            e.wrapCloze();
                          },
                        ),
                      ...state.contextMenuButtonItems,
                    ],
                  ),
            ),
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: HandySpace.m,
            runSpacing: HandySpace.xs,
            children: [
              OutlinedButton.icon(
                key: const Key('card-cloze'),
                onPressed: e.busy ? null : e.wrapCloze,
                icon: const Icon(Icons.data_array, size: 18),
                label: Text(label),
              ),
              Text(
                numbers.isEmpty
                    ? tr(
                        context,
                        'Select words first to hide them.',
                        'Chọn chữ trước để ẩn đi.',
                      )
                    : tr(
                        context,
                        'Makes ${numbers.length} cards, one per blank.',
                        'Tạo ${numbers.length} thẻ, mỗi ô một thẻ.',
                      ),
                key: const Key('card-cloze-count'),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
