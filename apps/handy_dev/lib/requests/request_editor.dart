import 'package:flutter/services.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'auth_fields.dart';
import 'response_view.dart';
import 'workspace.dart';

const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'];

/// One request: method, address and Send on one line; headers, sign-in and
/// body behind a compact switch; the response right under it.
class RequestEditor extends StatefulWidget {
  final Workspace ws;
  final ApiRequest request;
  final VoidCallback? onBack;
  const RequestEditor({
    super.key,
    required this.ws,
    required this.request,
    this.onBack,
  });
  @override
  State<RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<RequestEditor> {
  late final name = TextEditingController(text: widget.request.name);
  late final url = TextEditingController(text: widget.request.url);
  late final body = TextEditingController(text: widget.request.body);
  late final headers = TextEditingController(
    text: widget.request.headers.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n'),
  );
  late String method = widget.request.method;
  late ApiAuth auth = widget.request.auth;
  int part = 0;

  @override
  void dispose() {
    for (final c in [name, url, body, headers]) {
      c.dispose();
    }
    super.dispose();
  }

  ApiRequest build_() => ApiRequest(
    id: widget.request.id,
    name: name.text.trim().isEmpty
        ? tr(context, 'Untitled', 'Chưa đặt tên')
        : name.text.trim(),
    url: url.text.trim(),
    method: method,
    body: body.text,
    headers: {
      for (final line in headers.text.split('\n'))
        if (line.contains(':'))
          line.substring(0, line.indexOf(':')).trim(): line
              .substring(line.indexOf(':') + 1)
              .trim(),
    },
    auth: auth,
  );

  Future<void> guard(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (mounted && done != null) showHandyMessage(context, done);
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          e is FormatException
              ? e.message
              : tr(
                  context,
                  'Could not save. Nothing changed.',
                  'Chưa lưu được. Không có gì thay đổi.',
                ),
        );
      }
    }
  }

  Future<void> remove() async {
    final ws = widget.ws;
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete "${name.text}"?', 'Xóa "${name.text}"?'),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok) return;
    if (!ws.saved) return ws.select(null);
    await guard(() async {
      await ws.commit(removeRequest(ws.value, widget.request.id));
      ws.select(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ws = widget.ws;
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
    );
    return ListenableBuilder(
      listenable: ws,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.s,
          HandySpace.l,
          HandySpace.xxl,
        ),
        children: [
          Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  key: const Key('request-back'),
                  tooltip: tr(context, 'All requests', 'Tất cả request'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
              Expanded(
                child: TextField(
                  key: const Key('request-name'),
                  controller: name,
                  maxLength: 200,
                  style: theme.textTheme.titleLarge,
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    hintText: tr(context, 'Request name', 'Tên request'),
                    counterText: '',
                  ),
                ),
              ),
              OutlinedButton(
                key: const Key('request-save'),
                onPressed: () => guard(
                  () => ws.save(build_()),
                  tr(
                    context,
                    'Saved without secrets',
                    'Đã lưu, không kèm bí mật',
                  ),
                ),
                child: Text(tr(context, 'Save', 'Lưu')),
              ),
              HandyMenuButton(
                items: [
                  HandyMenuItem(
                    Icons.content_copy,
                    tr(
                      context,
                      'Copy cURL without secrets',
                      'Chép cURL, không kèm bí mật',
                    ),
                    () {
                      guard(
                        () => copyToClipboard(
                          context,
                          exportCurl(sanitizeRequest(build_())),
                        ),
                      );
                    },
                  ),
                  HandyMenuItem(
                    Icons.content_paste,
                    tr(
                      context,
                      'Fill from a copied cURL',
                      'Điền từ cURL đã chép',
                    ),
                    () => guard(() async {
                      final text =
                          (await Clipboard.getData('text/plain'))?.text ?? '';
                      final r = importCurl(text);
                      setState(() {
                        url.text = r.url;
                        method = r.method;
                        body.text = r.body;
                        headers.text = r.headers.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n');
                        auth = r.auth;
                      });
                    }),
                  ),
                  HandyMenuItem(
                    Icons.copy_all_outlined,
                    tr(context, 'Duplicate', 'Nhân bản'),
                    () {
                      ws.openDraft(
                        build_().copyWith(
                          id: Workspace.newId('r'),
                          name: '${name.text} (2)',
                        ),
                      );
                    },
                  ),
                  HandyMenuItem(
                    Icons.delete_outline,
                    tr(context, 'Delete', 'Xóa'),
                    remove,
                    destructive: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: HandySpace.s),
          LayoutBuilder(
            builder: (context, size) {
              final methodField = SizedBox(
                width: 128,
                child: DropdownButtonFormField<String>(
                  key: const Key('request-method'),
                  initialValue: method,
                  isExpanded: true,
                  items: [
                    for (final m in methods)
                      DropdownMenuItem(
                        value: m,
                        child: Text(m, style: mono),
                      ),
                  ],
                  onChanged: (v) => setState(() => method = v!),
                ),
              );
              final urlField = TextField(
                key: const Key('request-url'),
                controller: url,
                style: mono,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: 'https://{{baseUrl}}/v1/items',
                ),
              );
              final go = ws.sending
                  ? OutlinedButton(
                      key: const Key('cancel'),
                      onPressed: ws.cancel,
                      child: Text(tr(context, 'Cancel', 'Hủy')),
                    )
                  : FilledButton.icon(
                      key: const Key('send'),
                      onPressed: () => ws.send(build_()),
                      icon: const Icon(Icons.send, size: 18),
                      label: Text(tr(context, 'Send', 'Gửi')),
                    );
              // Phones: method and Send in reach of the thumb, the address
              // on its own full-width line.
              if (size.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [methodField, const Spacer(), go]),
                    const SizedBox(height: HandySpace.s),
                    urlField,
                  ],
                );
              }
              return Row(
                children: [
                  methodField,
                  const SizedBox(width: HandySpace.s),
                  Expanded(child: urlField),
                  const SizedBox(width: HandySpace.s),
                  go,
                ],
              );
            },
          ),
          const SizedBox(height: HandySpace.l),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 0,
                label: Text(tr(context, 'Headers', 'Header')),
              ),
              ButtonSegment(
                value: 1,
                label: Text(tr(context, 'Sign-in', 'Xác thực')),
              ),
              ButtonSegment(value: 2, label: Text(tr(context, 'Body', 'Body'))),
            ],
            selected: {part},
            onSelectionChanged: (s) => setState(() => part = s.first),
          ),
          const SizedBox(height: HandySpace.m),
          switch (part) {
            0 => TextField(
              key: const Key('request-headers'),
              controller: headers,
              minLines: 3,
              maxLines: 8,
              style: mono,
              decoration: const InputDecoration(
                hintText: 'Accept: application/json',
              ),
            ),
            1 => AuthFields(
              auth: auth,
              onChanged: (a) => setState(() => auth = a),
            ),
            _ => TextField(
              key: const Key('request-body'),
              controller: body,
              minLines: 4,
              maxLines: 14,
              style: mono,
              decoration: const InputDecoration(hintText: '{ "name": "…" }'),
            ),
          },
          const SizedBox(height: HandySpace.xl),
          // Sending, the response and an error each fade in; nothing jumps.
          HandySwap(
            child: Column(
              key: ValueKey(
                ws.sending
                    ? 'sending'
                    : ws.response != null
                    ? 'response-${identityHashCode(ws.response)}'
                    : ws.sendError != null
                    ? 'error'
                    : 'empty',
              ),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ws.sending) const LinearProgressIndicator(),
                if (ws.sendError != null)
                  HandyNotice(
                    tr(context, ws.sendError!.$1, ws.sendError!.$2),
                    key: const Key('send-error'),
                    tone: HandyTone.error,
                  ),
                if (ws.response != null)
                  ResponseView(response: ws.response!, previous: ws.previous),
                if (!ws.sending && ws.response == null && ws.sendError == null)
                  HandyEmpty(
                    title: tr(
                      context,
                      'Send to see the response here.',
                      'Gửi để xem phản hồi ở đây.',
                    ),
                    message: tr(
                      context,
                      'HTTPS only · up to 1 MB · 15 s. Secrets stay in this session.',
                      'Chỉ HTTPS · tối đa 1 MB · 15 giây. Bí mật chỉ giữ trong phiên.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
