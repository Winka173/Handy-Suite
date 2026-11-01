import 'dart:convert';
import 'package:handy_ui/kit.dart';
import '../http_transport.dart';
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
  const ResponseView({super.key, required this.response});
  @override
  State<ResponseView> createState() => _ResponseViewState();
}

class _ResponseViewState extends State<ResponseView> {
  String? path;
  @override
  Widget build(BuildContext context) {
    final r = widget.response;
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
