import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'detect.dart';
import 'lenses.dart';

/// Lenses whose answer is a finding to explore rather than text to copy.
const treeLenses = {'jwt', 'regex', 'schema', 'json-diff', 'json-filter'};

/// Inputs above this size wait for an explicit Run so typing never stalls.
const liveLimit = 200000;

/// One look at a payload through one lens (or a chain of safe lenses).
class Inspection {
  final DataKind kind;
  final Lens lens;

  /// Engine output as text, when the lens produced text.
  final String? text;

  /// Structured value to show as a tree: the input itself for `tree`, or an
  /// engine output that is a JSON object/array.
  final dynamic tree;

  /// Request parsed from a cURL command.
  final ApiRequest? request;
  final String error;

  /// The lens needs its option before it can run.
  final bool needsOption;

  /// Typed answer of a utility lens (timestamp, IDs, diff, cron, bases,
  /// URL), drawn by its own view.
  final Object? detail;

  /// What Copy and Save take when it is not [text] or [tree].
  final String? copyText;
  const Inspection({
    required this.kind,
    required this.lens,
    this.text,
    this.tree,
    this.request,
    this.error = '',
    this.needsOption = false,
    this.detail,
    this.copyText,
  });
  bool get ok =>
      error.isEmpty &&
      !needsOption &&
      (text != null || tree != null || request != null || detail != null);

  /// What Copy and Save take.
  String get copy =>
      copyText ??
      text ??
      (tree == null ? '' : const JsonEncoder.withIndent('  ').convert(tree));
}

/// A cron line with its next runs, read in [zone].
class CronAnswer {
  final CronSchedule schedule;
  final List<DateTime> runs;
  final ZoneChoice zone;
  final DateTime now;
  const CronAnswer(this.schedule, this.runs, this.zone, this.now);
}

/// UUIDs and ULIDs, one report per line.
class IdAnswer {
  final List<Map<String, dynamic>> ids;
  const IdAnswer(this.ids);
  Iterable<Map<String, dynamic>> get valid =>
      ids.where((i) => i['valid'] == true);

  /// The IDs in canonical form, one per line, for Copy.
  String get canonical => valid.map((i) => i['canonical']).join('\n');
}

/// Lenses with a view of their own instead of a tree or text.
const utilityLenses = {
  'timestamp',
  'uuid',
  'text-diff',
  'cron',
  'base-convert',
  'url-parse',
};

ZoneChoice _zone(Lens lens, String typed, Map<String, String> picks) =>
    typed.trim().isNotEmpty
    ? ZoneChoice.parse(typed)
    : lens.pick(picks, 'zone') == 'utc'
    ? const ZoneChoice.utc()
    : const ZoneChoice.local();

String _pretty(dynamic v) => const JsonEncoder.withIndent('  ').convert(v);

Inspection _utility(
  String input,
  DataKind kind,
  Lens lens,
  String option,
  Map<String, String> picks,
  DateTime now,
) {
  Inspection done(Object detail, String copy) =>
      Inspection(kind: kind, lens: lens, detail: detail, copyText: copy);
  switch (lens.id) {
    case 'timestamp':
      final r = readTimestamp(
        input,
        zone: _zone(lens, option, picks),
        now: now,
      );
      return done(r, _pretty(r.toJson()));
    case 'uuid':
      final ids = inspectIds(input);
      if (ids.isEmpty) throw const FormatException('No IDs / Không có ID');
      if (ids.length == 1 && ids.single['valid'] != true) {
        throw FormatException(ids.single['error'] as String);
      }
      final a = IdAnswer(ids);
      return done(a, a.canonical);
    case 'text-diff':
      if (option.isEmpty) {
        return Inspection(kind: kind, lens: lens, needsOption: true);
      }
      final d = diffText(input, option);
      return done(d, d.unified());
    case 'cron':
      final c = parseCron(input);
      final zone = _zone(lens, option, picks);
      final count = int.parse(lens.pick(picks, 'count'));
      return done(
        CronAnswer(c, c.next(count, zone, from: now), zone, now),
        _pretty(cronReport(c, zone, count, from: now)),
      );
    case 'base-convert':
      final o = option.trim();
      final base = o.isEmpty ? null : int.tryParse(o);
      if (o.isNotEmpty && base == null) {
        throw const FormatException(
          'Base must be a number 2–36 / Hệ cơ số phải là số từ 2 đến 36',
        );
      }
      final bits = lens.pick(picks, 'bits');
      final b = convertBase(
        input,
        base: base,
        bits: bits.isEmpty ? null : int.parse(bits),
      );
      return done(b, _pretty(b.toJson()));
    default:
      final u = parseUrl(input);
      return done(u, _pretty(u.toJson()));
  }
}

