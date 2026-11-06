import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import 'detail_facts.dart' show fileSize;

/// The viewer's own colours: it is always on black, whatever the app's
/// theme, so its words and marks are always light.
abstract final class PictureViewColors {
  static const ground = Colors.black;
  static const ink = Color(0xFFF7F7F5);
  static const muted = Color(0xFFC9CCC9);
  static const panel = Color(0xFF1E2221);
}

/// A picture the person saved, whole and zoomable, on black. Shows the
/// original bytes; when only the small preview is left on this device it
/// shows that and says so.
class PictureView extends StatefulWidget {
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
  State<PictureView> createState() => _PictureViewState();
}

class _PictureViewState extends State<PictureView> {
  late final Future<Uint8List?> original = widget.controller.mediaOriginal(
    widget.item.media!.id,
  );
  late final Future<Uint8List?> preview = widget.controller.mediaPreview(
    widget.item.media!.id,
  );

  @override
  Widget build(BuildContext context) {
    final media = widget.item.media!;
    final name = widget.item.title.isNotEmpty
        ? widget.item.title
        : tr(context, 'Picture', 'Ảnh');
    final theme = Theme.of(context);
    final file = [
      if (media.name.isNotEmpty &&
          media.name.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '') != name)
        media.name,
      '${media.width} × ${media.height}',
      fileSize(media.bytes),
    ].join(' · ');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: const Key('picture-view'),
          backgroundColor: PictureViewColors.ground,
          appBar: AppBar(
            backgroundColor: PictureViewColors.ground,
            foregroundColor: PictureViewColors.ink,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            iconTheme: const IconThemeData(color: PictureViewColors.ink),
            actionsIconTheme: const IconThemeData(color: PictureViewColors.ink),
            leading: IconButton(
              key: const Key('picture-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              style: IconButton.styleFrom(
                foregroundColor: PictureViewColors.ink,
              ),
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.maybePop(context),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  key: const Key('picture-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: PictureViewColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  file,
                  key: const Key('picture-file'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: PictureViewColors.muted,
                  ),
                ),
              ],
            ),
          ),
          body: FutureBuilder<Uint8List?>(
            future: original,
            builder: (context, full) => FutureBuilder<Uint8List?>(
              future: preview,
              builder: (context, small) {
                if (full.connectionState != ConnectionState.done) {
                  // The preview stands in while the original loads.
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (small.data != null) _picture(small.data!, name),
                      const Center(
                        child: CircularProgressIndicator(
                          color: PictureViewColors.ink,
                        ),
                      ),
                    ],
                  );
                }
                if (full.data != null) return _zoom(full.data!, name);
                if (small.data != null)
                  return Column(
                    children: [
                      Expanded(child: _zoom(small.data!, name)),
                      _note(
                        context,
                        tr(
                          context,
                          'Only a small preview is on this device. Restore a full backup to see the original.',
                          'Máy này chỉ còn ảnh xem trước cỡ nhỏ. Khôi phục một bản sao lưu đầy đủ để xem ảnh gốc.',
                        ),
                        key: const Key('picture-preview-only'),
                      ),
                    ],
                  );
                if (small.connectionState != ConnectionState.done)
                  return const SizedBox.shrink();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(HandySpace.xl),
                    child: Text(
                      tr(
                        context,
                        'This picture is missing on this device. Restore a full backup to bring it back.',
                        'Ảnh này không còn trên máy. Khôi phục một bản sao lưu đầy đủ để lấy lại.',
                      ),
                      key: const Key('picture-missing'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: PictureViewColors.ink,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _picture(Uint8List bytes, String name) => Center(
    child: Semantics(
      image: true,
      label: name,
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, _, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_outlined,
              color: PictureViewColors.ink,
              size: 48,
            ),
            const SizedBox(height: HandySpace.s),
            Text(
              tr(
                context,
                'This picture could not be shown.',
                'Chưa hiển thị được ảnh này.',
              ),
              style: const TextStyle(color: PictureViewColors.ink),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _zoom(Uint8List bytes, String name) =>
      InteractiveViewer(maxScale: 8, child: _picture(bytes, name));

  Widget _note(BuildContext context, String text, {Key? key}) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(HandySpace.l),
      child: Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.all(HandySpace.l),
        decoration: BoxDecoration(
          color: PictureViewColors.panel,
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
        ),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: PictureViewColors.ink),
        ),
      ),
    ),
  );
}

/// The picture at its own proportions, uncropped, as large as the column
/// allows (a tall one stands centred); tap to see it whole. Used on the
/// detail page. Only the preview is decoded here.
class PictureHeader extends StatelessWidget {
  final SaveController controller;
  final Bookmark item;
  final double maxHeight;
  const PictureHeader({
    super.key,
    required this.controller,
    required this.item,
    this.maxHeight = 460,
  });

  @override
  Widget build(BuildContext context) {
    final media = item.media!;
    final p = BookmarkPalette.of(context);
    final ratio = media.height > 0 ? media.width / media.height : 1.0;
    return LayoutBuilder(
      builder: (context, box) {
        final width = math.min(box.maxWidth, maxHeight * ratio);
        final height = width / ratio;
        return Center(
          child: Semantics(
            button: true,
            label: tr(context, 'View the picture', 'Xem ảnh'),
            child: SizedBox(
              width: width,
              height: height,
              child: Material(
                color: p.sunk,
                borderRadius: BorderRadius.circular(BookmarkRadii.collection),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('detail-picture'),
                  onTap: () => PictureView.open(context, controller, item),
                  child: FutureBuilder<Uint8List?>(
                    future: controller.mediaPreview(media.id),
                    builder: (context, snap) => snap.data == null
                        ? const SizedBox.expand()
                        : Ink.image(
                            image: MemoryImage(snap.data!),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
