import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'query_editor.dart';
import 'utility_views.dart';

/// A URL's parts, its query as an editable table, and the rebuilt URL.
class UrlView extends StatefulWidget {
  final UrlParts parts;
  final ValueChanged<String> onReplace;
  const UrlView({super.key, required this.parts, required this.onReplace});
  @override
  State<UrlView> createState() => _UrlViewState();
}

class _UrlViewState extends State<UrlView> {
  late QueryEditor editor = QueryEditor(widget.parts);

  @override
  void didUpdateWidget(UrlView old) {
    super.didUpdateWidget(old);
    if (old.parts.uri != widget.parts.uri) {
      editor.dispose();
      editor = QueryEditor(widget.parts);
    }
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parts;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final port = p.port ?? defaultPort(p.scheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DevRows(lead: 0, [
          DevRow('Host', p.host.isEmpty ? '—' : p.host),
          DevRow('Scheme', p.scheme),
          if (p.user.isNotEmpty)
            DevRow(tr(context, 'User', 'Người dùng'), p.user),
          if (p.hasPassword)
            DevRow(
              tr(context, 'Password', 'Mật khẩu'),
              '',
              shown: tr(context, 'hidden', 'đã ẩn'),
            ),
          DevRow(
            'Port',
            port == null ? '' : '$port',
            shown: port == null
                ? '—'
                : p.port == null
                ? tr(context, '$port (default)', '$port (mặc định)')
                : '$port',
          ),
          DevRow(
            tr(context, 'Path', 'Đường dẫn'),
            p.path.isEmpty ? '/' : p.path,
          ),
          if (p.fragment.isNotEmpty) DevRow('Fragment', p.fragment),
        ]),
        ListenableBuilder(
          listenable: editor,
          builder: (context, _) {
            String? url, error;
            try {
              url = editor.url;
            } on FormatException catch (e) {
              error = e.message;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HandyLabel(
                  tr(
                    context,
                    'Query parameters (${editor.rows.length})',
                    'Tham số query (${editor.rows.length})',
                  ),
                  trailing: editor.edited
                      ? TextButton(
                          key: const Key('query-reset'),
                          onPressed: editor.reset,
                          child: Text(tr(context, 'Undo edits', 'Bỏ sửa')),
                        )
                      : null,
                ),
                if (editor.rows.isNotEmpty) const _ParamHeader(),
                for (var i = 0; i < editor.rows.length; i++)
                  _ParamRow(
                    key: ObjectKey(editor.rows[i]),
                    index: i,
                    name: editor.rows[i].$1,
                    value: editor.rows[i].$2,
                    onRemove: () => editor.remove(i),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('query-add'),
                    onPressed: editor.full ? null : editor.add,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(tr(context, 'Add parameter', 'Thêm tham số')),
                  ),
                ),
                const SizedBox(height: HandySpace.s),
                if (error != null)
                  HandyNotice(error, tone: HandyTone.error)
                else ...[
                  Card(
                    color: c.lead,
                    child: Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: SelectionArea(
                        child: Text(
                          url!,
                          key: const Key('url-rebuilt'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'GeistMono',
                            package: 'handy_ui',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: HandySpace.m),
                  Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      FilledButton.icon(
                        key: const Key('url-copy'),
                        onPressed: () => copyToClipboard(context, url!),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(tr(context, 'Copy URL', 'Chép URL')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('url-use'),
                        onPressed: editor.edited
                            ? () => widget.onReplace(url!)
                            : null,
                        icon: const Icon(Icons.north_west, size: 18),
                        label: Text(
                          tr(context, 'Use as source', 'Dùng làm nguồn'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Below this width a parameter's name sits above its value.
const _sideBySide = 300.0;

/// Column names over the parameter fields, when they sit side by side.
class _ParamHeader extends StatelessWidget {
  const _ParamHeader();
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: HandyColors.of(context).muted);
    return LayoutBuilder(
      builder: (context, size) => size.maxWidth < _sideBySide
          ? const SizedBox.shrink()
          : ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 48, HandySpace.xs),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(tr(context, 'Name', 'Tên'), style: style),
                    ),
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      flex: 3,
                      child: Text(
                        tr(context, 'Value', 'Giá trị'),
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  final int index;
  final TextEditingController name, value;
  final VoidCallback onRemove;
  const _ParamRow({
    super.key,
    required this.index,
    required this.name,
    required this.value,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final code = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
    );
    final n = TextField(
      key: Key('query-name-$index'),
      controller: name,
      style: code,
      decoration: InputDecoration(labelText: tr(context, 'Name', 'Tên')),
    );
    final v = TextField(
      key: Key('query-value-$index'),
      controller: value,
      style: code,
      decoration: InputDecoration(labelText: tr(context, 'Value', 'Giá trị')),
    );
    final remove = IconButton(
      key: Key('query-remove-$index'),
      tooltip: tr(context, 'Remove parameter', 'Bỏ tham số'),
      icon: const Icon(Icons.close, size: 20),
      onPressed: onRemove,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.s),
      child: LayoutBuilder(
        builder: (context, size) => size.maxWidth >= _sideBySide
            ? Row(
                children: [
                  Expanded(flex: 2, child: n),
                  const SizedBox(width: HandySpace.s),
                  Expanded(flex: 3, child: v),
                  remove,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        n,
                        const SizedBox(height: HandySpace.xs),
                        v,
                      ],
                    ),
                  ),
                  remove,
                ],
              ),
      ),
    );
  }
}
