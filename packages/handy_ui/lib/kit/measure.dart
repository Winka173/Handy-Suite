import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Known lengths a photo can be measured against, in millimetres.
const handyMeasureReferences = [
  ('card-long', 'Bank card, long edge', 'Thẻ ngân hàng, cạnh dài', 85.60),
  ('card-short', 'Bank card, short edge', 'Thẻ ngân hàng, cạnh ngắn', 53.98),
  ('a4-long', 'A4 sheet, long edge', 'Giấy A4, cạnh dài', 297.0),
  ('a4-short', 'A4 sheet, short edge', 'Giấy A4, cạnh ngắn', 210.0),
];

/// The length from [a] to [b], in millimetres, given that [refA]-[refB] in the
/// same picture is [refMm] long. Holds only for things lying flat in the
/// reference's plane, photographed square on. Null while the reference has no
/// length.
double? handyMeasureMm(
  Offset refA,
  Offset refB,
  double refMm,
  Offset a,
  Offset b,
) {
  final ref = (refB - refA).distance;
  if (ref <= 0 || refMm <= 0) return null;
  return (b - a).distance / ref * refMm;
}

/// "≈ 42 mm", "≈ 18.5 cm": rounded to a millimetre, in cm from 10 cm.
String handyMeasureLabel(double mm) => mm < 100
    ? '≈ ${mm.round()} mm'
    : '≈ ${(mm.round() / 10).toStringAsFixed(mm.round() % 10 == 0 ? 0 : 1)} cm';

/// Measuring on a photo: two handles on a known edge, then two taps per
/// length. Points live in the picture's own pixels, so the answer does not
/// change with the screen. Handles drag; arrow keys nudge the chosen one.
class HandyMeasureBoard extends StatefulWidget {
  final Uint8List image;
  final double referenceMm;

  /// Every measured length, in millimetres, after each change.
  final ValueChanged<List<double>> onChanged;
  const HandyMeasureBoard({
    super.key,
    required this.image,
    required this.referenceMm,
    required this.onChanged,
  });
  @override
  State<HandyMeasureBoard> createState() => HandyMeasureBoardState();
}

class HandyMeasureBoardState extends State<HandyMeasureBoard> {
  ui.Image? picture;
  Object? error;

