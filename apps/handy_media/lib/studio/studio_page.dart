import 'package:handy_capture/handy_capture.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../guide/ids.dart';
import 'guide_card.dart';
import 'media_store.dart';
import 'open_guide.dart';

/// The studio: the guides being made, newest first, as film; then the
/// quick tools. Its question: "which guide, or a new one?"
class StudioPage extends StatefulWidget {
  final MediaStore store;
  final HandyFiles files;
  final ScanCamera? camera;
  const StudioPage({
    super.key,
    required this.store,
    required this.files,
    this.camera,
  });
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  String query = '';
  bool busy = false;
  MediaStore get store => widget.store;

  Future<void> run(Future<void> Function() task, {String? done}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (done != null && mounted) showHandyMessage(context, done);
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'Your guides are unchanged.', 'Các hướng dẫn vẫn giữ nguyên.')}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(PortableCapture guide) => run(
    () => openGuide(
      context,
      store: store,
      files: widget.files,
      camera: widget.camera,
      guide: guide,
    ),
  );

  Future<void> create() =>
      open(PortableCapture(CaptureProject.create(captureId('project')), {}));

  Future<void> import() => run(() async {
    final file = await widget.files.importBytes(
      extensions: ['zip', 'json'],
      maxBytes: 30000000,
    );
    if (file == null) return;
    await store.save(MediaStore.read(file.bytes), importing: true);
  }, done: tr(context, 'Guide added', 'Đã thêm hướng dẫn'));

  Future<void> delete(PortableCapture g) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this guide?', 'Xóa hướng dẫn này?'),
      message: tr(
        context,
        '${g.project.steps.length} steps and their pictures leave this device. Back it up first to keep a copy.',
        '${g.project.steps.length} bước cùng ảnh sẽ bị xóa khỏi máy. Hãy sao lưu trước nếu muốn giữ.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (ok) await run(() => store.remove(g.project.id));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('media-studio'),
    appBar: const HandyTopBar(
      mark: Icons.collections_outlined,
      name: 'Handy Media',
    ),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final all = store.guides;
        final terms = foldAccents(query.trim());
        final shown = terms.isEmpty
            ? all
            : all.where(
                (g) => foldAccents(
                  '${g.project.title} ${g.project.tags.join(' ')}',
                ).contains(terms),
              );
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            HandySpace.xxl,
          ),
          children: [
            HandyContent(
              maxWidth: HandySpace.contentWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, box) {
                      final title = Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            tr(context, 'Guides', 'Hướng dẫn'),
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      );
                      final more = HandyMenuButton(
                        items: [
                          HandyMenuItem(
                            Icons.unarchive_outlined,
                            tr(
                              context,
                              'Open a backup (ZIP or JSON)',
                              'Mở bản sao lưu (ZIP hoặc JSON)',
                            ),
                            busy ? null : import,
                            key: const Key('capture-import'),
                          ),
                        ],
                      );
                      final start = FilledButton.icon(
                        key: const Key('capture-new'),
                        onPressed: busy ? null : create,
                        icon: const Icon(Icons.add),
                        label: Text(tr(context, 'New guide', 'Hướng dẫn mới')),
                      );
                      if (box.maxWidth >= 420) {
                        return Row(children: [title, more, start]);
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [title, more]),
                          const SizedBox(height: HandySpace.s),
                          start,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: HandySpace.m),
                  if (all.length >= 6) ...[
                    HandySearchField(
                      hint: tr(
                        context,
                        'Find by name or tag',
                        'Tìm theo tên hoặc thẻ',
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: HandySpace.m),
                  ],
                  if (all.isEmpty)
                    Text(
                      tr(
                        context,
                        'Turn screenshots into numbered steps: point at what to tap, hide what is private, write what to do, and export it as a PDF, a web page or one long picture.',
                        'Biến ảnh chụp màn hình thành các bước đánh số: chỉ chỗ cần bấm, che chỗ riêng tư, ghi cần làm gì, rồi xuất thành PDF, trang web hay một ảnh dài.',
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  for (final g in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: HandySpace.m),
                      child: GuideCard(
                        key: ValueKey(g.project.id),
                        guide: g,
                        onOpen: busy ? null : () => open(g),
                        onDelete: busy ? null : () => delete(g),
                      ),
                    ),
                  const SizedBox(height: HandySpace.l),
                  HandySection(
                    title: tr(context, 'Quick tools', 'Công cụ nhanh'),
                    children: [
                      HandyTile(
                        key: const Key('studio-image'),
                        icon: Icons.photo_filter_outlined,
                        title: tr(context, 'Fix pictures', 'Sửa ảnh'),
                        subtitle: tr(
                          context,
                          'Crop, resize, convert, stamp, remove location',
                          'Cắt, đổi cỡ, đổi định dạng, đóng dấu, xóa vị trí',
                        ),
                        navigates: true,
                        onTap: () => Navigator.pushNamed(context, '/image'),
                      ),
                      HandyTile(
                        key: const Key('studio-subtitles'),
                        icon: Icons.closed_caption_outlined,
                        title: tr(context, 'Subtitles', 'Phụ đề'),
                        subtitle: tr(
                          context,
                          'Shift the timing, SRT and WebVTT',
                          'Dời thời gian, SRT và WebVTT',
                        ),
                        navigates: true,
                        onTap: () => Navigator.pushNamed(context, '/subtitles'),
                      ),
                      if (nativeCaptureAvailable)
                        HandyTile(
                          key: const Key('capture-native'),
                          icon: Icons.screenshot_monitor_outlined,
                          title: tr(
                            context,
                            'Capture the screen',
                            'Chụp màn hình',
                          ),
                          subtitle: tr(
                            context,
                            'Screenshots and recordings to mark up',
                            'Ảnh chụp và video để chú thích',
                          ),
                          navigates: true,
                          onTap: () => Navigator.pushNamed(context, '/capture'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}
