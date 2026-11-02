import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'diff_view.dart';
import 'inspection.dart';
import 'url_view.dart';

bool _vi(BuildContext c) => Localizations.localeOf(c).languageCode == 'vi';

/// One value row: what it is, what is shown, and what a tap copies.
class DevRow {
  final String label, value;
  final String? shown;
  const DevRow(this.label, this.value, {this.shown});
}

/// Labelled values in code type, each copied by a tap. Long values move
/// under their label instead of being squeezed.
class DevRows extends StatelessWidget {
  final List<DevRow> rows;
  final int lead;
  const DevRows(this.rows, {super.key, this.lead = -1});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return LayoutBuilder(
      builder: (context, size) => HandyGroup(
        color: c.lead,
        children: [
          for (var i = 0; i < rows.length; i++)
            () {
              final r = rows[i];
              final shown = r.shown ?? r.value;
              final style = i == lead
                  ? theme.textTheme.titleLarge?.copyWith(
                      color: c.accent,
                      fontFeatures: tabular,
                    )
                  : theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'GeistMono',
                      package: 'handy_ui',
                      height: 1.45,
                    );
              final label = Text(
                r.label,
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              );
              final value = Text(shown, style: style);
              // About 8.5px per code character at 14px.
              final stack = shown.length * 8.5 > size.maxWidth * .5;
              final copyable = r.value.isNotEmpty;
              return Semantics(
                button: copyable,
                label: '${r.label}: $shown',
                hint: copyable
                    ? tr(context, 'Copy this value', 'Chép giá trị này')
                    : null,
                excludeSemantics: true,
                child: InkWell(
                  key: Key('dev-row-$i'),
                  onTap: copyable
                      ? () => copyToClipboard(context, r.value)
                      : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: HandySpace.l,
                        vertical: 12,
                      ),
                      child: stack
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                label,
                                const SizedBox(height: 2),
                                value,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Expanded(flex: 2, child: label),
                                const SizedBox(width: HandySpace.m),
                                Expanded(
                                  flex: 3,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: value,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

/// The answer in large type in the app's hue, with one line under it.
class Headline extends StatelessWidget {
  final String text;
  final String? caption;
  const Headline(this.text, {super.key, this.caption});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectionArea(
            child: Text(
              text,
              key: const Key('utility-headline'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: c.accent,
                fontFeatures: tabular,
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: HandySpace.xs),
            Text(
              caption!,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Subhead extends StatelessWidget {
  final String text;
  const _Subhead(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, HandySpace.l, 2, HandySpace.s),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

String zoneLabel(BuildContext c, ZoneChoice z, DateTime at) => z.local
    ? '${tr(c, 'device time', 'giờ máy')} UTC${formatOffset(z.offsetAt(at))}'
    : z.label(at);

String _relative(BuildContext c, DateTime t, DateTime now) {
  final r = relativeTime(t, now);
  return _vi(c) ? r.vi : r.en;
}

/// `0b11110000` → `0b1111 0000` for reading; copying keeps the original.
String groupDigits(String s, int n) {
  final m = RegExp(r'^(-?0[box])?(.*)$').firstMatch(s)!;
  final digits = m[2]!;
  final out = StringBuffer(m[1] ?? '');
  final head = digits.length % n;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (i - head) % n == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Each utility lens's own answer.
class UtilityView extends StatelessWidget {
  final Inspection result;
  final ValueChanged<String> onReplace;
  final void Function(IdKind kind, int count) onGenerate;
  const UtilityView({
    super.key,
    required this.result,
    required this.onReplace,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => switch (result.detail) {
    TimestampReading t => _timestamp(context, t),
    IdAnswer a => IdsView(answer: a, onGenerate: onGenerate),
    TextDiff d => DiffView(diff: d),
    CronAnswer c => _cron(context, c),
    BaseConversion b => _base(context, b),
    UrlParts u => UrlView(parts: u, onReplace: onReplace),
    _ => const SizedBox.shrink(),
  };

  Widget _timestamp(BuildContext context, TimestampReading t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Headline(
        wallText(t.instant, t.zone),
        caption:
            '${_relative(context, t.instant, t.now)} · ${zoneLabel(context, t.zone, t.instant)}',
      ),
      DevRows([
        DevRow(tr(context, 'Unix seconds', 'Unix giây'), '${t.unixSeconds}'),
        DevRow(
          tr(context, 'Unix milliseconds', 'Unix mili giây'),
          '${t.unixMilliseconds}',
        ),
        DevRow('ISO-8601 UTC', t.instant.toUtc().toIso8601String()),
        DevRow(
          tr(context, 'ISO-8601 in zone', 'ISO-8601 theo múi'),
          isoInZone(t.instant, t.zone),
        ),
      ]),
    ],
  );

  Widget _cron(BuildContext context, CronAnswer a) {
    final vi = _vi(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Headline(
          a.schedule.describe(vi: vi),
          caption: zoneLabel(context, a.zone, a.now),
        ),
        _Subhead(tr(context, 'Next runs', 'Các lần chạy tới')),
        if (a.runs.isEmpty)
          HandyNotice(
            tr(
              context,
              'No run in the next 8 years.',
              'Không có lần chạy nào trong 8 năm tới.',
            ),
            key: const Key('cron-never'),
            tone: HandyTone.warning,
          )
        else
          DevRows([
            for (final r in a.runs)
              DevRow(
                _relative(context, r, a.now),
                isoInZone(r, a.zone),
                shown: wallText(r, a.zone),
              ),
          ]),
        _Subhead(tr(context, 'Fields', 'Các trường')),
        DevRows([
          for (final f in a.schedule.fields)
            DevRow(vi ? f.nameVi : f.nameEn, f.raw),
        ]),
      ],
    );
  }

  Widget _base(BuildContext context, BaseConversion b) {
    final t = b.twos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevRows(lead: 0, [
          DevRow(
            tr(context, 'Decimal', 'Thập phân'),
            b.decimal,
            shown: formatFigure(context, b.decimal),
          ),
          DevRow('Hex', b.hex, shown: groupDigits(b.hex, 4)),
          DevRow('Octal', b.octal, shown: groupDigits(b.octal, 3)),
          DevRow(
            tr(context, 'Binary', 'Nhị phân'),
            b.binary,
            shown: groupDigits(b.binary, 4),
          ),
          if (b.base != null)
            DevRow(tr(context, 'Base ${b.base}', 'Hệ ${b.base}'), b.inBase!),
        ]),
        if (t != null) ...[
          _Subhead(
            tr(
              context,
              'Two’s complement, ${b.bits} bits',
              'Bù hai, ${b.bits} bit',
            ),
          ),
          DevRows([
            DevRow(tr(context, 'Unsigned', 'Không dấu'), t.unsigned),
            DevRow(tr(context, 'Signed', 'Có dấu'), t.signed),
            DevRow('Hex', t.hex, shown: groupDigits(t.hex, 4)),
            DevRow(
              tr(context, 'Binary', 'Nhị phân'),
              t.binary,
              shown: groupDigits(t.binary, 4),
            ),
          ]),
        ],
      ],
    );
  }
}

/// What pasted IDs are, and a row that makes new ones.
class IdsView extends StatefulWidget {
  final IdAnswer answer;
  final void Function(IdKind kind, int count) onGenerate;
  const IdsView({super.key, required this.answer, required this.onGenerate});
  @override
  State<IdsView> createState() => _IdsViewState();
}

class _IdsViewState extends State<IdsView> {
  // Make more of what is on screen: v7 after a v7, ULID after a ULID.
  late IdKind kind = switch (widget.answer.valid.firstOrNull) {
    {'kind': 'ULID'} => IdKind.ulid,
    {'version': 7} => IdKind.v7,
    _ => IdKind.v4,
  };
  final count = TextEditingController(text: '5');
  String? countError;

  @override
  void dispose() {
    count.dispose();
    super.dispose();
  }

  void generate() {
    final n = int.tryParse(count.text.trim());
    if (n == null || n < 1 || n > maxIds) {
      setState(
        () => countError = tr(
          context,
          'Enter 1 to $maxIds',
          'Nhập từ 1 đến $maxIds',
        ),
      );
      return;
    }
    setState(() => countError = null);
    widget.onGenerate(kind, n);
  }

  String _meta(BuildContext context, Map<String, dynamic> i) {
    if (i['valid'] != true) return i['error'] as String;
    final parts = <String>[
      if (i['special'] != null)
        '${i['special']}'
      else if (i['version'] != null)
        'v${i['version']}'
      else
        '${i['kind']}',
      if (i['timestamp'] != null)
        '${(i['timestamp'] as String).substring(0, 19).replaceFirst('T', ' ')} UTC',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.answer.ids;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final Widget body;
    if (ids.length == 1) {
      final i = ids.single;
      final time = i['timestamp'] == null
          ? null
          : DateTime.parse(i['timestamp'] as String);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Headline(
            i['special'] != null
                ? '${i['special'] == 'nil' ? 'Nil' : 'Max'} UUID'
                : i['version'] != null
                ? 'UUID v${i['version']}'
                : '${i['kind']}',
            caption: i['versionName'] as String?,
          ),
          DevRows([
            DevRow(
              tr(context, 'Canonical', 'Dạng chuẩn'),
              i['canonical'] as String,
            ),
            if (i['variant'] != null) DevRow('Variant', i['variant'] as String),
            if (time != null) ...[
              DevRow(
                tr(context, 'Created (UTC)', 'Tạo lúc (UTC)'),
                i['timestamp'] as String,
              ),
              DevRow(
                tr(context, 'Created', 'Tạo'),
                _relativeNow(context, time),
              ),
            ],
          ]),
        ],
      );
    } else {
      const cap = 200;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DevRows([
            for (final i in ids.take(cap))
              DevRow(
                _meta(context, i),
                (i['canonical'] ?? i['input']) as String,
              ),
          ]),
          if (ids.length > cap)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: Text(
                tr(
                  context,
                  '${ids.length - cap} more not shown; Copy takes them all.',
                  'Còn ${ids.length - cap} ID không hiện; Chép lấy tất cả.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: HandySpace.l),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<IdKind>(
              key: const Key('id-kind'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: IdKind.v4, label: Text('v4')),
                ButtonSegment(value: IdKind.v7, label: Text('v7')),
                ButtonSegment(value: IdKind.ulid, label: Text('ULID')),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                key: const Key('id-count'),
                controller: count,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => generate(),
                decoration: InputDecoration(
                  labelText: tr(context, 'How many', 'Số lượng'),
                  suffixText: 'ID',
                  errorText: countError,
                  errorMaxLines: 2,
                ),
              ),
            ),
            OutlinedButton.icon(
              key: const Key('id-generate'),
              onPressed: generate,
              icon: const Icon(Icons.autorenew, size: 18),
              label: Text(tr(context, 'Make new', 'Tạo mới')),
            ),
          ],
        ),
      ],
    );
  }
}

String _relativeNow(BuildContext c, DateTime t) =>
    _relative(c, t, DateTime.now());
