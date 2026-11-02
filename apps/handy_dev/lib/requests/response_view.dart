import 'dart:convert';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import '../http_transport.dart';
import '../inspect/diff_view.dart';
import '../inspect/json_view.dart';
import '../inspect/status_line.dart';

String reason(int status) => switch (status) {
  200 => 'OK',
  201 => 'Created',
  204 => 'No Content',
  301 || 302 => 'Redirect',
  304 => 'Not Modified',
  400 => 'Bad Request',
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  409 => 'Conflict',
  422 => 'Unprocessable',
  429 => 'Too Many Requests',
  500 => 'Server Error',
  502 => 'Bad Gateway',
  503 => 'Unavailable',
  _ => '',
};

/// What came back: the status line first (the screen's answer), then the
/// body as a tree when it is JSON.
class ResponseView extends StatefulWidget {
  final ApiResponse response;

  /// What the same request got the time before, when it was sent before.
  final ApiResponse? previous;
  const ResponseView({super.key, required this.response, this.previous});
  @override
  State<ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<ResponseView> {
  String? path;
  bool comparing = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.response, before = widget.previous;
    if (before != null && comparing)
      return _Compare(
        before: before,
        after: r,
        onBack: () => setState(() => comparing = false),
      );
    dynamic json;
    try {
      final v = jsonDecode(r.body);
      if (v is Map || v is List) json = v;
    } catch (_) {}
    final ok = r.status >= 200 && r.status < 400;
    return Column(
      key: const Key('response'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusLine(
          path: json == null ? null : path,
          parts: [
            StatusPart('${r.status} ${reason(r.status)}'.trim(), good: ok),
            StatusPart('${formatFigure(context, '${r.elapsedMs}')} ms'),
            StatusPart(formatBytes(context, r.bytes)),
            if (json != null) const StatusPart('JSON'),
          ],
        ),
        if (before != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('response-compare'),
              onPressed: () => setState(() => comparing = true),
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: Text(
                tr(
                  context,
                  'Compare with the time before',
                  'So với lần gửi trước',
                ),
              ),
            ),
          ),
        const SizedBox(height: HandySpace.m),
        if (r.body.isEmpty)
          HandyEmpty(
            title: tr(
              context,
              'The response has no body.',
              'Phản hồi không có body.',
            ),
          )
        else if (json != null)
          JsonTreeView(value: json, onSelect: (p) => setState(() => path = p))
        else
          Card(
            color: HandyColors.of(context).lead,
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: SelectionArea(
                child: Text(
                  r.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'GeistMono',
                    package: 'handy_ui',
                  ),
                ),
              ),
            ),
          ),
        if (r.body.isNotEmpty) ...[
          const SizedBox(height: HandySpace.m),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('response-copy'),
              onPressed: () => copyToClipboard(context, r.body),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(tr(context, 'Copy body', 'Sao chép body')),
            ),
          ),
        ],
      ],
    );
  }
}

/// [body] laid out for comparing: JSON indented with its keys sorted, so
/// only real changes show; anything else as it came.
String comparable(String body) {
  dynamic sorted(dynamic v) => v is Map
      ? {for (final k in v.keys.toList()..sort()) k: sorted(v[k])}
      : v is List
      ? v.map(sorted).toList()
      : v;
  try {
    return const JsonEncoder.withIndent('  ').convert(sorted(jsonDecode(body)));
  } catch (_) {
    return body;
  }
}

/// This response against the one before it: the status line's changes as
/// signed figures, then the bodies line by line.
class _Compare extends StatelessWidget {
  final ApiResponse before, after;
  final VoidCallback onBack;
  const _Compare({
    required this.before,
    required this.after,
    required this.onBack,
  });
  @override
  Widget build(BuildContext context) {
    String signed(int d, String unit) =>
        '${d > 0
            ? '+'
            : d < 0
            ? '−'
            : '±'}${formatFigure(context, '${d.abs()}')}$unit';
    final ms = after.elapsedMs - before.elapsedMs;
    final bytes = after.bytes - before.bytes;
    TextDiff? diff;
    try {
      diff = diffText(comparable(before.body), comparable(after.body));
    } on FormatException {
      diff = null;
    }
    return Column(
      key: const Key('response-comparison'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusLine(
          parts: [
            StatusPart(
              before.status == after.status
                  ? '${after.status}'
                  : '${before.status} → ${after.status}',
              good: after.status >= 200 && after.status < 400,
            ),
            StatusPart(signed(ms, ' ms')),
            StatusPart(
              bytes == 0
                  ? tr(context, 'same size', 'cùng cỡ')
                  : '${bytes > 0 ? '+' : '−'}${formatBytes(context, bytes.abs())}',
            ),
          ],
        ),
        const SizedBox(height: HandySpace.m),
        if (diff == null)
          HandyNotice(
            tr(
              context,
              'These bodies are too long to compare here.',
              'Hai body quá dài để so ở đây.',
            ),
          )
        else
          DiffView(diff: diff),
        const SizedBox(height: HandySpace.m),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('response-compare-back'),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 18),
            label: Text(tr(context, 'This response', 'Phản hồi lần này')),
          ),
        ),
      ],
    );
  }
}
