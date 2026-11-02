import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../annotation_painter.dart';
import 'guide_output.dart';

/// How the GIF plays, chosen before anything is drawn. Null when dismissed.
Future<GifOptions?> pickGifOptions(
  BuildContext context,
  CaptureProject guide,
  Map<String, Uint8List> assets,
) => showModalBottomSheet<GifOptions>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => GifSheet(guide: guide, assets: assets),
);

/// Its question: "how will the GIF look and play?" The first frame, as it
/// will be drawn, is the biggest thing; under it the time per step, the
/// width and the caption bar, then one button.
class GifSheet extends StatefulWidget {
  final CaptureProject guide;
  final Map<String, Uint8List> assets;
  const GifSheet({super.key, required this.guide, required this.assets});
  @override
  State<GifSheet> createState() => _GifSheetState();
}

class _GifSheetState extends State<GifSheet> {
  GifOptions options = defaultGifOptions;

  void set({int? frameMs, int? width, bool? captions}) => setState(
    () => options = (
      frameMs: frameMs ?? options.frameMs,
      width: width ?? options.width,
      captions: captions ?? options.captions,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final steps = widget.guide.steps.length;
    GuideGifLayout? layout;
    String? problem;
    try {
      layout = gifLayoutFor(widget.guide, options);
    } on FormatException catch (e) {
      problem = e.message;
    }
    final seconds = steps * options.frameMs / 1000;
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: HandySpace.l, bottom: HandySpace.xs),
      child: Text(text, style: theme.textTheme.labelLarge),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        0,
        HandySpace.l,
        HandySpace.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Animated GIF', 'Ảnh động GIF'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: HandySpace.xs),
          Text(
            key: const Key('gif-summary'),
            layout == null
                ? tr(context, '$steps frames', '$steps khung')
                : tr(
                    context,
                    '$steps frames · ${layout.width} × ${layout.height} px · ${_s(seconds)} s, then it starts again',
                    '$steps khung · ${layout.width} × ${layout.height} px · ${_s(seconds, vi: true)} giây rồi chạy lại',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.m),
          if (layout != null)
            _FirstFrame(
              step: widget.guide.steps.first,
              picture: widget.assets[widget.guide.steps.first.imageUri],
              layout: layout,
            ),
          label(tr(context, 'Each step shows for', 'Mỗi bước hiện trong')),
          SegmentedButton<int>(
            key: const Key('gif-frame-ms'),
            showSelectedIcon: false,
            segments: [
              for (final ms in [1000, 2000, 3000, 5000])
                ButtonSegment(
                  value: ms,
                  label: Text(
                    tr(context, '${ms ~/ 1000} s', '${ms ~/ 1000} giây'),
                  ),
                ),
            ],
            selected: {options.frameMs},
            onSelectionChanged: (v) => set(frameMs: v.single),
          ),
          label(tr(context, 'Widest size', 'Rộng tối đa')),
          SegmentedButton<int>(
            key: const Key('gif-width'),
            showSelectedIcon: false,
            segments: [
              for (final w in guideGifWidths)
                ButtonSegment(value: w, label: Text('$w')),
            ],
            selected: {options.width},
            onSelectionChanged: (v) => set(width: v.single),
          ),
          if (layout != null && layout.width < options.width) ...[
            const SizedBox(height: HandySpace.xs),
            Text(
              key: const Key('gif-not-enlarged'),
              tr(
                context,
                'Pictures are never enlarged: these steps are ${layout.width} px wide.',
                'Ảnh không bị phóng to: các bước này rộng ${layout.width} px.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
          const SizedBox(height: HandySpace.s),
          SwitchListTile(
            key: const Key('gif-captions'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr(
                context,
                'Number and title under each frame',
                'Số và tên bước dưới mỗi khung',
              ),
            ),
            value: options.captions,
            onChanged: (v) => set(captions: v),
          ),
          if (problem != null) ...[
            const SizedBox(height: HandySpace.s),
            HandyNotice(
              problem,
              key: const Key('gif-problem'),
              tone: HandyTone.error,
            ),
          ],
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'Up to 100 steps, 48 million pixels in all and 20 MB. Hidden areas are painted over; the editable layers stay out.',
              'Tối đa 100 bước, tổng 48 triệu điểm ảnh và 20 MB. Vùng che được tô kín; các lớp chỉnh sửa không đi kèm.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.l),
          FilledButton.icon(
            key: const Key('gif-make'),
            onPressed: problem == null
                ? () => Navigator.pop(context, options)
                : null,
            icon: const Icon(Icons.gif_box_outlined),
            label: Text(tr(context, 'Make the GIF', 'Tạo GIF')),
          ),
        ],
      ),
    );
  }

  static String _s(double v, {bool vi = false}) {
    final text = v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    return vi ? text.replaceAll('.', ',') : text;
  }
}

/// The first frame as it will play: the picture with its notes and masks
/// drawn on, fitted in the frame, and the caption bar under it.
class _FirstFrame extends StatelessWidget {
  final ProjectStep step;
  final Uint8List? picture;
  final GuideGifLayout layout;
  const _FirstFrame({
    required this.step,
    required this.picture,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final title = step.title.trim().isEmpty
        ? tr(context, 'Step 1', 'Bước 1')
        : step.title.trim();
    return Semantics(
      label: tr(context, 'First frame: $title', 'Khung đầu: $title'),
      excludeSemantics: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: AspectRatio(
            aspectRatio: layout.width / layout.height,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: c.border)),
              child: Column(
                children: [
                  Expanded(
                    flex: layout.pictureHeight,
                    child: ColoredBox(
                      color: Colors.white,
                      child: picture == null
                          ? const SizedBox.expand()
                          : FittedBox(
                              child: SizedBox(
                                width: step.imageWidth.toDouble(),
                                height: step.imageHeight.toDouble(),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      picture!,
                                      fit: BoxFit.fill,
                                      cacheWidth: 600,
                                      excludeFromSemantics: true,
                                    ),
                                    CustomPaint(
                                      painter: AnnotationPainter(
                                        step.annotations,
                                        Size(
                                          step.imageWidth.toDouble(),
                                          step.imageHeight.toDouble(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (layout.captionHeight > 0)
                    Expanded(
                      flex: layout.captionHeight,
                      child: _Bar(title: title),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The caption bar drawn smaller, the same parts as [renderGifCaption].
class _Bar extends StatelessWidget {
  final String title;
  const _Bar({required this.title});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = box.maxHeight, disc = h * .56;
      return ColoredBox(
        color: const Color(0xFF1D1F20),
        child: Row(
          children: [
            SizedBox(width: h * .25),
            CircleAvatar(
              radius: disc / 2,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: disc * .5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: h * .25),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: h * .34,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: h * .25),
          ],
        ),
      );
    },
  );
}
