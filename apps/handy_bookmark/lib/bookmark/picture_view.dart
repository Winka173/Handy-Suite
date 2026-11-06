import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';

/// A picture the person saved, whole and zoomable, on black. Shows the
/// original bytes, not the preview.
class PictureView extends StatelessWidget {
  final SaveController controller;
  final Bookmark item;
  const PictureView({super.key, required this.controller, required this.item});

  static Future<void> open(
    BuildContext context,
    SaveController controller,
    Bookmark item,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PictureView(controller: controller, item: item),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final media = item.media!;
    final name = item.title.isNotEmpty
        ? item.title
        : tr(context, 'Picture', 'Ảnh');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<Uint8List?>(
        future: controller.mediaOriginal(media.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.data == null)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(HandySpace.xl),
                child: Text(
                  tr(
                    context,
                    'This picture is missing on this device. Restore a full backup to bring it back.',
                    'Ảnh này không còn trên máy. Khôi phục một bản sao lưu đầy đủ để lấy lại.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          return InteractiveViewer(
            maxScale: 8,
            child: Center(
              child: Semantics(
                image: true,
                label: name,
                child: Image.memory(
                  snap.data!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The picture at its own proportions, as wide as it may be; tap to see it
/// whole. Used on the detail page.
class PictureHeader extends StatelessWidget {
  final SaveController controller;
  final Bookmark item;
  final double maxHeight;
  const PictureHeader({
    super.key,
    required this.controller,
    required this.item,
    this.maxHeight = 420,
  });

  @override
  Widget build(BuildContext context) {
    final media = item.media!;
    final c = HandyColors.of(context);
    final ratio = media.width / media.height;
    return Semantics(
      button: true,
      label: tr(context, 'View the picture', 'Xem ảnh'),
      child: InkWell(
        key: const Key('detail-picture'),
        borderRadius: BorderRadius.circular(HandyRadius.control),
        onTap: () => PictureView.open(context, controller, item),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AspectRatio(
            aspectRatio: ratio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(HandyRadius.control),
              child: FutureBuilder<Uint8List?>(
                future: controller.mediaPreview(media.id),
                builder: (context, snap) => snap.data == null
                    ? ColoredBox(color: c.select)
                    : Image.memory(
                        snap.data!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
