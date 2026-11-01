import 'dart:convert';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import '../code_highlighter.dart';
import '../ui/paper.dart';
import 'reader_actions.dart';

/// The open document's own buttons: keep it, star it, and the rest.
class DocumentActions extends StatelessWidget {
  final ReaderActions actions;
  final bool source;
  final ValueChanged<bool> onSource;
  const DocumentActions({
    super.key,
    required this.actions,
    required this.source,
    required this.onSource,
  });
  @override
  Widget build(BuildContext context) {
    final store = actions.store, d = store.current!;
    final busy = actions.busy.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!store.saved)
          FilledButton(
            key: const Key('reader-save'),
            onPressed: busy ? null : () => actions.keep(context),
            child: Text(tr(context, 'Save copy', 'Lưu bản sao')),
          )
        else
          IconButton(
            key: Key('reader-favorite-${d.id}'),
            tooltip: d.favorite
                ? tr(context, 'Remove star', 'Bỏ gắn sao')
                : tr(context, 'Star', 'Gắn sao'),
            onPressed: busy ? null : () => actions.favorite(context, d),
            icon: Icon(d.favorite ? Icons.star : Icons.star_border),
          ),
        HandyMenuButton(
          items: [
            if (d.kind == 'html' || d.kind == 'markdown')
              HandyMenuItem(
                source ? Icons.article_outlined : Icons.code,
                source
                    ? tr(context, 'Show as a page', 'Hiện như trang')
                    : tr(context, 'Show the source', 'Hiện mã nguồn'),
                () => onSource(!source),
                key: const Key('reader-source'),
              ),
            if (store.saved)
              HandyMenuItem(
                Icons.drive_file_rename_outline,
                tr(context, 'Name and folder', 'Tên và thư mục'),
                busy ? null : () => actions.properties(context, d),
                key: const Key('reader-properties'),
              ),
            HandyMenuItem(
              Icons.save_alt,
              tr(context, 'Save the original', 'Lưu bản gốc'),
              busy ? null : () => actions.export(context, d),
              key: const Key('reader-export'),
            ),
            if (localShareSupported)
              HandyMenuItem(
                Icons.ios_share,
                tr(context, 'Share', 'Chia sẻ'),
                () => shareFile(
                  context,
                  name: d.name,
                  mimeType: 'text/plain',
                  bytes: actions.store.source(d),
                ),
              ),
            if (store.saved)
              HandyMenuItem(
                Icons.delete_outline,
                tr(context, 'Remove from library', 'Xóa khỏi thư viện'),
                busy ? null : () => actions.remove(context, d),
                destructive: true,
                key: const Key('reader-remove'),
              ),
          ],
        ),
      ],
    );
  }
}

/// The document itself on a sheet, with a literal find above it. Pages show
/// as pages (scripts, pictures and links never load); code keeps its
/// spacing.
class DocumentBody extends StatefulWidget {
  final ReaderDocument document;
  final bool source, saved;
  const DocumentBody({
    super.key,
    required this.document,
    required this.source,
    required this.saved,
  });
  @override
  State<DocumentBody> createState() => _DocumentBodyState();
}

class _DocumentBodyState extends State<DocumentBody> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final c = HandyColors.of(context);
    String text;
    String? problem;
    try {
      text = d.kind == 'html' && !widget.source
          ? readableHtml(d.source)
          : d.source;
    } on FormatException catch (e) {
      text = '';
      problem = e.message;
    }
    final matches = query.isEmpty ? null : findMarkdownLiteral(text, query);
    return ListView(
      key: ValueKey('reader-preview-${d.id}'),
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        0,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  [
                    widget.saved
                        ? tr(context, 'In your library', 'Trong thư viện')
                        : tr(
                            context,
                            'Unsaved import',
                            'Tài liệu nhập chưa lưu',
                          ),
                    if (d.folder.isNotEmpty) d.folder,
                    tr(
                      context,
                      '${formatFigure(context, '${text.length}')} characters',
                      '${formatFigure(context, '${text.length}')} ký tự',
                    ),
                  ].join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.muted),
                ),
                const SizedBox(height: HandySpace.s),
                TextField(
                  key: const Key('reader-search'),
                  maxLength: 10000,
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    counterText: '',
                    prefixIcon: const Icon(Icons.search),
                    hintText: tr(
                      context,
                      'Find in this document',
                      'Tìm trong tài liệu',
                    ),
                    suffixText: matches == null
                        ? null
                        : tr(
                            context,
                            '${matches.count} matches',
                            '${matches.count} kết quả',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HandySpace.l),
        if (problem != null)
          HandyNotice(problem, tone: HandyTone.warning)
        else
          PaperSheet(child: _content(d, text, matches?.count ?? 0)),
      ],
    );
  }

  Widget _content(ReaderDocument d, String text, int count) {
    if (d.kind == 'markdown' &&
        !widget.source &&
        query.isEmpty &&
        utf8.encode(text).length <= 100000) {
      try {
        return MarkdownBody(
          data: parseMarkdownDocument(text).source,
          selectable: true,
          syntaxHighlighter: LocalCodeHighlighter(dark: false),
          imageBuilder: (_, _, alt) => Text(
            '[${tr(context, 'Image blocked', 'Ảnh bị chặn')}: ${alt ?? ''}]',
          ),
          onTapLink: (_, url, _) => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr(context, 'Link destination', 'Đích liên kết')),
              content: SelectableText(url ?? ''),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Close', 'Đóng')),
                ),
              ],
            ),
          ),
        );
      } on FormatException {
        // Shown as text below.
      }
    }
    final mono = d.kind == 'code';
    final style = TextStyle(
      fontFamily: mono ? 'GeistMono' : null,
      package: mono ? 'handy_ui' : null,
      height: 1.55,
    );
    if (query.isNotEmpty && count > 0 && count <= 1000) {
      final parts = text.split(query);
      return SelectableText.rich(
        key: const Key('reader-content'),
        TextSpan(
          style: style,
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              TextSpan(text: parts[i]),
              if (i < parts.length - 1)
                TextSpan(
                  text: query,
                  style: const TextStyle(backgroundColor: Color(0xFFFFE08A)),
                ),
            ],
          ],
        ),
      );
    }
    return SelectableText(text, key: const Key('reader-content'), style: style);
  }
}
