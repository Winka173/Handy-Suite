import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

Uint8List _frame((Uint8List, ShotFrame) job) => frameScreenshot(job.$1, job.$2);
Uint8List _preview(Uint8List source) => framePreviewSource(source);

/// Flat grounds for a framed screenshot; null is the shot's own colour.
const frameGrounds = <(int?, String, String)>[
  (0xFFF2F2F2, 'Paper', 'Giấy'),
  (0xFF1A1A1A, 'Ink', 'Mực'),
  (0xFF2F6FB0, 'Blue', 'Xanh dương'),
  (0xFF2E7D32, 'Green', 'Xanh lá'),
  (0xFFE8590C, 'Orange', 'Cam'),
  (0xFFC2185B, 'Raspberry', 'Mâm xôi'),
  (null, 'From the shot', 'Theo màu ảnh'),
  (ShotFrame.transparent, 'Clear', 'Trong suốt'),
];

/// A screenshot made ready to share: a ground, space, rounded corners, a
/// shadow and an optional phone or browser frame. The preview is the whole
/// first block; the export is the full-size PNG. Nothing leaves the device.
class FramePage extends StatefulWidget {
  final HandyFiles files;
  const FramePage({super.key, required this.files});
  @override
  State<FramePage> createState() => _FramePageState();
}

