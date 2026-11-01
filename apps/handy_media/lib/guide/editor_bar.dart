import 'package:handy_ui/kit.dart';
import 'editor_actions.dart';
import 'editor_page.dart';

/// Back, the guide's name, undo and redo, Save, Export and the rest.
class EditorBar extends StatelessWidget implements PreferredSizeWidget {
  final CaptureEditorState state;
  const EditorBar({super.key, required this.state});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final c = state.c, busy = state.busy;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final step = c.step, layer = c.layer;
    final box = const {'rect', 'highlight', 'redact', 'spotlight'};
    return AppBar(
      toolbarHeight: 60,
      leading: BackButton(onPressed: busy ? null : state.leave),
      titleSpacing: 0,
      title: TextField(
        key: const Key('capture-title'),
        controller: c.title,
        enabled: !busy,
        maxLength: 200,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: InputDecoration(
          hintText: tr(context, 'Name this guide', 'Đặt tên hướng dẫn'),
          counterText: '',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
        ),
      ),
      actions: [
        if (wide) ...[
          IconButton(
            key: const Key('capture-undo'),
            tooltip: tr(context, 'Undo', 'Hoàn tác'),
            onPressed: busy || !c.canUndo ? null : () => c.history(true),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            key: const Key('capture-redo'),
            tooltip: tr(context, 'Redo', 'Làm lại'),
            onPressed: busy || !c.canRedo ? null : () => c.history(false),
            icon: const Icon(Icons.redo),
          ),
        ],
        TextButton(
          key: const Key('capture-save'),
          onPressed: busy ? null : state.save,
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: HandySpace.xs),
          child: wide
              ? FilledButton.icon(
                  key: const Key('guide-export-options'),
                  onPressed: busy || c.project.steps.isEmpty
                      ? null
                      : state.exportGuide,
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(tr(context, 'Export', 'Xuất')),
                )
              : IconButton.filled(
                  key: const Key('guide-export-options'),
                  tooltip: tr(context, 'Export', 'Xuất'),
                  onPressed: busy || c.project.steps.isEmpty
                      ? null
                      : state.exportGuide,
                  icon: const Icon(Icons.ios_share),
                ),
        ),
        HandyMenuButton(
          items: [
            if (!wide) ...[
              HandyMenuItem(
                Icons.undo,
                tr(context, 'Undo', 'Hoàn tác'),
                busy || !c.canUndo ? null : () => c.history(true),
                key: const Key('capture-undo'),
              ),
              HandyMenuItem(
                Icons.redo,
                tr(context, 'Redo', 'Làm lại'),
                busy || !c.canRedo ? null : () => c.history(false),
                key: const Key('capture-redo'),
              ),
            ],
            HandyMenuItem(
              Icons.info_outline,
              tr(context, 'About this guide', 'Thông tin hướng dẫn'),
              busy ? null : state.details,
              key: const Key('capture-project-details'),
            ),
            if (step != null && c.picture != null) ...[
              HandyMenuItem(
                Icons.rotate_90_degrees_cw_outlined,
                tr(context, 'Turn this picture', 'Xoay ảnh này'),
                busy ? null : () => state.editPicture('rotate'),
                key: const Key('capture-image-rotate'),
              ),
              HandyMenuItem(
                Icons.photo_size_select_large,
                tr(context, 'Halve this picture', 'Giảm nửa cỡ ảnh'),
                busy ? null : () => state.editPicture('resize'),
                key: const Key('capture-image-resize'),
              ),
              HandyMenuItem(
                Icons.crop,
                tr(
                  context,
                  'Crop to the chosen box',
                  'Cắt theo khung đang chọn',
                ),
                busy || layer == null || !box.contains(layer.kind)
                    ? null
                    : () => state.editPicture('crop'),
                key: const Key('capture-image-crop'),
              ),
              if (localShareSupported)
                HandyMenuItem(
                  Icons.share_outlined,
                  tr(
                    context,
                    'Share this step as a picture',
                    'Chia sẻ bước này thành ảnh',
                  ),
                  busy ? null : state.sharePicture,
                  key: const Key('capture-share-png'),
                ),
              HandyMenuItem(
                Icons.image_outlined,
                tr(
                  context,
                  'Save this step as a picture',
                  'Lưu bước này thành ảnh',
                ),
                busy ? null : state.savePicture,
                key: const Key('capture-save-png'),
              ),
            ],
            HandyMenuItem(
              Icons.folder_zip_outlined,
              tr(
                context,
                'Back up to move it (ZIP)',
                'Sao lưu để chuyển máy (ZIP)',
              ),
              busy || c.project.steps.isEmpty ? null : () => state.backup(true),
              key: const Key('capture-backup-zip'),
            ),
            HandyMenuItem(
              Icons.data_object,
              tr(
                context,
                'Back up the words (JSON)',
                'Sao lưu phần chữ (JSON)',
              ),
              busy ? null : () => state.backup(false),
              key: const Key('capture-backup-json'),
            ),
          ],
        ),
        const SizedBox(width: HandySpace.xs),
      ],
    );
  }
}
