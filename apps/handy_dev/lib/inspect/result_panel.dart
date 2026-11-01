import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'inspection.dart';
import 'json_view.dart';
import 'lenses.dart';
import 'status_line.dart';

String _fact(BuildContext c, String key) {
  final parts = key.split(':');
  final n = parts.length > 1 ? formatFigure(c, parts[1]) : '';
  return switch (parts.first) {
    'valid' => tr(c, 'valid', 'hợp lệ'),
    'invalid' => tr(c, 'invalid', 'không hợp lệ'),
    'expired' => tr(c, 'expired', 'đã hết hạn'),
    'not-expired' => tr(c, 'not expired', 'còn hạn'),
    'unsigned' => tr(c, 'signature not checked', 'chưa kiểm chữ ký'),
    'matches' => tr(c, '$n matches', '$n kết quả khớp'),
    'keys' => tr(c, '$n keys', '$n khóa'),
    'items' => tr(c, '$n items', '$n phần tử'),
    _ => key,
  };
}

/// The answer to "what is in it": a tree, text or a request, with the
/// status line under it and Copy as the primary action.
class ResultPanel extends StatelessWidget {
  final Inspection result;
  final String input;
  final String? path;
  final ValueChanged<String> onPath;
  final VoidCallback onCopy, onSave;
  final ValueChanged<ApiRequest> onOpenRequest;
  const ResultPanel({
    super.key,
    required this.result,
    required this.input,
    required this.path,
    required this.onPath,
    required this.onCopy,
    required this.onSave,
    required this.onOpenRequest,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final lines = '\n'.allMatches(input).length + 1;
    final status = StatusLine(
      path: r.tree != null ? path : null,
      parts: [
        StatusPart(kindLabel(context, r.kind)),
        StatusPart(formatBytes(context, input.length)),
        StatusPart(tr(context, '$lines lines', '$lines dòng')),
        if (r.error.isNotEmpty)
          StatusPart(tr(context, 'error', 'lỗi'), good: false),
        for (final f in facts(r)) StatusPart(_fact(context, f.$1), good: f.$2),
      ],
    );
    final Widget body;
    if (r.needsOption) {
      body = HandyEmpty(
        title: tr(
          context,
          'Fill in ${r.lens.option!.en.toLowerCase()} above.',
          'Điền ${r.lens.option!.vi.toLowerCase()} ở trên.',
        ),
      );
    } else if (r.error.isNotEmpty) {
      body = HandyNotice(
        r.error,
        key: const Key('dev-error'),
        tone: HandyTone.error,
      );
    } else if (r.request != null) {
      final q = r.request!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyValueRows([
            (tr(context, 'Method', 'Method'), q.method),
            ('URL', q.url),
            (tr(context, 'Headers', 'Header'), '${q.headers.length}'),
            (tr(context, 'Body', 'Body'), formatBytes(context, q.body.length)),
          ]),
          const SizedBox(height: HandySpace.m),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('open-request'),
              onPressed: () => onOpenRequest(q),
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(tr(context, 'Open in Requests', 'Mở trong Request')),
            ),
          ),
        ],
      );
    } else if (r.tree != null) {
      body = JsonTreeView(value: r.tree, onSelect: onPath);
    } else {
      body = Card(
        color: c.lead,
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: SelectionArea(
            child: Text(
              r.text!.isEmpty ? '—' : r.text!,
              key: const Key('dev-output'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'GeistMono',
                package: 'handy_ui',
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: HandySpace.m),
        status,
        if (r.ok && r.request == null) ...[
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            children: [
              FilledButton.icon(
                key: const Key('dev-copy'),
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(tr(context, 'Copy result', 'Sao chép kết quả')),
              ),
              IconButton.outlined(
                key: const Key('dev-save-file'),
                tooltip: tr(context, 'Save as file', 'Lưu thành file'),
                icon: const Icon(Icons.download_outlined, size: 20),
                onPressed: onSave,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