class _FramePageState extends State<FramePage> {
  Uint8List? source, small, preview;
  ShotFrame frame = const ShotFrame();
  String? error;
  bool working = false, saving = false;
  Timer? _debounce;
  int _job = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final file = await widget.files.importBytes(
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
        maxBytes: 20000000,
      );
      if (file == null || !mounted) return;
      setState(() {
        source = file.bytes;
        small = null;
        preview = null;
        error = null;
        working = true;
      });
      final s = await compute(_preview, file.bytes);
      if (!mounted) return;
      small = s;
      refresh(now: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorText(context, e);
          working = false;
        });
      }
    }
  }

  void change(ShotFrame next) {
    setState(() => frame = next);
    refresh();
  }

  void refresh({bool now = false}) {
    _debounce?.cancel();
    _debounce = Timer(
      now ? Duration.zero : const Duration(milliseconds: 120),
      () async {
        final s = small;
        if (s == null) return;
        final job = ++_job;
        setState(() => working = true);
        try {
          final out = await compute(_frame, (s, frame));
          if (mounted && job == _job) {
            setState(() {
              preview = out;
              working = false;
              error = null;
            });
          }
        } catch (e) {
          if (mounted && job == _job) {
            setState(() {
              error = errorText(context, e);
              working = false;
            });
          }
        }
      },
    );
  }

  Future<void> save() async {
    final s = source;
    if (s == null) return;
    setState(() => saving = true);
    try {
      final png = await compute(_frame, (s, frame));
      final uri = await widget.files.exportBytes(
        'handy-media-framed.png',
        png,
        mimeType: 'image/png',
      );
      if (uri != null && mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'The framed picture is saved.',
            'Đã lưu ảnh đã đóng khung.',
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  ShotFrame _with({
    Object? background = _same,
    double? padding,
    double? radius,
    bool? shadow,
    String? device,
  }) => ShotFrame(
    background: identical(background, _same)
        ? frame.background
        : background as int?,
    padding: padding ?? frame.padding,
    radius: radius ?? frame.radius,
    shadow: shadow ?? frame.shadow,
    device: device ?? frame.device,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final p = preview;
    Widget slider(
      String label,
      String value,
      double v,
      double max,
      ValueChanged<double> on,
      String key,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          label,
          trailing: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: tabular),
          ),
        ),
        Slider.adaptive(key: Key(key), value: v, max: max, onChanged: on),
      ],
    );
    return HandyPage(
      title: tr(context, 'Frame a screenshot', 'Khung ảnh chụp màn hình'),
      bottom: source == null
          ? null
          : FilledButton(
              key: const Key('frame-save'),
              onPressed: saving || error != null ? null : save,
              child: Text(
                saving
                    ? tr(context, 'Saving…', 'Đang lưu…')
                    : tr(context, 'Save the PNG', 'Lưu ảnh PNG'),
              ),
            ),
      children: [
        if (source == null)
          HandyEmpty(
            title: tr(
              context,
              'A screenshot ready to share',
              'Ảnh chụp sẵn sàng để chia sẻ',
            ),
            message: tr(
              context,
              'Add a ground, space, rounded corners and a shadow, or put it in a phone or browser frame. Saved at full size.',
              'Thêm nền, khoảng trống, bo góc và bóng, hoặc đặt vào khung điện thoại hay trình duyệt. Lưu đúng kích thước gốc.',
            ),
            action: FilledButton(
              key: const Key('frame-pick'),
              onPressed: pick,
              child: Text(tr(context, 'Choose a screenshot', 'Chọn ảnh chụp')),
            ),
          )
        else ...[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .55,
            ),
            child: Center(
              child: p == null
                  ? const Padding(
                      padding: EdgeInsets.all(HandySpace.xxl),
                      child: CircularProgressIndicator(),
                    )
                  : Semantics(
                      image: true,
                      label: tr(
                        context,
                        'Framed screenshot preview',
                        'Xem trước ảnh đã đóng khung',
                      ),
                      child: Image.memory(
                        p,
                        key: const Key('frame-preview'),
                        gaplessPlayback: true,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: HandySpace.s),
            Text(error!, style: TextStyle(color: c.negative)),
          ],
          HandyLabel(
            tr(context, 'Ground', 'Nền'),
            trailing: TextButton(
              key: const Key('frame-another'),
              onPressed: pick,
              child: Text(tr(context, 'Another shot', 'Ảnh khác')),
            ),
          ),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final (i, (argb, en, vi)) in frameGrounds.indexed)
                Tooltip(
                  message: tr(context, en, vi),
                  child: Semantics(
                    button: true,
                    selected: frame.background == argb,
                    label: tr(context, en, vi),
                    child: InkWell(
                      key: Key('frame-ground-$i'),
                      customBorder: const CircleBorder(),
                      onTap: () => change(_with(background: argb)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: argb == null || argb == ShotFrame.transparent
                              ? null
                              : Color(argb),
                          border: Border.all(
                            color: frame.background == argb
                                ? c.accent
                                : c.border,
                            width: frame.background == argb ? 3 : 1,
                          ),
                        ),
                        child: argb == null
                            ? Icon(Icons.colorize, size: 18, color: c.muted)
                            : argb == ShotFrame.transparent
                            ? Icon(Icons.grid_on, size: 18, color: c.muted)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          slider(
            tr(context, 'Space around', 'Khoảng trống'),
            '${(frame.padding * 100).round()}%',
            frame.padding,
            .25,
            (v) => change(_with(padding: v)),
            'frame-padding',
          ),
          slider(
            tr(context, 'Corners', 'Bo góc'),
            '${frame.radius.round()} px',
            frame.radius,
            48,
            (v) => change(_with(radius: v)),
            'frame-radius',
          ),
          HandyLabel(tr(context, 'Frame', 'Khung')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final (id, en, vi) in const [
                ('none', 'None', 'Không'),
                ('phone', 'Phone', 'Điện thoại'),
                ('browser', 'Browser', 'Trình duyệt'),
              ])
                ChoiceChip(
                  key: Key('frame-device-$id'),
                  label: Text(tr(context, en, vi)),
                  selected: frame.device == id,
                  onSelected: (_) => change(_with(device: id)),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.s),
          SwitchListTile.adaptive(
            key: const Key('frame-shadow'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Shadow', 'Đổ bóng')),
            value: frame.shadow,
            onChanged: (v) => change(_with(shadow: v)),
          ),
          if (working)
            Text(
              tr(
                context,
                'Updating the preview…',
                'Đang cập nhật bản xem trước…',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
        ],
      ],
    );
  }
}

const _same = Object();
