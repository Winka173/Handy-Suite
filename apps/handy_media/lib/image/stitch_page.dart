import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import 'frame_page.dart';

Future<StitchResult> _stitch(List<Uint8List> shots) => stitchScreenshots(shots);

/// Screenshots of one long page, joined into one picture: pick them, put
/// them in order, join, look, save. Nothing leaves the device.
class StitchPage extends StatefulWidget {
  final HandyFiles files;

  /// Screenshots picked on the screenshots entry.
  final List<ImportedBytes> initial;
  const StitchPage({super.key, required this.files, this.initial = const []});
  @override
  State<StitchPage> createState() => _StitchPageState();
}

class _StitchPageState extends State<StitchPage> {
  late final shots = <ImportedBytes>[...widget.initial];
  StitchResult? result;
  String? error;
  bool busy = false;

  Future<void> pick() async {
    final files = widget.files;
    try {
      final picked = files is BatchHandyFiles
          ? await (files as BatchHandyFiles).importManyBytes(
              extensions: const ['png', 'jpg', 'jpeg', 'webp'],
              maxFiles: 20,
            )
          : [
              ?await files.importBytes(
                extensions: const ['png', 'jpg', 'jpeg', 'webp'],
                maxBytes: 20000000,
              ),
            ];
      if (picked.isEmpty || !mounted) return;
      setState(() {
        shots.addAll(picked.take(20 - shots.length));
        result = null;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  Future<void> join() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await compute(_stitch, [for (final s in shots) s.bytes]);
      if (mounted) setState(() => result = r);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(StitchResult r) async {
    try {
      final uri = await widget.files.exportBytes(
        'handy-media-joined.png',
        r.png,
        mimeType: 'image/png',
      );
      if (uri != null && mounted)
        showHandyMessage(
          context,
          tr(context, 'The long picture is saved.', 'Đã lưu ảnh dài.'),
        );
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = result;
    final unmatched = [
      if (r != null)
        for (final (i, k) in r.overlaps.indexed)
          if (k == 0) i + 2,
    ];
    return HandyPage(
      title: tr(context, 'Join screenshots', 'Nối ảnh chụp màn hình'),
      bottom: shots.length < 2
          ? null
          : r == null
          ? FilledButton(
              key: const Key('stitch-join'),
              onPressed: busy ? null : join,
              child: Text(
                tr(
                  context,
                  'Join ${shots.length} screenshots',
                  'Nối ${shots.length} ảnh',
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('stitch-save'),
                    onPressed: () => save(r),
                    child: Text(
                      tr(context, 'Save the long picture', 'Lưu ảnh dài'),
                    ),
                  ),
                ),
                const SizedBox(width: HandySpace.s),
                OutlinedButton(
                  key: const Key('stitch-frame'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          FramePage(files: widget.files, initial: r.png),
                    ),
                  ),
                  child: Text(tr(context, 'Frame it', 'Đóng khung')),
                ),
              ],
            ),
      children: [
        if (shots.isEmpty)
          HandyEmpty(
            title: tr(
              context,
              'One long page from several screenshots',
              'Một trang dài từ nhiều ảnh chụp',
            ),
            message: tr(
              context,
              'Take them top to bottom, each sharing a little of the one before. The bars that stay put are kept once.',
              'Chụp lần lượt từ trên xuống, ảnh sau trùng một đoạn với ảnh trước. Các thanh cố định chỉ giữ một lần.',
            ),
            action: FilledButton(
              key: const Key('stitch-pick'),
              onPressed: pick,
              child: Text(tr(context, 'Choose screenshots', 'Chọn ảnh chụp')),
            ),
          )
        else ...[
          HandyLabel(
            tr(
              context,
              'In order, top to bottom',
              'Theo thứ tự, từ trên xuống',
            ),
            trailing: shots.length >= 20
                ? null
                : TextButton(
                    key: const Key('stitch-add'),
                    onPressed: busy ? null : pick,
                    child: Text(tr(context, 'Add', 'Thêm')),
                  ),
          ),
          // The strip of shots: drag to reorder, or move with the arrows.
          SizedBox(
            height: 200,
            child: ReorderableListView.builder(
              key: const Key('stitch-strip'),
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: !busy,
              itemCount: shots.length,
              onReorderItem: (from, to) => setState(() {
                shots.insert(to, shots.removeAt(from));
                result = null;
              }),
              itemBuilder: (context, i) => Padding(
                key: ObjectKey(shots[i]),
                padding: const EdgeInsets.only(right: HandySpace.s),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          HandyRadius.control,
                        ),
                        child: Image.memory(
                          shots[i].bytes,
                          fit: BoxFit.contain,
                          cacheHeight: 320,
                          semanticLabel: tr(
                            context,
                            'Screenshot ${i + 1}: ${shots[i].name}',
                            'Ảnh ${i + 1}: ${shots[i].name}',
                          ),
                          errorBuilder: (_, e, st) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${i + 1}', style: theme.textTheme.labelLarge),
                        IconButton(
                          key: Key('stitch-remove-$i'),
                          tooltip: tr(context, 'Remove', 'Bỏ ảnh này'),
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  shots.removeAt(i);
                                  result = null;
                                }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (shots.length == 1)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: Text(
                tr(
                  context,
                  'Add at least one more screenshot.',
                  'Thêm ít nhất một ảnh nữa.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            ),
        ],
        if (busy) ...[
          const SizedBox(height: HandySpace.l),
          const LinearProgressIndicator(),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(context, 'Matching the overlaps…', 'Đang khớp các đoạn trùng…'),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.l),
            child: HandyNotice(error!, tone: HandyTone.error),
          ),
        if (r != null) ...[
          HandyLabel(tr(context, 'The long picture', 'Ảnh dài')),
          Text(
            '${formatFigure(context, '${r.width}')} × ${formatFigure(context, '${r.height}')} px',
            key: const Key('stitch-size'),
            style: theme.textTheme.bodyMedium,
          ),
          if (unmatched.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: HandyNotice(
                tr(
                  context,
                  'No overlap found before screenshot ${unmatched.join(', ')}: it was added below as it is. Check the order, or retake it to share a little with the one before.',
                  'Không thấy đoạn trùng trước ảnh ${unmatched.join(', ')}: ảnh được nối thẳng bên dưới. Kiểm tra thứ tự, hoặc chụp lại cho trùng một đoạn với ảnh trước.',
                ),
                tone: HandyTone.warning,
              ),
            ),
          const SizedBox(height: HandySpace.m),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Image.memory(
                r.png,
                key: const Key('stitch-result'),
                fit: BoxFit.fitWidth,
                semanticLabel: tr(context, 'The joined picture', 'Ảnh đã nối'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
