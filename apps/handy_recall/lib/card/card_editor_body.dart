import 'package:handy_ui/kit.dart';
import '../occlusion_editor.dart';
import 'card_editor.dart';

/// The card form: the question, the answer, and optionally a picture with
/// parts covered. Save keeps going for new cards; the bar holds both saves.
class CardEditorBody extends StatelessWidget {
  final CardEditorState editor;
  const CardEditorBody({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final e = editor;
    final isNew = e.widget.card == null;
    final c = HandyColors.of(context);
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
                HandyField(
                  label: tr(context, 'Question', 'Câu hỏi'),
                  child: TextField(
                    key: const Key('card-front'),
                    controller: e.front,
                    focusNode: e.frontFocus,
                    enabled: !e.busy,
                    autofocus: isNew,
                    minLines: 2,
                    maxLines: 8,
                    onChanged: (_) => e.touch(() {}),
                  ),
                ),
                const SizedBox(height: HandySpace.l),
                HandyField(
                  label: tr(context, 'Answer', 'Đáp án'),
                  child: TextField(
                    key: const Key('card-back'),
                    controller: e.back,
                    enabled: !e.busy,
                    minLines: 2,
                    maxLines: 8,
                    onChanged: (_) => e.touch(() {}),
                  ),
                ),
                HandyLabel(
                  tr(context, 'Picture with covers', 'Ảnh có vùng che'),
                ),
                HandyReveal(
                  child: e.image == null
                      ? Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: OutlinedButton.icon(
                            key: const Key('card-image'),
                            onPressed: e.busy ? null : e.importImage,
                            icon: const Icon(Icons.image_outlined),
                            label: Text(
                              tr(
                                context,
                                'Add a picture (PNG or JPEG, up to 500 KB)',
                                'Thêm ảnh (PNG hoặc JPEG, tối đa 500 KB)',
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OcclusionCanvas(
                              image: e.image!,
                              hidden: true,
                              onChanged: e.busy
                                  ? null
                                  : (next) => e.touch(() => e.image = next),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                key: const Key('card-image-remove'),
                                onPressed: e.busy
                                    ? null
                                    : () => e.touch(() => e.image = null),
                                child: Text(
                                  tr(context, 'Remove picture', 'Bỏ ảnh'),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
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
