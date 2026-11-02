import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../app.dart' show saveAccent;
import '../links/link_actions.dart';
import '../scope.dart';

const _minSize = 14.0, _maxSize = 28.0, _defaultSize = 18.0;

/// A link's offline copy as calm text: one readable column, the person's
/// own size and tone, no pictures, no links. `#/read/<id>` on the web.
class ReaderPage extends StatefulWidget {
  final SaveScope scope;
  final String id;
  const ReaderPage({super.key, required this.scope, required this.id});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late Future<ReadingCopy?> copy = widget.scope.c.readingCopy(widget.id);
  SaveScope get scope => widget.scope;

  double get size =>
      ((scope.c.preferences['readerSize'] as num?)?.toDouble() ?? _defaultSize)
          .clamp(_minSize, _maxSize);
  String get tone => scope.c.preferences['readerTone'] as String? ?? 'app';

  Future<void> _set(String key, Object value) => scope.run(
    context,
    () => scope.c.update((l) => l, prefs: {...scope.c.preferences, key: value}),
  );

  void _size(double step) {
    final next = (size + step).clamp(_minSize, _maxSize);
    if (next != size) _set('readerSize', next);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final page = _page(context);
      return switch (tone) {
        'light' => Theme(
          data: buildHandyTheme(saveAccent, Brightness.light),
          child: page,
        ),
        'dark' => Theme(
          data: buildHandyTheme(saveAccent, Brightness.dark),
          child: page,
        ),
        _ => page,
      };
    },
  );

  Widget _page(BuildContext context) {
    final b = scope.find(widget.id);
    return CallbackShortcuts(
      bindings: {
        for (final meta in [false, true]) ...{
          SingleActivator(
            LogicalKeyboardKey.equal,
            control: !meta,
            meta: meta,
          ): () =>
              _size(2),
          SingleActivator(
            LogicalKeyboardKey.minus,
            control: !meta,
            meta: meta,
          ): () =>
              _size(-2),
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  key: const Key('reader-smaller'),
                  tooltip: tr(context, 'Smaller text', 'Chữ nhỏ hơn'),
                  onPressed: size > _minSize ? () => _size(-2) : null,
                  icon: const Icon(Icons.text_decrease),
                ),
                IconButton(
                  key: const Key('reader-larger'),
                  tooltip: tr(context, 'Larger text', 'Chữ lớn hơn'),
                  onPressed: size < _maxSize ? () => _size(2) : null,
                  icon: const Icon(Icons.text_increase),
                ),
                PopupMenuButton<String>(
                  key: const Key('reader-tone'),
                  tooltip: tr(context, 'Page tone', 'Nền trang'),
                  icon: const Icon(Icons.contrast),
                  initialValue: tone,
                  onSelected: (v) => _set('readerTone', v),
                  itemBuilder: (context) => [
                    for (final (v, label) in [
                      ('app', tr(context, 'Like the app', 'Theo app')),
                      ('light', tr(context, 'Light', 'Sáng')),
                      ('dark', tr(context, 'Dark', 'Tối')),
                    ])
                      CheckedPopupMenuItem(
                        key: Key('reader-tone-$v'),
                        value: v,
                        checked: tone == v,
                        child: Text(label),
                      ),
                  ],
                ),
                if (b != null)
                  IconButton(
                    key: const Key('reader-original'),
                    tooltip: tr(context, 'Open original', 'Mở bản gốc'),
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () => scope.open(context, b),
                  ),
                const SizedBox(width: HandySpace.xs),
              ],
            ),
            body: FutureBuilder<ReadingCopy?>(
              future: copy,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const _Placeholder();
                }
                if (snap.hasError || snap.data == null || b == null) {
                  return _missing(context, b, failed: snap.hasError);
                }
                return _text(context, snap.data!);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _missing(BuildContext context, Bookmark? b, {bool failed = false}) =>
      HandyEmpty(
        title: b == null
            ? tr(context, 'This link was deleted.', 'Link này đã bị xóa.')
            : failed
            ? tr(
                context,
                'This copy could not be read. The link itself is fine.',
                'Chưa đọc được bản này. Bản thân link vẫn nguyên.',
              )
            : tr(
                context,
                'No offline copy of this link',
                'Link này chưa có bản đọc offline',
              ),
        action: b == null
            ? null
            : FilledButton(
                key: const Key('reader-save'),
                onPressed: () async {
                  await scope.saveCopies(context, [b.id]);
                  if (mounted)
                    setState(() => copy = scope.c.readingCopy(widget.id));
                },
                child: Text(
                  tr(context, 'Save offline copy', 'Lưu bản đọc offline'),
                ),
              ),
      );

  Widget _text(BuildContext context, ReadingCopy r) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final body = theme.textTheme.bodyLarge!.copyWith(
      fontSize: size,
      height: 1.6,
      color: theme.colorScheme.onSurface,
    );
    final minutes = (r.words / 200).ceil();
    final saved = formatDay(
      context,
      DateTime.parse(r.savedAt).toLocal().toIso8601String().substring(0, 10),
    );
    Widget block(ReadingBlock k) => switch (k.kind) {
      'h' => Padding(
        padding: EdgeInsets.only(top: size * .9),
        child: Semantics(
          header: true,
          child: Text(
            k.text,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: size * 1.25,
              height: 1.3,
            ),
          ),
        ),
      ),
      'quote' => Container(
        padding: EdgeInsets.only(left: size * .9),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: c.border, width: 3),
          ),
        ),
        child: Text(k.text, style: body.copyWith(fontStyle: FontStyle.italic)),
      ),
      'li' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: size * 1.2,
            child: Text('•', style: body.copyWith(color: c.muted)),
          ),
          Expanded(child: Text(k.text, style: body)),
        ],
      ),
      'pre' => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HandySpace.m),
        decoration: BoxDecoration(
          color: c.raised,
          borderRadius: BorderRadius.circular(HandyRadius.control),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(
            k.text,
            style: body.copyWith(
              fontFamily: 'packages/handy_ui/GeistMono',
              fontSize: size * .85,
              height: 1.45,
            ),
          ),
        ),
      ),
      _ => Text(k.text, style: body),
    };
    final rows = <Widget>[
      Semantics(
        header: true,
        child: Text(
          r.title.isEmpty ? (scope.find(widget.id)?.title ?? '') : r.title,
          style: theme.textTheme.headlineMedium?.copyWith(height: 1.15),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.s),
        child: Text(
          [
            if (r.siteName.isNotEmpty) r.siteName,
            if (r.byline.isNotEmpty) r.byline,
            tr(
              context,
              '$minutes min read · saved $saved',
              '$minutes phút đọc · lưu $saved',
            ),
          ].join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
      ),
      SizedBox(height: size * 1.4),
      for (final k in r.blocks) block(k),
      if (r.truncated)
        Text(
          tr(
            context,
            'The page was longer. This copy keeps its first ${ReadingCopy.maxChars ~/ 1000}k characters; open the original for the rest.',
            'Trang dài hơn. Bản này giữ ${ReadingCopy.maxChars ~/ 1000}k ký tự đầu; mở bản gốc để đọc tiếp.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.l),
        child: Text(
          tr(
            context,
            'Offline copy of ${r.url}',
            'Bản đọc offline của ${r.url}',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ),
    ];
    return SelectionArea(
      child: ListView.builder(
        key: const Key('reader-text'),
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.l,
          HandySpace.l,
          HandySpace.xxl * 2,
        ),
        itemCount: rows.length,
        itemBuilder: (context, i) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            // Full column width, so short lines keep the left edge.
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(bottom: i < 2 ? 0 : size * .8),
              child: rows[i],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reader's frame while the copy loads: flat bars at the text's size.
class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: HandySpace.m),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Semantics(
      label: tr(context, 'Opening the copy', 'Đang mở bản đọc'),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: LayoutBuilder(
              builder: (context, box) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(box.maxWidth * .8, 28),
                  bar(box.maxWidth * .4, 14),
                  const SizedBox(height: HandySpace.l),
                  for (var i = 0; i < 6; i++)
                    bar(box.maxWidth * (i.isEven ? 1 : .9), 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
