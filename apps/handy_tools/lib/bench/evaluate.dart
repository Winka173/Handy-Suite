import 'package:handy_ui/kit.dart';
import '../specs.dart';
import '../tool_output.dart';
import 'tape.dart';

/// One run of a tool: either an answer or an engine message.
class Evaluation {
  final Output? output;
  final String raw, error;
  const Evaluation.ok(this.output, this.raw) : error = '';
  const Evaluation.failed(this.error) : output = null, raw = '';
  bool get ok => output != null;

  /// What Copy and Save take: the engine's own values, never the display.
  String get copy => output == null ? '' : copyText(output!);

  /// Engine value that joins the tape's total, when the answer is a number.
  String? get number => switch (output) {
    ValueOutput o when isPlainNumber(o.value) => o.value,
    RowsOutput o when isPlainNumber(_amount(o.rows[o.lead].$2)) => _amount(
      o.rows[o.lead].$2,
    ),
    _ => null,
  };

  /// A money figure joins the total without its unit.
  static String _amount(String s) =>
      s.endsWith(' đ') ? s.substring(0, s.length - 2) : s;
}

const liveLimit = 20000;

Evaluation evaluate(
  BuildContext context,
  ToolSpec spec,
  Map<String, String> v,
) {
  try {
    final (input, options) = spec.encode(v);
    final raw = spec.engine.run(input, options);
    return Evaluation.ok(spec.present(context, raw, v), raw);
  } on FormatException catch (e) {
    return Evaluation.failed(e.message);
  } catch (_) {
    return Evaluation.failed('Invalid input');
  }
}

/// Runs text transforms one after another, as a saved chain would.
Evaluation runChain(List<String> steps, String text) {
  try {
    var out = text;
    for (final id in steps) {
      out = runStep(id, out);
    }
    return Evaluation.ok(TextOutput(out), out);
  } on FormatException catch (e) {
    return Evaluation.failed(e.message);
  }
}
