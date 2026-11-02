import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';

/// An image with regions hidden for review. With [onChanged] it edits them:
/// drag empty space to add a region, drag a region to move it, drag its
/// corner to resize. Geometry is in 0–1 of the image, so it survives resizing.
class OcclusionCanvas extends StatefulWidget {
  final RecallImage image;
  final bool hidden;
  final ValueChanged<RecallImage>? onChanged;
  const OcclusionCanvas({
    super.key,
    required this.image,
    required this.hidden,
    this.onChanged,
  });
  @override
  State<OcclusionCanvas> createState() => _OcclusionCanvasState();
}

class _OcclusionCanvasState extends State<OcclusionCanvas> {
  late RecallImage current = widget.image;
  int selected = 0;
  Offset? start, end;
  double ratio = 1;
  bool decodeFailed = false;
  ImageStream? stream;
  ImageStreamListener? listener;
  String loadedUri = '';

  /// Decoded once per picture: one image provider for its whole life, so a
  /// rebuild (dragging a cover, a store update) never re-decodes or flickers.
  MemoryImage? picture;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bindImage();
  }

  @override
  void didUpdateWidget(covariant OcclusionCanvas old) {
    super.didUpdateWidget(old);
    current = widget.image;
    selected = current.masks.isEmpty
        ? 0
        : selected.clamp(0, current.masks.length - 1);
    if (old.image.dataUri != widget.image.dataUri) {
      selected = 0;
      start = null;
      end = null;
      bindImage();
    }
  }

  void unbind() {
    if (stream != null && listener != null) stream!.removeListener(listener!);
    stream = null;
    listener = null;
  }

  void bindImage() {
    final uri = widget.image.dataUri;
    if (uri == loadedUri) return;
    unbind();
    loadedUri = uri;
    ratio = 1;
    decodeFailed = false;
    final provider = picture = MemoryImage(
      Uint8List.fromList(base64Decode(uri.split(',').last)),
    );
    stream = provider.resolve(createLocalImageConfiguration(context));
    listener = ImageStreamListener(
      (info, _) {
        final width = info.image.width, height = info.image.height;
        info.dispose();
        if (mounted && loadedUri == uri) setState(() => ratio = width / height);
      },
      onError: (Object error, StackTrace? trace) {
        if (mounted && loadedUri == uri) setState(() => decodeFailed = true);
      },
    );
    stream!.addListener(listener!);
  }

  @override
  void dispose() {
    unbind();
    super.dispose();
  }

  void publish(List<OcclusionMask> masks) {
    current = current.copyWith(masks: masks);
    widget.onChanged?.call(current);
  }

  void move(int index, Offset delta, Size size, bool resize) {
    if (size.width <= 0 || size.height <= 0 || index >= current.masks.length)
      return;
    final m = current.masks[index],
        dx = delta.dx / size.width,
        dy = delta.dy / size.height,
        maxWidth = 1 - m.x,
        maxHeight = 1 - m.y;
    final next = resize
        ? m.copyWith({
            'width': (m.width + dx).clamp(math.min(0.02, maxWidth), maxWidth),
            'height': (m.height + dy).clamp(
              math.min(0.02, maxHeight),
              maxHeight,
            ),
          })
        : m.copyWith({
            'x': (m.x + dx).clamp(0, 1 - m.width),
            'y': (m.y + dy).clamp(0, 1 - m.height),
          });
    setState(() => selected = index);
    publish([...current.masks]..[index] = next);
  }

  void finishCreation(Size size) {
    final origin = start, point = end;
    start = null;
    end = null;
    if (origin == null || point == null || current.masks.length >= 32) return;
    final x1 = (origin.dx / size.width).clamp(0.0, 1.0),
        y1 = (origin.dy / size.height).clamp(0.0, 1.0),
        x2 = (point.dx / size.width).clamp(0.0, 1.0),
        y2 = (point.dy / size.height).clamp(0.0, 1.0);
    final width = (x2 - x1).abs(), height = (y2 - y1).abs();
    if (width * size.width < 3 || height * size.height < 3) return;
    final mask = OcclusionMask(
      x: math.min(x1, x2),
      y: math.min(y1, y2),
      width: width,
      height: height,
    );
    setState(() => selected = current.masks.length);
    publish([...current.masks, mask]);
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.onChanged != null, image = picture;
    final c = HandyColors.of(context);
    final cover = Theme.of(context).colorScheme.primary;
    if (decodeFailed) {
      return HandyNotice(
        tr(context, 'This image could not be read.', 'Không đọc được ảnh này.'),
        tone: HandyTone.error,
      );
    }
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(1.0, 640.0).toDouble(),
                size = Size(width, width / ratio);
            return SizedBox(
              width: width,
              height: size.height,
              child: GestureDetector(
                key: const Key('occlusion-surface'),
                behavior: HitTestBehavior.opaque,
                onPanStart: editable
                    ? (d) {
                        start = d.localPosition;
                        end = d.localPosition;
                      }
                    : null,
                onPanUpdate: editable ? (d) => end = d.localPosition : null,
                onPanCancel: () {
                  start = null;
                  end = null;
                },
                onPanEnd: editable ? (_) => finishCreation(size) : null,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: Image(
                        image: image!,
                        gaplessPlayback: true,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, trace) => HandyNotice(
                          tr(
                            context,
                            'This image could not be read.',
                            'Không đọc được ảnh này.',
                          ),
                          tone: HandyTone.error,
                        ),
                      ),
                    ),
                    if (widget.hidden)
                      for (var i = 0; i < current.masks.length; i++)
                        Positioned(
                          left: current.masks[i].x * size.width,
                          top: current.masks[i].y * size.height,
                          width: current.masks[i].width * size.width,
                          height: current.masks[i].height * size.height,
                          child: GestureDetector(
                            key: Key('occlusion-region-$i'),
                            onTap: editable
                                ? () => setState(() => selected = i)
                                : null,
                            onPanUpdate: editable
                                ? (d) => move(i, d.delta, size, false)
                                : null,
                            // The cover is the app's deep hue; the chosen
                            // region gets a white edge and its resize corner.
                            child: AnimatedContainer(
                              duration: HandyMotion.of(
                                context,
                                HandyMotion.short,
                              ),
                              decoration: BoxDecoration(
                                color: cover,
                                borderRadius: BorderRadius.circular(4),
                                border: editable
                                    ? Border.all(
                                        color: i == selected
                                            ? Colors.white
                                            : cover,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: editable && selected == i
                                  ? Align(
                                      alignment: Alignment.bottomRight,
                                      child: GestureDetector(
                                        key: Key('occlusion-resize-$i'),
                                        onPanUpdate: (d) =>
                                            move(i, d.delta, size, true),
                                        child: Semantics(
                                          label: tr(
                                            context,
                                            'Resize region',
                                            'Đổi cỡ vùng che',
                                          ),
                                          child: const SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Icon(
                                              Icons.open_in_full,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
        ),
        if (editable) ...[
          const SizedBox(height: HandySpace.m),
          Text(
            tr(
              context,
              'Drag over the picture to hide a part. Drag a cover to move it, its corner to resize.',
              'Kéo trên ảnh để che một phần. Kéo vùng che để dời, kéo góc để đổi cỡ.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              OutlinedButton(
                key: const Key('occlusion-add'),
                onPressed: current.masks.length >= 32
                    ? null
                    : () {
                        setState(() => selected = current.masks.length);
                        publish([
                          ...current.masks,
                          const OcclusionMask(
                            x: 0.25,
                            y: 0.25,
                            width: 0.25,
                            height: 0.25,
                          ),
                        ]);
                      },
                child: Text(tr(context, 'Add a cover', 'Thêm vùng che')),
              ),
              OutlinedButton(
                key: const Key('occlusion-delete'),
                // The last cover can go too: the picture stays, plain.
                onPressed: current.masks.isEmpty
                    ? null
                    : () {
                        final masks = [...current.masks]
                          ..removeAt(
                            selected.clamp(0, current.masks.length - 1),
                          );
                        setState(() => selected = 0);
                        publish(masks);
                      },
                child: Text(
                  tr(
                    context,
                    'Remove the chosen cover',
                    'Bỏ vùng che đang chọn',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
