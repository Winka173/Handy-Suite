import 'package:handy_ui/kit.dart';
import '../occlusion_editor.dart';
import 'card_editor.dart';

/// An optional picture. With covers it hides parts until the answer shows;
/// without any, it is a plain picture shown with the question or only with
/// the answer.
class PictureField extends StatelessWidget {
  final CardEditorState editor;
  const PictureField({super.key, required this.editor});
  @override
  Widget build(BuildContext context) {
    final e = editor;
    final image = e.image;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Picture', 'Ảnh')),
        HandyReveal(
          child: image == null
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
                      image: image,
                      hidden: true,
                      onChanged: e.busy
                          ? null
                          : (next) => e.touch(() {
                              // Covers only make sense on the question side.
                              e.image = next.masks.isEmpty
                                  ? next
                                  : next.copyWith(side: 'front');
                              if (next.masks.isNotEmpty) e.reverse = false;
                            }),
                    ),
                    if (image.masks.isEmpty) ...[
                      const SizedBox(height: HandySpace.m),
                      SegmentedButton<String>(
                        key: const Key('card-image-side'),
                        segments: [
                          ButtonSegment(
                            value: 'front',
                            label: Text(
                              tr(context, 'With the question', 'Cùng câu hỏi'),
                            ),
                          ),
                          ButtonSegment(
                            value: 'back',
                            label: Text(
                              tr(context, 'With the answer', 'Cùng đáp án'),
                            ),
                          ),
                        ],
                        selected: {image.side},
                        showSelectedIcon: false,
                        onSelectionChanged: e.busy
                            ? null
                            : (v) => e.touch(
                                () => e.image = image.copyWith(side: v.first),
                              ),
                      ),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        key: const Key('card-image-remove'),
                        onPressed: e.busy
                            ? null
                            : () => e.touch(() => e.image = null),
                        child: Text(tr(context, 'Remove picture', 'Bỏ ảnh')),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
