import 'dart:math' as math;
import 'package:handy_ui/kit.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import '../../scope.dart';

Future<void> showTripReplay(
  BuildContext context,
  TripScope scope,
  String key,
) async {
  final points = replayPoints(scope.state, key);
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => _Replay(points)));
}

class _Replay extends StatefulWidget {
  final List<Json> points;
  const _Replay(this.points);
  @override
  State<_Replay> createState() => _ReplayState();
}

class _ReplayState extends State<_Replay> with SingleTickerProviderStateMixin {
  late final points = widget.points;
  late final AnimationController motion =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: math.max(1, points.length) * 700),
      )..addListener(
        () => setState(() {
          position = motion.value;
        }),
      );
  double position = 1;
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context),
        count = points.isEmpty
            ? 0
            : math.max(1, (points.length * position).ceil());
    if (reduced && motion.isAnimating) motion.stop();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Pin replay', 'Xem lại các điểm')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              context,
              'Illustrative sequence of saved pins. Straight lines are not driven routes, GPS tracks or travel-time estimates. Visits without coordinates are omitted.',
              'Chuỗi điểm đã lưu để minh họa. Đường thẳng không phải tuyến đã đi, vệt GPS hay thời gian di chuyển. Bỏ qua lượt ghé không có tọa độ.',
            ),
          ),
          if (points.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tr(
                  context,
                  'No confirmed visits with coordinates in this trip.',
                  'Chuyến này chưa có lượt ghé xác nhận kèm tọa độ.',
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 280,
              child: Semantics(
                label: tr(
                  context,
                  'Illustrative pin sequence, $count of ${points.length} visible',
                  'Chuỗi điểm minh họa, hiện $count trên ${points.length}',
                ),
                child: CustomPaint(
                  painter: _Pins(
                    points.take(count).toList(),
                    points,
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            Slider(
              value: position,
              onChanged: (v) {
                motion.stop();
                setState(() => position = v);
              },
              semanticFormatterCallback: (v) =>
                  '${math.max(1, (points.length * v).ceil())} / ${points.length}',
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: motion.isAnimating
                      ? () => setState(() => motion.stop())
                      : reduced
                      ? null
                      : () => motion.forward(from: 0),
                  icon: Icon(
                    motion.isAnimating ? Icons.pause : Icons.play_arrow,
                  ),
                  label: Text(tr(context, 'Play / pause', 'Phát / tạm dừng')),
                ),
                TextButton(
                  onPressed: () {
                    motion.stop();
                    setState(() => position = 1);
                  },
                  child: Text(tr(context, 'Show all pins', 'Hiện tất cả điểm')),
                ),
              ],
            ),
            Text(
              '$count / ${points.length} ${tr(context, 'saved pins', 'điểm đã lưu')}',
            ),
            for (var i = 0; i < count; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}'),
                title: Text(points[i]['place']),
                subtitle: Text(points[i]['day']),
              ),
          ],
        ],
      ),
    );
  }
}

class _Pins extends CustomPainter {
  final List<Json> shown, all;
  final Color hue, ink;
  _Pins(this.shown, this.all, this.hue, this.ink);
  @override
  void paint(Canvas canvas, Size size) {
    final minLat = all
            .map((p) => (p['lat'] as num).toDouble())
            .reduce(math.min),
        maxLat = all.map((p) => (p['lat'] as num).toDouble()).reduce(math.max),
        minLon = all.map((p) => (p['lon'] as num).toDouble()).reduce(math.min),
        maxLon = all.map((p) => (p['lon'] as num).toDouble()).reduce(math.max);
    Offset point(Json p) => Offset(
      (maxLon - minLon).abs() < 0.001
          ? size.width / 2
          : 24 +
                ((p['lon'] as num) - minLon) /
                    math.max(0.001, maxLon - minLon) *
                    (size.width - 48),
      (maxLat - minLat).abs() < 0.001
          ? size.height / 2
          : size.height -
                24 -
                ((p['lat'] as num) - minLat) /
                    math.max(0.001, maxLat - minLat) *
                    (size.height - 48),
    );
    final path = Path();
    for (var i = 0; i < shown.length; i++) {
      final p = point(shown[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = hue.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final groups = <Offset, List<int>>{};
    for (var i = 0; i < shown.length; i++) {
      (groups[point(shown[i])] ??= []).add(i + 1);
    }
    for (final entry in groups.entries) {
      final p = entry.key, numbers = entry.value;
      canvas.drawCircle(p, 5, Paint()..color = hue);
      if (all.length > 20) continue;
      final text = TextPainter(
        text: TextSpan(
          text: numbers.length <= 3
              ? numbers.join(', ')
              : '${numbers.first} +${numbers.length - 1}',
          style: TextStyle(color: ink, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (p.dx + 6).clamp(0.0, math.max(0.0, size.width - text.width)),
          math.max(0.0, p.dy - 18),
        ),
      );
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _Pins old) => true;
}
