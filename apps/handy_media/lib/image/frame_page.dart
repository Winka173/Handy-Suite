import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';

Uint8List _frame((Uint8List, ShotFrame, Uint8List?) job) =>
    frameScreenshot(job.$1, job.$2, header: job.$3);
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

/// Two-colour grounds (top left to bottom right).
const frameGradients = <(int, int, String, String)>[
  (0xFF0F766E, 0xFF2F6FB0, 'Sea', 'Biển'),
  (0xFFE8590C, 0xFFC2185B, 'Sunset', 'Hoàng hôn'),
  (0xFF7DD3FC, 0xFFE0F2FE, 'Sky', 'Trời'),
  (0xFFD1FAE5, 0xFF6EE7B7, 'Mint', 'Bạc hà'),
  (0xFF1A1A1A, 0xFF4B5563, 'Graphite', 'Than chì'),
  (0xFFF5EBDD, 0xFFE9C9A6, 'Sand', 'Cát'),
];

/// One-tap looks: a ground, a frame, a shape. Each is a different
/// arrangement, not only a colour; every value can be changed after.
const framePresets = <(String, String, String, ShotFrame)>[
  ('clean', 'Clean', 'Gọn gàng', ShotFrame()),
  ('ink', 'Ink', 'Mực', ShotFrame(background: 0xFF1A1A1A, padding: .1)),
  (
    'story',
    'Story 9:16',
    'Story 9:16',
    ShotFrame(
      background: 0xFFE8590C,
      background2: 0xFFC2185B,
      device: 'phone',
      aspect: '9:16',
      padding: .1,
    ),
  ),
  (
    'phone-sea',
    'Phone on sea',
    'Điện thoại, nền biển',
    ShotFrame(
      background: 0xFF0F766E,
      background2: 0xFF2F6FB0,
      device: 'phone',
      padding: .12,
    ),
  ),
  (
    'slide',
    'Slide 16:9',
    'Slide 16:9',
    ShotFrame(
      background: 0xFF1A1A1A,
      background2: 0xFF4B5563,
      device: 'browser',
      aspect: '16:9',
      radius: 16,
    ),
  ),
  (
    'browser-sky',
    'Browser on sky',
    'Trình duyệt, nền trời',
    ShotFrame(
      background: 0xFF7DD3FC,
      background2: 0xFFE0F2FE,
      device: 'browser',
      radius: 12,
    ),
  ),
  (
    'square',
    'Square post',
    'Bài vuông',
    ShotFrame(
      background: 0xFFD1FAE5,
      background2: 0xFF6EE7B7,
      aspect: '1:1',
      padding: .1,
    ),
  ),
  (
    'portrait',
    'Portrait post 4:5',
    'Bài dọc 4:5',
    ShotFrame(background: 0xFFF2F2F2, device: 'phone', aspect: '4:5'),
  ),
  (
    'sand',
    'Sand',
    'Cát',
    ShotFrame(
      background: 0xFFF5EBDD,
      background2: 0xFFE9C9A6,
      radius: 36,
      padding: .14,
    ),
  ),
  (
    'own',
    'Its own colour',
    'Theo màu ảnh',
    ShotFrame(background: null, padding: .1),
  ),
  (
    'cutout',
    'Cut out',
    'Cắt nền',
    ShotFrame(background: ShotFrame.transparent, padding: .04),
  ),
  (
    'square-ink',
    'Square, sharp',
    'Vuông, góc nhọn',
    ShotFrame(
      background: 0xFF2F6FB0,
      aspect: '1:1',
      radius: 0,
      shadow: false,
      padding: .06,
    ),
  ),
];

