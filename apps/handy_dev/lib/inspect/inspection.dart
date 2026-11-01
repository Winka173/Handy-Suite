import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'detect.dart';
import 'lenses.dart';

/// Lenses whose answer is a finding to explore rather than text to copy.
const treeLenses = {
  'jwt',
  'regex',
  'schema',
  'json-diff',
  'jsonpath',
  'json-project',
  'har',
};

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
  const Inspection({
    required this.kind,
    required this.lens,
    this.text,
    this.tree,
    this.request,
    this.error = '',
    this.needsOption = false,
  });
  bool get ok =>
      error.isEmpty &&
      !needsOption &&
      (text != null || tree != null || request != null);

  /// What Copy and Save take.
  String get copy =>
      text ??
      (tree == null ? '' : const JsonEncoder.withIndent('  ').convert(tree));
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
  List<String> chain = const [],
}) {
  Inspection fail(String e) => Inspection(kind: kind, lens: lens, error: e);
  try {
    if (chain.isNotEmpty) {
      var out = input;
      for (final id in chain) {
        out = devTools.firstWhere((t) => t.id == id).run(out);
      }
      return Inspection(kind: kind, lens: lens, text: out);
    }
    if (lens.id == 'tree') {
      return Inspection(kind: kind, lens: lens, tree: parseJson(input));
    }
    if (lens.id == 'curl') {
      return Inspection(kind: kind, lens: lens, request: importCurl(input));
    }
    final o = lens.option;
    if (o != null && !o.optional && option.trim().isEmpty) {
      return Inspection(kind: kind, lens: lens, needsOption: true);
    }
    final out = lens.engine!.run(input, o == null ? '' : o.encode(option));
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
