import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import 'scan/corner_canvas.dart';

export 'scan/corner_canvas.dart';

class CornerEditor extends StatefulWidget {
  final Uint8List bytes;
  final Future<void> Function(Uint8List png) onCommit;
  const CornerEditor({super.key, required this.bytes, required this.onCommit});
  @override
  State<CornerEditor> createState() => _CornerEditorState();
}

class _CornerEditorState extends State<CornerEditor> {
  late final ScanRaster raster;
  late final Uint8List preview;
  List<ScanPoint> corners = fullScanCorners();
  double contrast = 1, progress = 0;

  /// The kind of paper: it sets the tone and a starting contrast.
  ScanPreset preset = scanPresets.first;
  bool busy = false;
  String error = '';
  CancellationToken? cancellation;
  @override
  void initState() {
    super.initState();
    raster = decodeScanImage(widget.bytes);
    preview = encodeScanPng(raster);
  }

  @override
  void dispose() {
    cancellation?.cancel();
    super.dispose();
  }

  Future<void> apply() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
      progress = 0;
    });
    final token = CancellationToken();
    cancellation = token;
    try {
      final corrected = await rectifyScan(
        raster,
        corners,
        contrast: contrast,
        tone: preset.tone,
        cancellation: token,
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      token.check();
      await widget.onCommit(encodeScanPng(corrected));
      if (mounted) {
        setState(() => busy = false);
        Navigator.pop(context);
      }
    } on Cancelled {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Cancelled. The source and corners were preserved.',
            'Đã hủy. Ảnh gốc và bốn góc vẫn giữ nguyên.',
          ),
        );
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException
              ? e.message
              : tr(
                  context,
                  'Could not save. Keep this editor open and retry.',
                  'Không lưu được. Giữ màn hình này và thử lại.',
                ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Fix the corners', 'Sửa bốn góc')),
        actions: [
          TextButton(
            key: const Key('scan-reset-corners'),
            onPressed: busy
                ? null
                : () => setState(() {
                    corners = fullScanCorners();
                    preset = scanPresets.first;
                    contrast = 1;
                  }),
            child: Text(tr(context, 'Reset', 'Đặt lại')),
          ),
        ],
      ),
      bottomNavigationBar: HandyBottomBar(
        child: busy
            ? Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress == 0 ? null : progress,
                    ),
                  ),
                  const SizedBox(width: HandySpace.m),
                  TextButton(
                    onPressed: () => cancellation?.cancel(),
                    child: Text(tr(context, 'Cancel', 'Hủy')),
                  ),
                ],
              )
            : FilledButton(
                key: const Key('save-scan-page'),
                onPressed: apply,
                child: Text(tr(context, 'Save page', 'Lưu trang')),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HandySpace.l),
        children: [
          Text(
            tr(
              context,
              'Drag the four dots onto the corners of the paper, 1 at top left and on clockwise. The page is straightened from them.',
              'Kéo bốn chấm vào bốn góc tờ giấy, số 1 ở góc trên trái rồi theo chiều kim đồng hồ. Trang được nắn thẳng theo đó.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: HandySpace.l),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AbsorbPointer(
                absorbing: busy,
                child: CornerCanvas(
                  png: preview,
                  ratio: raster.width / raster.height,
                  corners: corners,
                  onChange: (v) => setState(() => corners = v),
                ),
              ),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          Text(
            tr(context, 'What is it?', 'Đây là gì?'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final p in scanPresets)
                ChoiceChip(
                  key: Key('scan-preset-${p.id}'),
                  label: Text(tr(context, p.en, p.vi)),
                  selected: p.id == preset.id,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                          preset = p;
                          contrast = p.contrast;
                        }),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.xs),
          Text(
            switch (preset.tone) {
              'gray' => tr(
                context,
                'Saved in grey: smaller, and text stands out.',
                'Lưu màu xám: nhẹ hơn, chữ rõ hơn.',
              ),
              'whiten' => tr(
                context,
                'The board is lifted to white; marker strokes stay.',
                'Nền bảng được làm trắng; nét bút giữ nguyên.',
              ),
              _ => tr(
                context,
                'Colours are kept as photographed.',
                'Giữ nguyên màu như ảnh chụp.',
              ),
            },
            key: const Key('scan-preset-note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: HandySpace.m),
          Row(
            children: [
              Text(
                tr(context, 'Contrast', 'Tương phản'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Expanded(
                child: Slider(
                  value: contrast,
                  min: 1,
                  max: 2.5,
                  divisions: 15,
                  label: contrast.toStringAsFixed(1),
                  semanticFormatterCallback: (v) => v.toStringAsFixed(1),
                  onChanged: busy ? null : (v) => setState(() => contrast = v),
                ),
              ),
              SizedBox(width: 32, child: Text(contrast.toStringAsFixed(1))),
            ],
          ),
          if (error.isNotEmpty) HandyNotice(error, tone: HandyTone.error),
        ],
      ),
    ),
  );
}
