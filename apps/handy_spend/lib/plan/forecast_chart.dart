import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';
import '../ui/figures.dart';

/// The balance day by day to the plan's end. It is a forecast, so the
/// line is dashed; the lowest day is marked and named, and a day below
/// zero is drawn under the zero line in the negative colour.
class ForecastChart extends StatelessWidget {
  final SpendScope scope;
  final Projection projection;
  const ForecastChart({
    super.key,
    required this.scope,
    required this.projection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final p = projection;
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final low = p.points.isEmpty
        ? null
        : p.points.reduce((a, b) => b.balance < a.balance ? b : a);
    final label = low == null
        ? null
        : tr(
            context,
            'Lowest ${scope.hidden ? '' : compactAmount(low.balance, scope.currency, vi: false)} · ${dayLabel(context, scope, low.date)}',
            'Thấp nhất ${scope.hidden ? '' : compactAmount(low.balance, scope.currency, vi: true)} · ${dayLabel(context, scope, low.date)}',
          );
    return Semantics(
      label: tr(
        context,
        'Forecast balance. Exact days are in the daily table.',
        'Số dư dự báo. Số từng ngày nằm trong bảng từng ngày.',
      ),
      excludeSemantics: true,
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: CustomPaint(
          key: const Key('forecast-chart'),
          painter: _LinePainter(
            values: [for (final x in p.points) x.balance],
            dates: [for (final x in p.points) dayLabel(context, scope, x.date)],
            tick: (v) =>
                scope.hidden ? '' : compactAmount(v, scope.currency, vi: vi),
            low: low == null ? -1 : p.points.indexOf(low),
            lowLabel: label ?? '',
            line: c.accent,
            grid: c.border,
            ink: theme.colorScheme.onSurface,
            muted: c.muted,
            negative: c.negative,
            text: theme.textTheme.labelSmall!,
          ),
        ),
      ),
    );
  }
}

/// [x] kept between [lo] and [hi]; a label wider than the room starts at [lo].
double _fit(double x, double lo, double hi) => hi < lo ? lo : x.clamp(lo, hi);

class _LinePainter extends CustomPainter {
  final List<BigInt> values;
  final List<String> dates;
  final String Function(BigInt) tick;
  final int low;
  final String lowLabel;
  final Color line, grid, ink, muted, negative;
  final TextStyle text;
  _LinePainter({
    required this.values,
    required this.dates,
    required this.tick,
    required this.low,
    required this.lowLabel,
    required this.line,
    required this.grid,
    required this.ink,
    required this.muted,
    required this.negative,
    required this.text,
  });

  TextPainter _text(String s, Color color) => TextPainter(
    text: TextSpan(
      text: s,
      style: text.copyWith(color: color),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    // Round, even steps with zero always on the scale.
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (lo > BigInt.zero) lo = BigInt.zero;
    if (hi < BigInt.zero) hi = BigInt.zero;
    final span = (hi - lo) == BigInt.zero ? BigInt.one : hi - lo;
    var step = BigInt.one;
    while (step * BigInt.from(4) < span) {
      final s = step.toString();
      step = s.startsWith('1')
          ? step * BigInt.two
          : s.startsWith('2')
          ? step * BigInt.from(5) ~/ BigInt.two
          : step * BigInt.two;
    }
    final bottom = lo < BigInt.zero
        ? -(((-lo) + step - BigInt.one) ~/ step) * step
        : BigInt.zero;
    final top = ((hi + step) ~/ step) * step;
    const left = 52.0, labelBand = 18.0, axisBand = 20.0;
    final plot = Rect.fromLTRB(
      left,
      labelBand,
      size.width - 4,
      size.height - axisBand,
    );
    double y(BigInt v) =>
        plot.bottom -
        plot.height * ((v - bottom).toDouble() / (top - bottom).toDouble());
    double x(int i) => values.length == 1
        ? plot.left
        : plot.left + plot.width * i / (values.length - 1);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = bottom; v <= top; v += step) {
      final yy = y(v);
      canvas.drawLine(
        Offset(plot.left, yy),
        Offset(plot.right, yy),
        v == BigInt.zero
            ? (Paint()
                ..color = ink.withValues(alpha: .45)
                ..strokeWidth = 1)
            : gridPaint,
      );
      final t = _text(tick(v), muted);
      t.paint(canvas, Offset(left - 8 - t.width, yy - t.height / 2));
    }

    // Dashed line: every value is a forecast.
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      i == 0
          ? path.moveTo(x(i), y(values[i]))
          : path.lineTo(x(i), y(values[i]));
    }
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 6), stroke);
      }
    }
    // Days under zero.
    for (var i = 0; i < values.length; i++) {
      if (values[i] < BigInt.zero)
        canvas.drawCircle(
          Offset(x(i), y(values[i])),
          2.5,
          Paint()..color = negative,
        );
    }

    if (low >= 0 && lowLabel.isNotEmpty) {
      final p = Offset(x(low), y(values[low]));
      canvas.drawCircle(
        p,
        4,
        Paint()..color = values[low] < BigInt.zero ? negative : ink,
      );
      canvas.drawLine(
        Offset(p.dx, plot.top),
        Offset(p.dx, p.dy - 6),
        Paint()
          ..color = ink.withValues(alpha: .35)
          ..strokeWidth = 1,
      );
      final t = _text(lowLabel, ink);
      final dx = _fit(p.dx - t.width / 2, plot.left, size.width - t.width);
      t.paint(canvas, Offset(dx, 0));
    }

    // First, middle and last day on the axis, pulled inside the plot.
    for (final i in {0, values.length ~/ 2, values.length - 1}) {
      final t = _text(dates[i], muted);
      final dx = _fit(x(i) - t.width / 2, plot.left, size.width - t.width);
      t.paint(canvas, Offset(dx, plot.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values.length != values.length ||
      old.low != low ||
      old.lowLabel != lowLabel ||
      old.line != line ||
      [
        for (var i = 0; i < values.length; i++) values[i] != old.values[i],
      ].any((v) => v);
}

/// Every day of the forecast with its money in and out, exactly.
Future<void> showDailyTable(
  BuildContext context,
  SpendScope scope,
  Projection p,
) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (context) => HandyPage(
      title: tr(context, 'Day by day', 'Từng ngày'),
      body: ListView.builder(
        itemCount: p.points.length,
        itemBuilder: (context, i) {
          final d = p.points[i];
          return HandyContent(
            child: ListTile(
              title: Text(dayLabel(context, scope, d.date)),
              subtitle: Text(
                tr(
                  context,
                  'In ${moneyText(context, scope, d.inflow, scope.currency)} · out ${moneyText(context, scope, d.outflow, scope.currency)}',
                  'Vào ${moneyText(context, scope, d.inflow, scope.currency)} · ra ${moneyText(context, scope, d.outflow, scope.currency)}',
                ),
              ),
              trailing: Money(scope, d.balance, scope.currency),
            ),
          );
        },
      ),
    ),
  ),
);
