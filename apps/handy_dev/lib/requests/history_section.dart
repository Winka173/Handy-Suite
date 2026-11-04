import '../inspect/status_line.dart' show formatBytes;
import 'package:handy_ui/kit.dart';
import 'request_list.dart' show MethodTag;
import 'workspace.dart';

/// "Sent": the opt-in history under the collections. Off by default; what
/// one send keeps is said before it is turned on.
class SendHistorySection extends StatelessWidget {
  final Workspace ws;
  const SendHistorySection({super.key, required this.ws});

  static String when(BuildContext context, String at) {
    final t = DateTime.parse(at).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)} ${t.day}/${t.month}';
  }

  /// The part that tells sends apart: path and query names, without the
  /// scheme and host every row shares. Templates stay whole.
  static String pathOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasAuthority) return url;
    return '${u.path.isEmpty ? '/' : u.path}${u.hasQuery ? '?${u.query}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final h = ws.history;
    final small = theme.textTheme.bodySmall?.copyWith(color: c.muted);
    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
      fontSize: 13,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          tr(context, 'Sent', 'Đã gửi'),
          trailing: Semantics(
            label: tr(context, 'Keep a history of sends', 'Ghi lịch sử gửi'),
            child: Switch(
              key: const Key('history-keep'),
              value: h.on,
              onChanged: (on) async {
                if (!on && h.items.isNotEmpty) {
                  final ok = await confirmHandy(
                    context,
                    title: tr(
                      context,
                      'Stop and forget ${h.items.length} sends?',
                      'Tắt và xoá ${h.items.length} lần gửi?',
                    ),
                    message: tr(
                      context,
                      'Saved requests stay.',
                      'Request đã lưu vẫn giữ.',
                    ),
                    confirmLabel: tr(context, 'Stop', 'Tắt'),
                  );
                  if (!ok) return;
                }
                await ws.keepHistory(on);
              },
            ),
          ),
        ),
        if (!h.on)
          Text(
            tr(
              context,
              'Off. When on, each send keeps its method, address without query values, status, time and size, never headers, bodies or secrets. Up to 50, on this device.',
              'Đang tắt. Khi bật, mỗi lần gửi giữ method, địa chỉ bỏ giá trị query, mã trả về, thời gian và kích thước; không bao giờ giữ header, body hay bí mật. Tối đa 50, trên máy này.',
            ),
            key: const Key('history-off'),
            style: small,
          )
        else if (h.items.isEmpty)
          Text(tr(context, 'Nothing sent yet.', 'Chưa gửi gì.'), style: small)
        else
          HandyGroup(
            children: [
              for (final (i, s) in h.items.take(20).indexed)
                ListTile(
                  key: Key('sent-$i'),
                  dense: true,
                  isThreeLine: true,
                  enabled: ws.value.requests.any((r) => r.id == s.requestId),
                  onTap: () => ws.openSent(s),
                  leading: SizedBox(
                    width: 60,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MethodTag(
                        s.method,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ),
                  // The request's name as it is now, else as it was sent.
                  title: Text(
                    ws.value.requests
                            .where((r) => r.id == s.requestId)
                            .firstOrNull
                            ?.name ??
                        s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pathOf(s.url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono?.copyWith(color: c.muted),
                      ),
                      Text(
                        [
                          s.status?.toString() ??
                              tr(context, 'no answer', 'không có phản hồi'),
                          if (s.status != null) '${s.elapsedMs} ms',
                          if (s.status != null) formatBytes(context, s.bytes),
                          when(context, s.at),
                        ].join(' · '),
                        style: small?.copyWith(
                          color: s.status == null || s.status! >= 400
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