dynamic _structured(String s) {
  final t = s.trimLeft();
  if (!t.startsWith('{') && !t.startsWith('[')) return null;
  try {
    final v = jsonDecode(s);
    return v is Map || v is List ? v : null;
  } catch (_) {
    return null;
  }
}

Inspection inspect(
  String input,
  DataKind kind,
  Lens lens, {
  String option = '',
  Map<String, String> picks = const {},
  List<String> chain = const [],
  DateTime? now,
}) {
  Inspection fail(String e) => Inspection(kind: kind, lens: lens, error: e);
  try {
    if (chain.isNotEmpty) {
      var out = input;
      for (final id in chain) {
        out = runDevTool(id, out);
      }
      return Inspection(kind: kind, lens: lens, text: out);
    }
    if (lens.id == 'tree') {
      return Inspection(kind: kind, lens: lens, tree: parseJson(input));
    }
    if (lens.id == 'curl') {
      return Inspection(kind: kind, lens: lens, request: importCurl(input));
    }
    if (utilityLenses.contains(lens.id)) {
      return _utility(input, kind, lens, option, picks, now ?? DateTime.now());
    }
    final o = lens.option;
    if (o != null && !o.optional && option.trim().isEmpty) {
      return Inspection(kind: kind, lens: lens, needsOption: true);
    }
    final out = lens.engine!.run(
      input,
      lens.encode != null
          ? lens.encode!(option, (id) => lens.pick(picks, id))
          : o == null
          ? ''
          : o.encode(option),
    );
    // Analyses read best as a tree; conversions are text to copy.
    final tree = treeLenses.contains(lens.id) ? _structured(out) : null;
    return Inspection(
      kind: kind,
      lens: lens,
      text: tree == null ? out : null,
      tree: tree,
    );
  } on FormatException catch (e) {
    return fail(e.message);
  } catch (e) {
    return fail('$e');
  }
}

/// Facts for the status line, as (text, good?) pairs; text is bilingual by
/// key so the view can translate.
List<(String, bool?)> facts(Inspection r) {
  final out = <(String, bool?)>[];
  switch (r.detail) {
    case TimestampReading t:
      out.add(('unit:${t.source.name}', null));
    case IdAnswer a:
      final bad = a.ids.length - a.valid.length;
      if (a.ids.length == 1) {
        final i = a.ids.single;
        out.add((
          'id:${i['kind']}${i['version'] == null ? '' : ' v${i['version']}'}',
          null,
        ));
      } else {
        out.add(('ids:${a.valid.length}', null));
      }
      if (bad > 0) out.add(('bad-ids:$bad', false));
    case TextDiff d:
      out.add(
        d.identical
            ? ('identical', true)
            : ('diff:${d.added}:${d.removed}', null),
      );
    case CronAnswer c:
      out.add(
        c.runs.isEmpty
            ? ('never', false)
            : ('next:${c.runs.first.toIso8601String()}', null),
      );
    case BaseConversion b when b.bits != null:
      out.add(('bits:${b.bits}', null));
    case UrlParts u:
      out.add(('params:${u.query.length}', null));
  }
  final t = r.tree;
  if (t is Map) {
    if (t['valid'] is bool)
      out.add((t['valid'] == true ? 'valid' : 'invalid', t['valid'] as bool));
    if (t['expired'] is bool)
      out.add((
        t['expired'] == true ? 'expired' : 'not-expired',
        t['expired'] != true,
      ));
    if (t['signatureVerified'] == false) out.add(('unsigned', null));
    if (t['matches'] is List)
      out.add(('matches:${(t['matches'] as List).length}', null));
    if (!t.containsKey('valid') &&
        !t.containsKey('matches') &&
        !t.containsKey('expired')) {
      out.add(('keys:${t.length}', null));
    }
  } else if (t is List) {
    out.add(('items:${t.length}', null));
  }
  return out;
}