/// [title] set in the app's own face as a PNG [width] px wide, light or
/// dark to suit [ground]; the engine places it above the shot.
Future<Uint8List?> frameTitlePng(String title, int width, int? ground) async {
  if (title.trim().isEmpty || width < 40) return null;
  final light =
      ground != null &&
      ground != ShotFrame.transparent &&
      Color(ground).computeLuminance() < .45;
  final painter = TextPainter(
    text: TextSpan(
      text: title.trim(),
      style: TextStyle(
        fontFamily: handyFontFamily('Bricolage'),
        fontSize: width * .07,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: light ? const Color(0xFFFFFFFF) : const Color(0xFF111111),
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 3,
    ellipsis: '…',
  )..layout(maxWidth: width.toDouble());
  final h = painter.height.ceil();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset((width - painter.width) / 2, 0));
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// A screenshot made ready to share: a ground, space, rounded corners, a
/// shadow and an optional phone or browser frame. The preview is the whole
/// first block; the export is the full-size PNG. Nothing leaves the device.
class FramePage extends StatefulWidget {
  final HandyFiles files;

  /// A picture to start with (from the screenshots entry, or a joined one).
  final Uint8List? initial;
  const FramePage({super.key, required this.files, this.initial});
  @override
  State<FramePage> createState() => _FramePageState();
}

class _FramePageState extends State<FramePage> {
  Uint8List? source, small, preview;
  ShotFrame frame = const ShotFrame();
  int sourceWidth = 0, smallWidth = 0;
  String preset = 'clean';
  final title = TextEditingController();
  String? error;
  bool working = false, saving = false;
  Timer? _debounce;
  int _job = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    title.dispose();
    super.dispose();
  }

  Future<int> _width(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final f = await codec.getNextFrame();
    final w = f.image.width;
    f.image.dispose();
    codec.dispose();
    return w;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial case final bytes?) use(bytes);
  }

  Future<void> pick() async {
    try {
      final file = await widget.files.importBytes(
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
        maxBytes: 20000000,
      );
      if (file == null || !mounted) return;
      await use(file.bytes);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorText(context, e);
          working = false;
        });
      }
    }
  }

  Future<void> use(Uint8List bytes) async {
    try {
      setState(() {
        source = bytes;
        small = null;
        preview = null;
        error = null;
        working = true;
      });
      final s = await compute(_preview, bytes);
      if (!mounted) return;
      small = s;
      sourceWidth = await _width(bytes);
      smallWidth = await _width(s);
      if (!mounted) return;
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
          final head = await frameTitlePng(
            title.text,
            smallWidth,
            frame.background,
          );
          final out = await compute(_frame, (s, frame, head));
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
      final head = await frameTitlePng(
        title.text,
        sourceWidth,
        frame.background,
      );
      final png = await compute(_frame, (s, frame, head));
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

  /// [frame] with some values changed; a flat ground ends a gradient.
  ShotFrame _with({
    Object? background = _same,
    double? padding,
    double? radius,
    bool? shadow,
    String? device,
  }) => frame.copyWith(
    background: identical(background, _same) ? null : background as int?,
    clearBackground: !identical(background, _same) && background == null,
    flat: !identical(background, _same),
    padding: padding,
    radius: radius,
    shadow: shadow,
    device: device,
  );

  Widget _previewView(BuildContext context, Uint8List? p) => Center(
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
  );

  List<Widget> _controls(
    BuildContext context,
    ThemeData theme,
    HandyColors c,
    Widget Function(
      String,
      String,
      double,
      double,
      ValueChanged<double>,
      String,
    )
    slider,
  ) => [
    if (error != null) ...[
      const SizedBox(height: HandySpace.s),
      Text(error!, style: TextStyle(color: c.negative)),
    ],
    HandyLabel(tr(context, 'Quick looks', 'Kiểu nhanh')),
    SizedBox(
      height: 44,
      child: ListView(
        key: const Key('frame-presets'),
        scrollDirection: Axis.horizontal,
        children: [
          for (final (id, en, vi, look) in framePresets)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: HandySpace.s),
              child: ChoiceChip(
                key: Key('frame-preset-$id'),
                label: Text(tr(context, en, vi)),
                selected: preset == id,
                onSelected: (_) {
                  preset = id;
                  change(look);
                },
              ),
            ),
        ],
      ),
    ),
    const SizedBox(height: HandySpace.l),
    HandyField(
      label: tr(context, 'Title (optional)', 'Tiêu đề (không bắt buộc)'),
      child: TextField(
        key: const Key('frame-title'),
        controller: title,
        maxLength: 80,
        decoration: InputDecoration(
          counterText: '',
          hintText: tr(
            context,
            'e.g. How to turn on dark mode',
            'ví dụ: Cách bật chế độ tối',
          ),
        ),
        onChanged: (_) => refresh(),
      ),
    ),
    HandyLabel(tr(context, 'Shape', 'Khổ ảnh')),
    Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: [
        for (final (id, en, vi) in const [
          ('auto', 'Fit the shot', 'Vừa ảnh'),
          ('1:1', 'Square 1:1', 'Vuông 1:1'),
          ('4:5', 'Portrait 4:5', 'Dọc 4:5'),
          ('9:16', 'Story 9:16', 'Story 9:16'),
          ('16:9', 'Slide 16:9', 'Slide 16:9'),
        ])
          ChoiceChip(
            key: Key('frame-aspect-$id'),
            label: Text(tr(context, en, vi)),
            selected: frame.aspect == id,
            onSelected: (_) => change(frame.copyWith(aspect: id)),
          ),
      ],
    ),
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
              selected: frame.background == argb && frame.background2 == null,
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
                      color:
                          frame.background == argb && frame.background2 == null
                          ? c.accent
                          : c.border,
                      width:
                          frame.background == argb && frame.background2 == null
                          ? 3
                          : 1,
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
        for (final (i, (a, b, en, vi)) in frameGradients.indexed)
          Tooltip(
            message: tr(context, en, vi),
            child: Semantics(
              button: true,
              selected: frame.background == a && frame.background2 == b,
              label: tr(context, en, vi),
              child: InkWell(
                key: Key('frame-gradient-$i'),
                customBorder: const CircleBorder(),
                onTap: () =>
                    change(frame.copyWith(background: a, background2: b)),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(a), Color(b)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: frame.background == a && frame.background2 == b
                          ? c.accent
                          : c.border,
                      width: frame.background == a && frame.background2 == b
                          ? 3
                          : 1,
                    ),
                  ),
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
        tr(context, 'Updating the preview…', 'Đang cập nhật bản xem trước…'),
        style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
      ),
  ];

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
      body: source == null
          ? null
          : LayoutBuilder(
              builder: (context, box) {
                final previewBox = Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    HandySpace.s,
                    HandySpace.l,
                    HandySpace.s,
                  ),
                  child: _previewView(context, p),
                );
                final list = ListView(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    0,
                    HandySpace.l,
                    HandySpace.xxl,
                  ),
                  children: [
                    // Wide screens show no app bar title; the column has it.
                    if (box.maxWidth >= 840)
                      Padding(
                        padding: const EdgeInsets.only(top: HandySpace.l),
                        child: Semantics(
                          header: true,
                          child: Text(
                            tr(
                              context,
                              'Frame a screenshot',
                              'Khung ảnh chụp màn hình',
                            ),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ..._controls(context, theme, c, slider),
                  ],
                );
                // The preview stays in sight while the controls scroll.
                return box.maxWidth >= 840
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: previewBox),
                          SizedBox(width: 420, child: list),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: box.maxHeight * .42,
                            child: previewBox,
                          ),
                          const Divider(height: 1),
                          Expanded(child: list),
                        ],
                      );
              },
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
          ),
      ],
    );
  }
}

const _same = Object();
