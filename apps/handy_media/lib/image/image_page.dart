import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../crop_canvas.dart';
import 'image_desk.dart';
import 'image_result.dart';
import 'tool_settings.dart';

const _tools = [
  ('crop', Icons.crop, 'Crop', 'Cắt'),
  ('resize', Icons.photo_size_select_large, 'Size', 'Cỡ'),
  ('convert', Icons.swap_horiz, 'Format', 'Định dạng'),
  ('watermark', Icons.branding_watermark_outlined, 'Stamp', 'Đóng dấu'),
  ('metadata', Icons.location_off_outlined, 'Location', 'Vị trí'),
];

/// Fixing pictures: the picture large, the fix beside it, the result
/// under the fix. Format and Stamp apply to every picture open.
class ImagePage extends StatefulWidget {
  final HandyFiles files;
  final ScanCamera? camera;
  final String tool;
  const ImagePage({
    super.key,
    required this.files,
    this.camera,
    this.tool = 'crop',
  });
  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  late final d = ImageDesk(tool: widget.tool);
  late final ScanCamera camera = widget.camera ?? SystemScanCamera();
  bool busy = false;
  CancellationToken? token;
  ImportedBytes? recovered;

  @override
  void initState() {
    super.initState();
    if (camera.supported) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final photo = await camera.recover();
          if (photo != null && mounted) setState(() => recovered = photo);
        } catch (_) {
          // Nothing to offer back.
        }
      });
    }
  }

  @override
  void dispose() {
    token?.cancel();
    d.dispose();
    super.dispose();
  }

  Future<void> run(
    Future<void> Function(CancellationToken t) task, {
    bool cancellable = false,
  }) async {
    if (busy) return;
    final t = CancellationToken();
    setState(() {
      busy = true;
      if (cancellable) token = t;
    });
    try {
      await task(t);
    } on Cancelled {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Canceled. Your pictures are unchanged.',
            'Đã hủy. Các ảnh vẫn giữ nguyên.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'Your pictures are unchanged.', 'Các ảnh vẫn giữ nguyên.')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          token = null;
        });
      }
    }
  }

  Future<void> add() => run((t) async {
    final files = widget.files;
    final picked = files is BatchHandyFiles
        ? await (files as BatchHandyFiles).importManyBytes(
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            maxFiles: ImageDesk.maxFiles - d.sources.length,
            maxTotalBytes: ImageDesk.maxBytes - d.bytes,
            cancellation: t,
          )
        : [
            ?await files.importBytes(
              extensions: ['png', 'jpg', 'jpeg', 'webp'],
              maxBytes: 20000000,
              cancellation: t,
            ),
          ];
    d.accept(picked, token: t);
  });

  Future<void> photo() => run((_) async {
    final p = await camera.capture();
    if (p != null) d.accept([p]);
  });

  Future<void> logo() => run((_) async {
    final f = await widget.files.importBytes(
      extensions: ['png'],
      maxBytes: 20000000,
    );
    if (f == null) return;
    decodeBoundedImage(f.bytes, allowWebP: true);
    d.set(() => d.logo = f.bytes);
  });

  Future<void> save() => run((t) async {
    final f = d.file();
    final uri = await widget.files.exportBytes(
      f.name,
      f.bytes,
      mimeType: f.mime,
      cancellation: t,
    );
    if (mounted)
      showHandyMessage(
        context,
        uri == null
            ? tr(context, 'Export canceled', 'Đã hủy xuất')
            : tr(context, 'Saved', 'Đã lưu'),
      );
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: d,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Fix pictures', 'Sửa ảnh')),
          actions: [
            if (camera.supported)
              IconButton(
                key: const Key('media-camera'),
                tooltip: tr(context, 'Take a photo', 'Chụp ảnh'),
                onPressed: busy ? null : photo,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
            if (d.sources.isNotEmpty)
              TextButton.icon(
                key: const Key('media-import'),
                onPressed: busy ? null : add,
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Add', 'Thêm')),
              ),
            const SizedBox(width: HandySpace.xs),
          ],
        ),
        bottomNavigationBar: token == null
            ? null
            : HandyBottomBar(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.status.isEmpty
                            ? tr(context, 'Working…', 'Đang xử lý…')
                            : tr(
                                context,
                                '${d.status.length} of ${d.sources.length} done',
                                'Xong ${d.status.length}/${d.sources.length}',
                              ),
                      ),
                    ),
                    TextButton(
                      key: const Key('media-cancel'),
                      onPressed: token?.cancel,
                      child: Text(tr(context, 'Cancel', 'Hủy')),
                    ),
                  ],
                ),
              ),
        body: Column(
          children: [
            if (recovered != null)
              Padding(
                padding: const EdgeInsets.all(HandySpace.m),
                child: HandyNotice(
                  tr(
                    context,
                    'A photo was taken while the app was closed.',
                    'Có một ảnh chụp lúc app bị đóng.',
                  ),
                  action: TextButton(
                    key: const Key('media-camera-recovered'),
                    onPressed: () => run((_) async {
                      d.accept([recovered!]);
                      setState(() => recovered = null);
                    }),
                    child: Text(tr(context, 'Use it', 'Dùng ảnh này')),
                  ),
                ),
              ),
            Expanded(
              child: d.sources.isEmpty
                  ? _empty(context)
                  : LayoutBuilder(builder: _layout),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _empty(BuildContext context) => HandyEmpty(
    title: tr(context, 'Open the pictures to fix', 'Mở các ảnh cần sửa'),
    message: tr(
      context,
      'PNG, JPEG or WebP, up to 20 MB each; up to 50 at once for a new format or a stamp. The originals are never changed.',
      'PNG, JPEG hoặc WebP, mỗi ảnh tối đa 20 MB; tối đa 50 ảnh một lần khi đổi định dạng hay đóng dấu. Ảnh gốc không bao giờ bị sửa.',
    ),
    action: FilledButton.icon(
      key: const Key('media-import'),
      onPressed: busy ? null : add,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: Text(tr(context, 'Open pictures', 'Mở ảnh')),
    ),
  );

  Widget _layout(BuildContext context, BoxConstraints box) {
    final wide = box.maxWidth >= 900;
    final picture = d.tool == 'crop'
        ? CropCanvas(
            png: d.preview!,
            ratio: d.ratio,
            region: d.region,
            onChange: busy ? (_) {} : (r) => d.set(() => d.region = r),
          )
        : Center(
            child: Image.memory(
              d.preview!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              semanticLabel: d.chosen!.name,
            ),
          );
    final strip = SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
        children: [
          for (final (i, f) in d.sources.indexed)
            Padding(
              padding: const EdgeInsets.only(right: HandySpace.s),
              child: InputChip(
                key: Key('media-source-$i'),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(
                    '${i + 1}. ${f.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                selected: i == d.selected,
                showCheckmark: false,
                onSelected: busy ? null : (_) => d.choose(i),
                deleteButtonTooltipMessage: tr(
                  context,
                  'Close ${f.name}',
                  'Đóng ${f.name}',
                ),
                onDeleted: busy ? null : () => d.remove(i),
              ),
            ),
        ],
      ),
    );
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          key: const Key('media-tool'),
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final (id, icon, en, vi) in _tools)
              ChoiceChip(
                key: Key('media-tool-$id'),
                avatar: Icon(icon, size: 18),
                label: Text(tr(context, en, vi)),
                selected: d.tool == id,
                showCheckmark: false,
                onSelected: busy ? null : (_) => d.pick(id),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        ToolSettings(d: d, busy: busy, onLogo: logo),
        const SizedBox(height: HandySpace.l),
        FilledButton(
          key: const Key('media-apply'),
          onPressed: busy ? null : () => run(d.apply, cancellable: true),
          child: Text(
            d.batch && d.sources.length > 1
                ? tr(
                    context,
                    'Apply to ${d.sources.length} pictures',
                    'Áp dụng cho ${d.sources.length} ảnh',
                  )
                : tr(context, 'Apply', 'Áp dụng'),
          ),
        ),
        ImageResult(d: d, busy: busy, onSave: save),
      ],
    );
    if (!wide) {
      return ListView(
        padding: const EdgeInsets.only(bottom: HandySpace.xxl),
        children: [
          strip,
          SizedBox(
            height: box.maxHeight * .5,
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.s),
              child: picture,
            ),
          ),
          Padding(padding: const EdgeInsets.all(HandySpace.l), child: panel),
        ],
      );
    }
    final colors = HandyColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: colors.ground,
            child: Column(
              children: [
                const SizedBox(height: HandySpace.s),
                strip,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(HandySpace.l),
                    child: picture,
                  ),
                ),
              ],
            ),
          ),
        ),
        VerticalDivider(width: 1, color: colors.rule),
        SizedBox(
          width: 400,
          child: ListView(
            padding: const EdgeInsets.all(HandySpace.xl),
            children: [panel],
          ),
        ),
      ],
    );
  }
}
