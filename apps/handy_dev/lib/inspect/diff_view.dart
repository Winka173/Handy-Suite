import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';

/// Most rows drawn; Copy still takes the whole diff.
const _rowCap = 1500;

/// Unchanged lines kept around each change before the rest fold away.
const _context = 3;

/// One drawn row: a pair of lines, or a fold of unchanged ones.
class _Row {
  final DiffLine? left, right;
  final int folded;
  const _Row(this.left, this.right) : folded = 0;
  const _Row.fold(this.folded) : left = null, right = null;
}

/// Long runs of unchanged rows fold to one "N unchanged lines" row.
List<_Row> _fold(List<(DiffLine?, DiffLine?)> pairs) {
  bool same((DiffLine?, DiffLine?) p) => p.$1?.op == DiffOp.same;
  final out = <_Row>[];
  var i = 0;
  while (i < pairs.length) {
    if (!same(pairs[i])) {
      out.add(_Row(pairs[i].$1, pairs[i].$2));
      i++;
      continue;
    }
    var j = i;
    while (j < pairs.length && same(pairs[j])) {
      j++;
    }
    final keepHead = i == 0 ? 0 : _context;
    final keepTail = j == pairs.length ? 0 : _context;
    if (j - i > keepHead + keepTail + 1) {
      for (var k = i; k < i + keepHead; k++) {
        out.add(_Row(pairs[k].$1, pairs[k].$2));
      }
      out.add(_Row.fold(j - i - keepHead - keepTail));
      for (var k = j - keepTail; k < j; k++) {
        out.add(_Row(pairs[k].$1, pairs[k].$2));
      }
    } else {
      for (var k = i; k < j; k++) {
        out.add(_Row(pairs[k].$1, pairs[k].$2));
      }
    }
    i = j;
  }
  return out;
}

/// Line changes side by side (wide) or as one unified column (narrow), with
/// + and − signs so the change never rests on colour alone.
class DiffView extends StatefulWidget {
  final TextDiff diff;
  const DiffView({super.key, required this.diff});
  @override
  State<DiffView> createState() => _DiffViewState();
}

class _DiffViewState extends State<DiffView> {
  bool? sideBySide;

  @override
  Widget build(BuildContext context) {
    final d = widget.diff;
    if (d.identical) {
      return HandyNotice(
        tr(context, 'The two texts are the same.', 'Hai bản giống nhau.'),
        key: const Key('diff-identical'),
        tone: HandyTone.success,
      );
    }
    return LayoutBuilder(
      builder: (context, size) {
        final side = sideBySide ?? size.maxWidth >= 600;
        final rows = _fold(
          side
              ? d.sideBySide()
              : [
                  for (final l in d.lines)
                    l.op == DiffOp.added
                        ? (null, l)
                        : (l, l.op == DiffOp.same ? l : null),
                ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                key: const Key('diff-layout'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(tr(context, 'Side by side', 'Hai cột')),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(tr(context, 'Unified', 'Gộp')),
                  ),
                ],
                selected: {side},
                onSelectionChanged: (s) => setState(() => sideBySide = s.first),
              ),
            ),
            const SizedBox(height: HandySpace.m),
            Card(
              key: const Key('diff-rows'),
              clipBehavior: Clip.antiAlias,
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in rows.take(_rowCap))
                      r.folded > 0
                          ? _FoldRow(r.folded)
                          : side
                          ? _SideRow(r.left, r.right)
                          : _UnifiedRow(r.left ?? r.right!),
                  ],
                ),
              ),
            ),
            if (rows.length > _rowCap)
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.s),
                child: Text(
                  tr(
                    context,
                    'Showing the first $_rowCap rows; Copy takes the whole diff.',
                    'Đang hiện $_rowCap dòng đầu; Chép lấy toàn bộ.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}

TextStyle? _code(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
      fontSize: 13,
      height: 1.5,
    );

Color? _fill(BuildContext context, DiffOp? op) {
  final c = HandyColors.of(context);
  return switch (op) {
    DiffOp.removed => c.negativeBg,
    DiffOp.added => c.positiveBg,
    _ => null,
  };
}

String _sign(DiffOp op) => switch (op) {
  DiffOp.removed => '−',
  DiffOp.added => '+',
  DiffOp.same => ' ',
};

class _Cell extends StatelessWidget {
  final DiffLine? line;
  final int? number;
  const _Cell(this.line, this.number);
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final style = _code(context);
    final l = line;
    return Container(
      color: _fill(context, l?.op),
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.s,
        vertical: 1,
      ),
      child: l == null
          ? const SizedBox(height: 19)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    '${number ?? ''}',
                    textAlign: TextAlign.end,
                    style: style?.copyWith(color: c.muted, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Text(
                    _sign(l.op),
                    textAlign: TextAlign.center,
                    style: style?.copyWith(
                      color: l.op == DiffOp.removed
                          ? c.negative
                          : l.op == DiffOp.added
                          ? c.positive
                          : c.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(l.text.isEmpty ? ' ' : l.text, style: style),
                ),
              ],
            ),
    );
  }
}

class _SideRow extends StatelessWidget {
  final DiffLine? left, right;
  const _SideRow(this.left, this.right);
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _Cell(left, left?.before)),
        VerticalDivider(width: 1, color: HandyColors.of(context).rule),
        Expanded(child: _Cell(right, right?.after)),
      ],
    ),
  );
}

class _UnifiedRow extends StatelessWidget {
  final DiffLine line;
  const _UnifiedRow(this.line);
  @override
  Widget build(BuildContext context) =>
      _Cell(line, line.op == DiffOp.added ? line.after : line.before);
}

class _FoldRow extends StatelessWidget {
  final int count;
  const _FoldRow(this.count);
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Container(
      color: c.raised,
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.m,
        vertical: HandySpace.xs,
      ),
      child: Text(
        tr(context, '$count unchanged lines', '$count dòng giống nhau'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted),
      ),
    );
  }
}
