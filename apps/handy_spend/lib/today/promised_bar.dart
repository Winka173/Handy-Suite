import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'promised_logic.dart';

const _kinds = {'expense', 'income', 'transfer', 'refund', 'adjustment'};

String partName(BuildContext context, PromisedPart p) =>
    _kinds.contains(p.name) ? kindLabel(context, p.name) : p.name;

/// The money held, as one bar cut into what is already promised (each
/// payment, the reserves, the buffer) and what is free, in the app's hue.
/// A shortfall runs past the money held in the negative colour.
class PromisedBar extends StatelessWidget {
  final SpendScope scope;
  final Promised promised;
  const PromisedBar({super.key, required this.scope, required this.promised});

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final safe = promised.safe;
    final parts = <_Part>[
      for (final (i, p) in promised.outs.indexed)
        _Part(
          p.amount,
          ink.withValues(alpha: i.isEven ? .30 : .20),
          partName(context, p),
        ),
      if (promised.others > BigInt.zero)
        _Part(promised.others, ink.withValues(alpha: .20), ''),
      if (safe.reserves > BigInt.zero)
        _Part(
          safe.reserves,
          ink.withValues(alpha: .12),
          tr(context, 'Saved', 'Để dành'),
        ),
      if (safe.owe > BigInt.zero)
        _Part(
          safe.owe,
          ink.withValues(alpha: .16),
          tr(context, 'You owe', 'Bạn nợ'),
        ),
      if (safe.buffer > BigInt.zero)
        _Part(
          safe.buffer,
          ink.withValues(alpha: .07),
          tr(context, 'Buffer', 'Dự phòng'),
          hatch: ink.withValues(alpha: .18),
        ),
      if (safe.available > BigInt.zero)
        _Part(
          safe.available,
          c.accent,
          tr(context, 'Free', 'Còn tiêu'),
          label: Colors.white,
        ),
    ];
    return Semantics(
      label: tr(
        context,
        'Money held, split into promised payments and what is free',
        'Tiền đang có, chia thành các khoản đã hứa và phần còn tiêu được',
      ),
      excludeSemantics: true,
      child: SizedBox(
        height: 36,
        width: double.infinity,
        child: CustomPaint(
          key: const Key('promised-bar'),
          painter: _BarPainter(
            parts: parts,
            held: promised.held,
            shortfall: safe.shortfall,
            negative: c.negative,
            seam: theme.colorScheme.surface,
            ground: c.raised,
            labelInk: ink,
            labels: !scope.hidden,
            textStyle: theme.textTheme.labelSmall!,
          ),
        ),
      ),
    );
  }
}

class _Part {
  final BigInt amount;
  final Color fill;
  final String name;
  final Color? hatch, label;
  const _Part(this.amount, this.fill, this.name, {this.hatch, this.label});
}

class _BarPainter extends CustomPainter {
  final List<_Part> parts;
  final BigInt held, shortfall;
  final Color negative, seam, ground, labelInk;
  final bool labels;
  final TextStyle textStyle;
  _BarPainter({
    required this.parts,
    required this.held,
    required this.shortfall,
    required this.negative,
    required this.seam,
    required this.ground,
    required this.labelInk,
    required this.labels,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = parts.fold(BigInt.zero, (n, p) => n + p.amount);
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(6),
    );
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = ground);
    if (total <= BigInt.zero) {
      canvas.restore();
      return;
    }
    double at(BigInt v) => size.width * (v.toDouble() / total.toDouble());
    var x = 0.0, sum = BigInt.zero;
    for (final p in parts) {
      sum += p.amount;
      final next = at(sum), rect = Rect.fromLTRB(x, 0, next, size.height);
      canvas.drawRect(rect, Paint()..color = p.fill);
      if (p.hatch != null) {
        final line = Paint()
          ..color = p.hatch!
          ..strokeWidth = 1;
        canvas.save();
        canvas.clipRect(rect);
        for (var h = rect.left - size.height; h < rect.right; h += 6) {
          canvas.drawLine(
            Offset(h, size.height),
            Offset(h + size.height, 0),
            line,
          );
        }
        canvas.restore();
      }
      if (labels && p.name.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: p.name,
            style: textStyle.copyWith(color: p.label ?? labelInk),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        if (tp.width + 12 <= rect.width)
          tp.paint(
            canvas,
            Offset(rect.left + 6, (size.height - tp.height) / 2),
          );
      }
      // A 2px seam between parts.
      if (sum < total)
        canvas.drawRect(
          Rect.fromLTWH(next - 1, 0, 2, size.height),
          Paint()..color = seam,
        );
      x = next;
    }
    if (shortfall > BigInt.zero) {
      // What is promised beyond the money held.
      final edge = at(held < BigInt.zero ? BigInt.zero : held);
      canvas.drawRect(
        Rect.fromLTRB(edge, 0, size.width, size.height),
        Paint()..color = negative.withValues(alpha: .55),
      );
      canvas.drawRect(
        Rect.fromLTWH(edge - 1, 0, 2, size.height),
        Paint()..color = labelInk,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.parts.length != parts.length ||
      old.held != held ||
      old.shortfall != shortfall ||
      old.labels != labels ||
      old.negative != negative ||
      [
        for (var i = 0; i < parts.length; i++)
          parts[i].amount != old.parts[i].amount ||
              parts[i].fill != old.parts[i].fill,
      ].any((v) => v);
}

/// The sum the bar draws, row by row, ending in the answer.
class PromisedSum extends StatelessWidget {
  final SpendScope scope;
  final Promised promised;
  const PromisedSum({super.key, required this.scope, required this.promised});

  @override
  Widget build(BuildContext context) {
    final safe = promised.safe;
    final cur = scope.currency;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget row(
      String label,
      BigInt v, {
      String? note,
      bool lead = false,
      bool sign = true,
      Key? key,
    }) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: [
                  if (note != null)
                    TextSpan(
                      text: '  $note',
                      style: TextStyle(color: c.muted),
                    ),
                ],
              ),
              style: lead
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
          Money(
            scope,
            v,
            cur,
            sign: sign,
            style: lead
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
    final count = promised.outs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // What is held and the answer are amounts, not changes: no plus.
        row(tr(context, 'Held now', 'Đang có'), safe.liquid, sign: false),
        if (safe.income > BigInt.zero)
          row(
            tr(context, 'Expected in', 'Sẽ nhận'),
            safe.income,
            note: tr(context, 'marked reliable', 'đã đánh dấu chắc chắn'),
          ),
        if (safe.committed > BigInt.zero)
          row(
            tr(context, 'Promised payments', 'Sắp phải trả'),
            -safe.committed,
            note: count == 0 ? null : tr(context, '$count due', '$count khoản'),
          ),
        if (safe.reserves > BigInt.zero)
          row(
            tr(context, 'Saved for goals', 'Để dành mục tiêu'),
            -safe.reserves,
          ),
        if (safe.owe > BigInt.zero)
          row(
            tr(context, 'You owe people', 'Bạn nợ người khác'),
            -safe.owe,
            note: tr(context, 'shared costs', 'chia tiền'),
          ),
        if (safe.buffer > BigInt.zero)
          row(tr(context, 'Buffer', 'Dự phòng'), -safe.buffer),
        const Divider(height: HandySpace.l),
        row(
          safe.shortfall > BigInt.zero
              ? tr(context, 'Short by', 'Còn thiếu')
              : tr(context, 'Free to spend', 'Có thể chi'),
          safe.shortfall > BigInt.zero ? -safe.shortfall : safe.available,
          lead: true,
          sign: false,
          key: const Key('promised-answer'),
        ),
      ],
    );
  }
}