  /// Reference first (two points), then pairs. A lone last point waits for
  /// its partner.
  final points = <Offset>[];
  int? selected;
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(HandyMeasureBoard old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      points.clear();
      selected = null;
      _decode();
    } else if (old.referenceMm != widget.referenceMm) {
      _report();
    }
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.image);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => picture = frame.image);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    focus.dispose();
    picture?.dispose();
    super.dispose();
  }

  List<double> get lengths => [
    for (var i = 2; i + 1 < points.length; i += 2)
      handyMeasureMm(
            points[0],
            points[1],
            widget.referenceMm,
            points[i],
            points[i + 1],
          ) ??
          0,
  ];

  bool get referenceSet => points.length >= 2;

  void _report() => widget.onChanged(lengths);

  /// Drops the last measurement (or the reference, when nothing else is
  /// left).
  void undo() {
    if (points.isEmpty) return;
    setState(() {
      // A lone point, else the last pair, else the reference itself.
      final drop = points.length.isOdd ? 1 : 2;
      points.removeRange(points.length - drop, points.length);
      selected = null;
    });
    _report();
  }

  void clear() {
    setState(() {
      points.clear();
      selected = null;
    });
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final img = picture;
    if (error != null) {
      return Text(
        tr(context, 'This picture cannot be read.', 'Không đọc được ảnh này.'),
        style: TextStyle(color: HandyColors.of(context).negative),
      );
    }
    if (img == null) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = math.min(
          MediaQuery.sizeOf(context).height * 0.62,
          box.maxWidth * 1.4,
        );
        final scale = math.min(box.maxWidth / img.width, maxH / img.height);
        final size = Size(img.width * scale, img.height * scale);
        Offset toPicture(Offset p) => p / scale;
        int? near(Offset p) {
          for (var i = points.length - 1; i >= 0; i--) {
            if ((points[i] * scale - p).distance <= 24) return i;
          }
          return null;
        }

        void nudge(Offset by) {
          final i = selected;
          if (i == null) return;
          setState(() => points[i] = points[i] + by / scale);
          _report();
        }

        final step = HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0;
        return Focus(
          focusNode: focus,
          onKeyEvent: (_, e) {
            if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final by = switch (e.logicalKey) {
              LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
              LogicalKeyboardKey.arrowRight => Offset(step, 0),
              LogicalKeyboardKey.arrowUp => Offset(0, -step),
              LogicalKeyboardKey.arrowDown => Offset(0, step),
              _ => null,
            };
            if (by == null || selected == null) return KeyEventResult.ignored;
            nudge(by);
            return KeyEventResult.handled;
          },
          child: Semantics(
            label: tr(
              context,
              'Photo to measure. Tap two ends of the known edge, then two ends of each length.',
              'Ảnh để đo. Chạm hai đầu cạnh đã biết, rồi hai đầu mỗi đoạn cần đo.',
            ),
            child: Center(
              child: GestureDetector(
                key: const Key('measure-board'),
                onTapUp: (d) {
                  focus.requestFocus();
                  final hit = near(d.localPosition);
                  setState(() {
                    if (hit != null) {
                      selected = hit;
                    } else {
                      points.add(toPicture(d.localPosition));
                      selected = points.length - 1;
                    }
                  });
                  _report();
                },
                onPanStart: (d) =>
                    setState(() => selected = near(d.localPosition)),
                onPanUpdate: (d) {
                  final i = selected;
                  if (i == null) return;
                  setState(
                    () => points[i] = toPicture(
                      Offset(
                        (points[i].dx * scale + d.delta.dx).clamp(
                          0,
                          size.width,
                        ),
                        (points[i].dy * scale + d.delta.dy).clamp(
                          0,
                          size.height,
                        ),
                      ),
                    ),
                  );
                  _report();
                },
                child: CustomPaint(
                  size: size,
                  painter: _MeasurePainter(
                    picture: img,
                    scale: scale,
                    points: points,
                    selected: selected,
                    lengths: lengths,
                    referenceMm: widget.referenceMm,
                    hue: HandyColors.of(context).accent,
                    ink: Colors.white,
                    label: Theme.of(context).textTheme.labelLarge!,
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

class _MeasurePainter extends CustomPainter {
  final ui.Image picture;
  final double scale, referenceMm;
  final List<Offset> points;
  final List<double> lengths;
  final int? selected;
  final Color hue, ink;
  final TextStyle label;
  _MeasurePainter({
    required this.picture,
    required this.scale,
    required this.points,
    required this.selected,
    required this.lengths,
    required this.referenceMm,
    required this.hue,
    required this.ink,
    required this.label,
  });

  void _tag(Canvas canvas, Offset at, String text, Color fill, Color on) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: label.copyWith(color: on),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(
      center: at,
      width: tp.width + 12,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(4)),
      Paint()..color = fill,
    );
    tp.paint(canvas, r.topLeft + const Offset(6, 3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      picture,
      Rect.fromLTWH(0, 0, picture.width.toDouble(), picture.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final shown = [for (final p in points) p * scale];
    void segment(int i, Color color, String text) {
      final line = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final halo = Paint()
        ..color = Colors.black54
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      if (i + 1 < shown.length) {
        canvas.drawLine(shown[i], shown[i + 1], halo);
        canvas.drawLine(shown[i], shown[i + 1], line);
        if (text.isNotEmpty) {
          _tag(
            canvas,
            (shown[i] + shown[i + 1]) / 2 + const Offset(0, -18),
            text,
            color,
            color == hue ? Colors.white : Colors.black,
          );
        }
      }
    }

    segment(
      0,
      hue,
      referenceMm > 0 ? '${referenceMm.toStringAsFixed(2)} mm' : '',
    );
    for (var i = 2, n = 0; i < shown.length; i += 2, n++) {
      segment(i, ink, n < lengths.length ? handyMeasureLabel(lengths[n]) : '');
    }
    for (var i = 0; i < shown.length; i++) {
      final color = i < 2 ? hue : ink;
      canvas.drawCircle(
        shown[i],
        i == selected ? 11 : 8,
        Paint()..color = Colors.black54,
      );
      canvas.drawCircle(
        shown[i],
        i == selected ? 9 : 6,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_MeasurePainter old) => true;
}

/// The whole measuring tool: choose a photo, choose what the reference edge
/// is, mark it and the lengths, read the answers. [actions] adds the host
/// app's own buttons for the lengths (Keep's "Add to notes").
class HandyMeasurePanel extends StatefulWidget {
  final Uint8List? initial;
  final Future<Uint8List?> Function() pickImage;
  final Future<Uint8List?> Function()? capture;
  final List<Widget> Function(BuildContext, List<double>)? actions;
  const HandyMeasurePanel({
    super.key,
    this.initial,
    required this.pickImage,
    this.capture,
    this.actions,
  });
  @override
  State<HandyMeasurePanel> createState() => _HandyMeasurePanelState();
}

class _HandyMeasurePanelState extends State<HandyMeasurePanel> {
  final board = GlobalKey<HandyMeasureBoardState>();
  final custom = TextEditingController();
  Uint8List? image;
  String reference = handyMeasureReferences.first.$1;
  List<double> lengths = const [];
  String error = '';

  @override
  void initState() {
    super.initState();
    image = widget.initial;
  }

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  double get referenceMm => reference == 'custom'
      ? double.tryParse(custom.text.replaceAll(',', '.')) ?? 0
      : handyMeasureReferences.firstWhere((r) => r.$1 == reference).$4;

  Future<void> choose(Future<Uint8List?> Function() source) async {
    try {
      final bytes = await source();
      if (bytes == null || !mounted) return;
      setState(() {
        image = bytes;
        lengths = const [];
        error = '';
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = tr(
            context,
            'Could not open that picture.',
            'Không mở được ảnh đó.',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final b = board.currentState;
    final set = b?.referenceSet ?? false;
    final sources = Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: [
        if (widget.capture != null)
          FilledButton.icon(
            key: const Key('measure-camera'),
            onPressed: () => choose(widget.capture!),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(tr(context, 'Take a photo', 'Chụp ảnh')),
          ),
        (widget.capture == null && image == null
            ? FilledButton.icon
            : OutlinedButton.icon)(
          key: const Key('measure-pick'),
          onPressed: () => choose(widget.pickImage),
          icon: const Icon(Icons.image_outlined, size: 18),
          label: Text(
            image == null
                ? tr(context, 'Choose a photo', 'Chọn ảnh')
                : tr(context, 'Another photo', 'Ảnh khác'),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image == null) ...[
          Text(
            tr(
              context,
              'Put a bank card (or an A4 sheet) flat beside the thing, photograph both square on, then mark the card\'s edge and the lengths you want.',
              'Đặt thẻ ngân hàng (hoặc tờ A4) nằm phẳng cạnh vật, chụp thẳng từ trên xuống, rồi đánh dấu cạnh thẻ và các đoạn cần đo.',
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: HandySpace.l),
          sources,
        ] else ...[
          HandyLabel(tr(context, 'Known edge', 'Cạnh đã biết')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final r in handyMeasureReferences)
                ChoiceChip(
                  key: Key('measure-ref-${r.$1}'),
                  label: Text(tr(context, r.$2, r.$3)),
                  selected: reference == r.$1,
                  onSelected: (_) => setState(() => reference = r.$1),
                ),
              ChoiceChip(
                key: const Key('measure-ref-custom'),
                label: Text(tr(context, 'Other, in mm', 'Khác, theo mm')),
                selected: reference == 'custom',
                onSelected: (_) => setState(() => reference = 'custom'),
              ),
            ],
          ),
          if (reference == 'custom')
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: TextField(
                key: const Key('measure-custom'),
                controller: custom,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: tr(context, 'Length in mm', 'Độ dài (mm)'),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          const SizedBox(height: HandySpace.m),
          Text(
            !set
                ? tr(
                    context,
                    'Tap the two ends of the known edge.',
                    'Chạm vào hai đầu của cạnh đã biết.',
                  )
                : tr(
                    context,
                    'Tap two ends of each length. Drag a dot to adjust.',
                    'Chạm hai đầu mỗi đoạn cần đo. Kéo chấm để chỉnh.',
                  ),
            key: const Key('measure-hint'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: HandySpace.s),
          HandyMeasureBoard(
            key: board,
            image: image!,
            referenceMm: referenceMm,
            onChanged: (v) => setState(() => lengths = v),
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'An estimate: right only when the thing and the reference lie flat in one plane, photographed square on.',
              'Kết quả ước lượng: chỉ đúng khi vật và cạnh tham chiếu nằm phẳng cùng một mặt, chụp thẳng góc.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
          HandyLabel(
            tr(context, 'Lengths', 'Các đoạn đo'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('measure-undo'),
                  tooltip: tr(context, 'Undo the last one', 'Bỏ đoạn cuối'),
                  onPressed: set ? () => b?.undo() : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  key: const Key('measure-clear'),
                  tooltip: tr(context, 'Start over', 'Làm lại từ đầu'),
                  onPressed: set ? () => b?.clear() : null,
                  icon: const Icon(Icons.restart_alt),
                ),
              ],
            ),
          ),
          if (lengths.isEmpty)
            Text(
              tr(context, 'Nothing measured yet.', 'Chưa đo đoạn nào.'),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            )
          else
            for (final (i, mm) in lengths.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Length ${i + 1}', 'Đoạn ${i + 1}'),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      handyMeasureLabel(mm),
                      key: Key('measure-length-$i'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          if (widget.actions != null && lengths.isNotEmpty) ...[
            const SizedBox(height: HandySpace.m),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: widget.actions!(context, lengths),
            ),
          ],
          const SizedBox(height: HandySpace.l),
          sources,
        ],
        if (error.isNotEmpty) ...[
          const SizedBox(height: HandySpace.s),
          Text(error, style: TextStyle(color: c.negative)),
        ],
      ],
    );
  }
}
