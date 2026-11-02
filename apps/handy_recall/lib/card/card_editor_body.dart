import 'package:handy_ui/kit.dart';
import 'card_editor.dart';
import 'picture_field.dart';
import 'question_field.dart';

/// The card form: the question (with clozes), the answer, the reverse card
/// switch, and optionally a picture. Save keeps going for new cards; the
/// bar holds both saves.
class CardEditorBody extends StatelessWidget {
  final CardEditorState editor;
  const CardEditorBody({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final e = editor;
    final isNew = e.widget.card == null;
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final cloze = e.clozes.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('card-close'),
          tooltip: tr(context, 'Close', 'Đóng'),
          icon: const Icon(Icons.close),
          onPressed: e.busy ? null : e.askToLeave,
        ),
        title: Text(
          isNew
              ? tr(context, 'New card', 'Thẻ mới')
              : tr(context, 'Edit card', 'Sửa thẻ'),
        ),
        actions: [
          if (e.widget.onDelete != null)
            IconButton(
              key: const Key('card-delete'),
              tooltip: tr(context, 'Delete card', 'Xóa thẻ'),
              icon: const Icon(Icons.delete_outline),
              onPressed: e.busy
                  ? null
                  : () async {
                      if (await e.widget.onDelete!(context)) e.leave();
                    },
            ),
          if (e.saved > 0)
            Padding(
              padding: const EdgeInsets.only(right: HandySpace.l),
              child: Center(
                child: HandySwap(
                  child: Text(
                    tr(context, '${e.saved} saved', 'Đã lưu ${e.saved}'),
                    key: ValueKey(e.saved),
                    style: TextStyle(color: c.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: HandyBottomBar(
        child: Row(
          children: [
            if (isNew) ...[
              Expanded(
                child: OutlinedButton(
                  key: const Key('card-save-next'),
                  onPressed: e.busy ? null : () => e.save(another: true),
                  child: Text(
                    tr(context, 'Save, add another', 'Lưu, thêm thẻ khác'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: HandySpace.m),
            ],
            Expanded(
              child: FilledButton(
                key: const Key('card-save'),
                onPressed: e.busy ? null : e.save,
                child: Text(tr(context, 'Save card', 'Lưu thẻ')),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HandySpace.l),
        children: [
          HandyContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (e.busy) const LinearProgressIndicator(),
                QuestionField(editor: e),
                HandyField(
                  label: cloze
                      ? tr(
                          context,
                          'Extra (optional)',
                          'Ghi chú thêm (không bắt buộc)',
                        )
                      : tr(context, 'Answer', 'Đáp án'),
                  child: TextField(
                    key: const Key('card-back'),
                    controller: e.back,
                    enabled: !e.busy,
                    minLines: 2,
                    maxLines: 8,
                    onChanged: (_) => e.touch(() {}),
                  ),
                ),
                // The reverse card: its own schedule, so it is a choice.
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    key: const Key('card-reverse'),
                    contentPadding: EdgeInsets.zero,
                    value: e.reverse && e.canReverse,
                    onChanged: e.busy || !e.canReverse
                        ? null
                        : (v) => e.touch(() => e.reverse = v),
                    title: Text(
                      tr(
                        context,
                        'Also make the reverse card',
                        'Tạo thêm thẻ đảo chiều',
                      ),
                    ),
                    subtitle: Text(
                      !e.canReverse
                          ? (cloze
                                ? tr(
                                    context,
                                    'Cloze cards are asked one way only.',
                                    'Thẻ điền khuyết chỉ hỏi một chiều.',
                                  )
                                : tr(
                                    context,
                                    'A picture with covers is asked one way only.',
                                    'Ảnh có vùng che chỉ hỏi một chiều.',
                                  ))
                          : !e.reverse && e.widget.reverse
                          ? tr(
                              context,
                              'Saving removes the reverse card and its reviews.',
                              'Khi lưu, thẻ đảo chiều và lịch ôn của nó bị xóa.',
                            )
                          : tr(
                              context,
                              'Asks the answer, expects the question. Scheduled on its own.',
                              'Hỏi đáp án, nhớ lại câu hỏi. Lịch ôn riêng.',
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: !e.reverse && e.widget.reverse
                            ? c.warning
                            : c.muted,
                      ),
                    ),
                  ),
                ),
                PictureField(editor: e),
                HandyReveal(
                  child: e.error.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: HandySpace.l),
                          child: HandyNotice(e.error, tone: HandyTone.error),
                        ),
                ),
                const SizedBox(height: HandySpace.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
