import 'package:handy_ui/kit.dart';
import 'specs.dart';

String copyText(Output o) => switch (o) {
  ValueOutput o => o.value,
  ScheduleOutput o => o.copy,
  RowsOutput o => o.copy,
  TextOutput o => o.text,
};

/// Renders a tool's answer; the leading figure carries the app's hue.
class OutputView extends StatelessWidget {
  final Output output;
  const OutputView(this.output, {super.key});
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: const Key('tool-output'),
    child: switch (output) {
      ValueOutput o => Card(
        color: HandyColors.of(context).lead,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: SizedBox(
            width: double.infinity,
            child: HandyResultView(
              o.value,
              caption: o.caption.isEmpty ? null : o.caption,
              money: o.money,
            ),
          ),
        ),
      ),
      ScheduleOutput o => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyValueRows(o.rows, lead: o.lead),
          const SizedBox(height: HandySpace.m),
          ScheduleTable(o.schedule),
        ],
      ),
      RowsOutput o => HandyValueRows(o.rows, lead: o.lead),
      TextOutput o => Card(
        color: HandyColors.of(context).lead,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: SizedBox(
            width: double.infinity,
            child: SelectionArea(
              child: Text(
                o.text.isEmpty ? '—' : o.text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    },
  );
}

/// Month-by-month loan table: right-aligned tabular figures, first 12 rows
/// until the reader asks for the rest.
class ScheduleTable extends StatefulWidget {
  final List<List<String>> rows;
  const ScheduleTable(this.rows, {super.key});
  @override
  State<ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  bool all = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall;
    final body = theme.textTheme.bodyMedium?.copyWith(fontFeatures: tabular);
    final shown = all ? widget.rows : widget.rows.take(12).toList();
    Widget row(List<String> cells, TextStyle? style) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.l,
        vertical: 10,
      ),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(cells[0], style: style)),
          for (final i in [1, 2, 4])
            Expanded(
              child: Text(
                formatFigure(context, cells[i]),
                style: style,
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
    // Below 480px the table becomes two-line rows: month and payment first,
    // interest and balance in grey under them. No figure ever wraps.
    Widget narrow(List<String> r) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.l,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Month ${r[0]}', 'Tháng ${r[0]}'),
                  style: body,
                ),
              ),
              Text(formatFigure(context, r[1]), style: body),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              context,
              'Interest ${formatFigure(context, r[2])} · balance ${formatFigure(context, r[4])}',
              'Lãi ${formatFigure(context, r[2])} · còn ${formatFigure(context, r[4])}',
            ),
            textAlign: TextAlign.end,
            style: muted?.copyWith(fontFeatures: tabular),
          ),
        ],
      ),
    );
    final wide = MediaQuery.sizeOf(context).width >= 480;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) ...[
            row([
              tr(context, 'Month', 'Tháng'),
              tr(context, 'Payment', 'Trả'),
              tr(context, 'Interest', 'Lãi'),
              '',
              tr(context, 'Balance', 'Còn nợ'),
            ], muted),
            const Divider(),
          ],
          for (final r in shown) wide ? row(r, body) : narrow(r),
          if (widget.rows.length > 12) ...[
            const Divider(),
            TextButton(
              onPressed: () => setState(() => all = !all),
              child: Text(
                all
                    ? tr(
                        context,
                        'Show first 12 months',
                        'Chỉ hiện 12 tháng đầu',
                      )
                    : tr(
                        context,
                        'Show all ${widget.rows.length} months',
                        'Hiện cả ${widget.rows.length} tháng',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
