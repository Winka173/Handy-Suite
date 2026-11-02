import 'dart:math' as math;
import 'package:handy_ui/kit.dart';
import '../annotation_canvas.dart';
import 'editor_actions.dart';
import 'editor_page.dart';
import 'layer_panel.dart';
import 'review_panel.dart';
import 'sensitive_review.dart';
import 'step_notes.dart';
import 'step_strip.dart';
import 'tool_bar.dart';

/// From 1100 px: film | picture | settings. Narrower: the picture with
/// its settings under it and the film along the foot.
class EditorBody extends StatelessWidget {
  final CaptureEditorState state;
  const EditorBody({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = state.c, busy = state.locked, review = state.review;
    final colors = HandyColors.of(context);
    if (c.step == null) {
      return HandyEmpty(
        title: tr(context, 'Add the screenshots', 'Thêm các ảnh chụp màn hình'),
        message: tr(
          context,
          'Each picture becomes a numbered step. You can mark it up, hide what is private and write what to do.',
          'Mỗi ảnh thành một bước có số. Bạn có thể đánh dấu, che chỗ riêng tư và ghi cần làm gì.',
        ),
        action: FilledButton.icon(
          key: const Key('capture-import-images'),
          onPressed: busy ? null : state.addFiles,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(tr(context, 'Add screenshots', 'Thêm ảnh chụp')),
        ),
      );
    }
    StepStrip strip(bool vertical) => StepStrip(
      c: c,
      busy: busy,
      vertical: vertical,
      onAdd: state.addFiles,
      onCamera: state.camera.supported ? state.addPhoto : null,
    );
    final side = review != null
        ? [ReviewPanel(review: review)]
        : [
            LayerPanel(
              c: c,
              busy: busy,
              onRepeatMask: state.repeatMask,
              onFindSensitive: state.reader.supported
                  ? state.findSensitive
                  : null,
            ),
            Divider(height: HandySpace.xl, color: colors.rule),
            StepNotes(key: ValueKey('notes-${c.step!.id}'), c: c, busy: busy),
            const SizedBox(height: HandySpace.s),
            _StepActions(state: state),
          ];
    final notice = c.draftError == null
        ? null
        : Padding(
            padding: const EdgeInsets.all(HandySpace.s),
            child: HandyNotice(
              tr(
                context,
                'The draft copy could not be written. Keep this open and save or back up the guide.',
                'Chưa ghi được bản nháp. Giữ màn hình này và lưu hoặc sao lưu hướng dẫn.',
              ),
              tone: HandyTone.warning,
            ),
          );
    final tools = SizedBox(
      height: 52,
      child: Align(
        alignment: Alignment.centerLeft,
        child: ToolBar(c: c, busy: busy),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 1100) {
          return Column(
            children: [
              ?notice,
              tools,
              Divider(height: 1, color: colors.rule),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 160, child: strip(true)),
                    VerticalDivider(width: 1, color: colors.rule),
                    Expanded(
                      child: ColoredBox(
                        color: colors.ground,
                        child: Padding(
                          padding: const EdgeInsets.all(HandySpace.s),
                          child: _Picture(state: state),
                        ),
                      ),
                    ),
                    VerticalDivider(width: 1, color: colors.rule),
                    SizedBox(
                      width: 320,
                      child: ListView(
                        padding: const EdgeInsets.all(HandySpace.l),
                        children: side,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            ?notice,
            tools,
            Divider(height: 1, color: colors.rule),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: HandySpace.l),
                children: [
                  SizedBox(
                    height: math.min(box.maxHeight * .62, 640),
                    child: _Picture(state: state),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HandySpace.l,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: side,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.rule),
            SizedBox(height: 112, child: strip(false)),
          ],
        );
      },
    );
  }
}

class _Picture extends StatelessWidget {
  final CaptureEditorState state;
  const _Picture({required this.state});
  @override
  Widget build(BuildContext context) {
    final c = state.c, png = c.picture, review = state.review;
    final hue = Theme.of(context).colorScheme.primary;
    // While places are looked over, the picture shows them and takes no
    // gestures; the guide itself is unchanged.
    final step = review == null ? c.step! : review.preview(c.step!, _hex(hue));
    if (png == null) {
      return Center(
        child: HandyEmpty(
          title: tr(
            context,
            'This picture is missing',
            'Thiếu ảnh của bước này',
          ),
          message: tr(
            context,
            'The backup did not carry it. Add the same PNG, ${step.imageWidth} × ${step.imageHeight}, so the notes land where they were.',
            'Bản sao lưu không có ảnh này. Thêm đúng PNG đó, ${step.imageWidth} × ${step.imageHeight}, để chú thích nằm đúng chỗ.',
          ),
          action: OutlinedButton(
            key: const Key('capture-relink'),
            onPressed: state.busy ? null : state.relink,
            child: Text(tr(context, 'Add the picture', 'Thêm ảnh')),
          ),
        ),
      );
    }
    return HandySwap(
      child: AbsorbPointer(
        key: ValueKey(step.id),
        absorbing: state.locked,
        child: GestureDetector(
          excludeFromSemantics: true,
          onTap: c.tool == null ? () => c.select(null) : null,
          child: AnnotationCanvas(
            step: step,
            png: png,
            selected: review == null
                ? c.selected
                : review.focus == null
                ? null
                : SensitiveReview.proposalId(review.focus!),
            panEnabled: c.panMode,
            transformation: c.zoom,
            drawing: c.tool == 'pen',
            tool: c.tool,
            onSelect: c.select,
            onChange: (l) => c.editLayer(l, record: false),
            onGestureStart: c.checkpoint,
            onGestureEnd: c.backup,
            onStroke: (points) => _add(context, () => c.addStroke(points)),
            describe: (l) => [
              kindName(context, l.kind),
              if (l.text.isNotEmpty) l.text,
            ].join(': '),
            onCreate: (kind, area, line) =>
                _add(context, () => c.addLayer(kind, area: area, line: line)),
          ),
        ),
      ),
    );
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _add(BuildContext context, VoidCallback add) {
    try {
      add();
    } on FormatException catch (e) {
      state.say(e.message);
    }
  }
}

class _StepActions extends StatelessWidget {
  final CaptureEditorState state;
  const _StepActions({required this.state});
  @override
  Widget build(BuildContext context) {
    final c = state.c, busy = state.locked, i = c.stepIndex;
    return Row(
      children: [
        IconButton(
          key: const Key('capture-step-up'),
          tooltip: tr(context, 'Move step earlier', 'Đưa bước lên trước'),
          onPressed: busy || i == 0 ? null : () => c.moveStep(i, i - 1),
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          key: const Key('capture-step-down'),
          tooltip: tr(context, 'Move step later', 'Đưa bước ra sau'),
          onPressed: busy || i == c.project.steps.length - 1
              ? null
              : () => c.moveStep(i, i + 1),
          icon: const Icon(Icons.arrow_downward),
        ),
        const Spacer(),
        TextButton.icon(
          key: const Key('capture-step-delete'),
          onPressed: busy ? null : state.deleteStep,
          icon: const Icon(Icons.delete_outline),
          label: Text(tr(context, 'Delete step', 'Xóa bước')),
        ),
      ],
    );
  }
}
