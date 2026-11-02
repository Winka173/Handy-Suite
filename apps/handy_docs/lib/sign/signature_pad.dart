import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:handy_ui/kit.dart';

/// Blue-black ink, as from a pen.
const signatureInk = Color(0xFF1B2A4A);

/// A signature ready to place: its PNG and its straight RGBA pixels.
typedef SignaturePicture = ({
  Uint8List png,
  Uint8List rgba,
  int width,
  int height,
});

/// Decodes a PNG to place it, scaled to at most [maxEdge] pixels.
Future<SignaturePicture> signaturePicture(
  Uint8List png, {
  int maxEdge = 1200,
}) async {
  final probe = await ui.instantiateImageCodec(png);
  final first = await probe.getNextFrame();
  final w = first.image.width, h = first.image.height;
  first.image.dispose();
  probe.dispose();
  final scale = math.min(1.0, maxEdge / math.max(w, h));
  final codec = await ui.instantiateImageCodec(
    png,
    targetWidth: scale < 1 ? (w * scale).round() : null,
    targetHeight: scale < 1 ? (h * scale).round() : null,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    final rgba = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    final out = scale < 1
        ? await image.toByteData(format: ui.ImageByteFormat.png)
        : null;
    return (
      png: out == null ? png : out.buffer.asUint8List(),
      rgba: rgba!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

/// Draws a signature with a finger, a mouse or a pen. Returns the PNG
/// (clear background, trimmed to the ink) or null when closed.
Future<Uint8List?> drawSignature(BuildContext context) =>
    Navigator.of(context).push(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => const _PadPage(),
      ),
    );

class _PadPage extends StatefulWidget {
  const _PadPage();
  @override
  State<_PadPage> createState() => _PadPageState();
}

class _PadPageState extends State<_PadPage> {
  final strokes = <List<Offset>>[];
  bool saving = false;

  Future<void> done(Size size) async {
    if (strokes.isEmpty || saving) return;
    setState(() => saving = true);
    final png = await renderStrokes(strokes);
    if (mounted) Navigator.pop(context, png);
  }

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Sign here', 'Ký vào đây')),
        actions: [
          TextButton(
            key: const Key('pad-clear'),
            onPressed: strokes.isEmpty
                ? null
                : () => setState(() => strokes.clear()),
            child: Text(tr(context, 'Clear', 'Xóa nét')),
          ),
          const SizedBox(width: HandySpace.s),
        ],
      ),
      bottomNavigationBar: HandyBottomBar(
        child: FilledButton(
          key: const Key('pad-done'),
          onPressed: strokes.isEmpty || saving
              ? null
              : () => done(MediaQuery.sizeOf(context)),
          child: Text(tr(context, 'Use this signature', 'Dùng chữ ký này')),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: Center(
          child: AspectRatio(
            aspectRatio: 2.4,
            child: Semantics(
              label: tr(
                context,
                'Signature area. Draw with a finger, mouse or pen.',
                'Vùng ký. Vẽ bằng ngón tay, chuột hoặc bút.',
              ),
              child: Container(
                key: const Key('pad-area'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    // The line people sign on.
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 40,
                      child: Container(
                        height: 1,
                        color: const Color(0xFFBFC5CE),
                      ),
                    ),
                    if (strokes.isEmpty)
                      Center(
                        child: Text(
                          tr(
                            context,
                            'Sign above the line',
                            'Ký phía trên đường kẻ',
                          ),
                          style: const TextStyle(color: Color(0xFF8A919C)),
                        ),
                      ),
                    Positioned.fill(
                      child: GestureDetector(
                        onPanStart: (d) =>
                            setState(() => strokes.add([d.localPosition])),
                        onPanUpdate: (d) =>
                            setState(() => strokes.last.add(d.localPosition)),
                        child: CustomPaint(painter: _Ink(strokes)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Paint get _pen => Paint()
  ..color = signatureInk
  ..strokeWidth = 2.6
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..style = PaintingStyle.stroke;

void _draw(Canvas canvas, List<List<Offset>> strokes) {
  for (final s in strokes) {
    if (s.length == 1) {
      canvas.drawCircle(s.first, 1.3, _pen..style = PaintingStyle.fill);
      continue;
    }
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    for (var i = 1; i < s.length - 1; i++) {
      // Through the midpoints: smooth without lagging the pen.
      final m = (s[i] + s[i + 1]) / 2;
      path.quadraticBezierTo(s[i].dx, s[i].dy, m.dx, m.dy);
    }
    path.lineTo(s.last.dx, s.last.dy);
    canvas.drawPath(path, _pen);
  }
}

class _Ink extends CustomPainter {
  final List<List<Offset>> strokes;
  _Ink(this.strokes);
  @override
  void paint(Canvas canvas, Size size) => _draw(canvas, strokes);
  @override
  bool shouldRepaint(_Ink old) => true;
}

/// The strokes as a PNG three times as sharp, trimmed to the ink with a
/// little margin, on a clear background.
Future<Uint8List> renderStrokes(List<List<Offset>> strokes) async {
  var bounds = Rect.zero;
  for (final s in strokes) {
    for (final p in s) {
      final r = Rect.fromCenter(center: p, width: 1, height: 1);
      bounds = bounds == Rect.zero ? r : bounds.expandToInclude(r);
    }
  }
  bounds = bounds.inflate(6);
  const scale = 3.0;
  final w = math.max(1, (bounds.width * scale).ceil()),
      h = math.max(1, (bounds.height * scale).ceil());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(scale)
    ..translate(-bounds.left, -bounds.top);
  _draw(canvas, strokes);
  final image = await recorder.endRecording().toImage(
    math.min(w, 2400),
    math.min(h, 1200),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
