import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../app.dart' show saveAccent;
import '../design/theme.dart';
import '../scope.dart';
import 'article_view.dart';
import 'find_bar.dart';
import 'find_in_text.dart';
import 'highlights_sheet.dart';
import '../pro/entitlements.dart';
import 'reader_session.dart';
import 'reader_states.dart';
import 'reading_position.dart';

const _minSize = 14.0, _maxSize = 28.0, _defaultSize = 18.0;

/// One item's text as calm reading: the offline copy when there is one,
/// otherwise the page read online on this tap (never in the background),
/// with Save offline to keep it. Find in the article, the person's own
/// size and tone, and the spot they stopped at, remembered on this device
/// for this version of the text. `#/read/<id>` on the web.
class ReaderPage extends StatefulWidget {
  final SaveScope scope;
  final String id;
  const ReaderPage({super.key, required this.scope, required this.id});
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  SaveScope get scope => widget.scope;
  late final session = ReaderSession(scope.c, widget.id)..addListener(_changed);
  final positions = ReadingPositions.instance;
  final _page = FocusNode(debugLabel: 'reader');

  // The text on screen, its version and where to open it.
  ReadingCopy? _shown;
  String? _version;
  ReaderSpot? _initial, _spot;
  bool _ready = false, _spotDirty = false;
  Timer? _spotTimer;

  // Find in article.
  bool finding = false;
  final _query = TextEditingController();
  final _findFocus = FocusNode(debugLabel: 'reader-find');
  TextFinder? _finder;
  List<TextMatch> _matches = const [];
  int? _current;
  int _reveal = 0;
  static const _findLimit = 1000;

  // Highlights: one article view per text version, to jump within it.
  final _articles = <String, GlobalKey<ArticleViewState>>{};
  ArticleViewState? get _article => _articles[_version ?? '']?.currentState;

  Map<int, List<(int, int, String)>> _marks(ReadingCopy r) {
    final blocks = [for (final b in r.blocks) b.text];
    final out = <int, List<(int, int, String)>>{};
    for (final h in highlightsOf(scope.c, widget.id)) {
      final at = anchorHighlight(h, blocks);
      if (at != null) (out[at.$1] ??= []).add((at.$2, at.$3, h.color));
    }
    return out;
  }

  /// Marks the selected words (Pro); existing highlights stay readable
  /// and editable without it.
  Future<void> _highlight(BuildContext context, String text) async {
    final r = _shown;
    if (r == null) return;
    if (!await requirePro(context, ProFeature.readerHighlights) ||
        !context.mounted)
      return;
    final blocks = [for (final b in r.blocks) b.text];
    final at = locateQuote(text, blocks, _spot?.block ?? 0);
    if (at == null) {
      showHandyMessage(
        context,
        tr(
          context,
          'Could not find those words in the text.',
          'Không tìm thấy đoạn chữ đó trong bài.',
        ),
      );
      return;
    }
    final (block, start, end) = at;
    final list = highlightsOf(scope.c, widget.id);
    final h = Highlight(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      block: block,
      start: start,
      end: end,
      quote: blocks[block].substring(start, end),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    if (list.length >= Highlight.maxPerItem) return;
    await saveHighlights(scope.c, widget.id, [...list, h]);
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr(context, 'Highlighted.', 'Đã đánh dấu.')),
          action: SnackBarAction(
            key: const Key('highlight-add-note'),
            label: tr(context, 'Add a note', 'Thêm ghi chú'),
            onPressed: () async {
              final next = await editHighlight(context, h);
              if (next == null) return;
              await saveHighlights(scope.c, widget.id, [
                for (final x in highlightsOf(scope.c, widget.id))
                  x.id == h.id ? next : x,
              ]);
              if (mounted) setState(() {});
            },
          ),
        ),
      );
  }

  Future<void> _openHighlights(BuildContext context, Bookmark? b) async {
    final r = _shown;
    await showHighlights(
      context,
      controller: scope.c,
      id: widget.id,
      title: r?.title.isNotEmpty == true ? r!.title : (b?.title ?? ''),
      url: b?.originalUrl ?? r?.url ?? '',
      blocks: [for (final x in r?.blocks ?? const <ReadingBlock>[]) x.text],
      onJump: (block) => _article?.jumpTo(block),
    );
    if (mounted) setState(() {});
  }

  double get size =>
      ((scope.c.preferences['readerSize'] as num?)?.toDouble() ?? _defaultSize)
          .clamp(_minSize, _maxSize);
  String get tone => scope.c.preferences['readerTone'] as String? ?? 'app';

  @override
  void initState() {
    super.initState();
    // After the first build, so a quick answer can set state.
    Future.microtask(session.open);
  }

  @override
  void dispose() {
    _flushSpot();
    session
      ..removeListener(_changed)
      ..dispose();
    _query.dispose();
    _findFocus.dispose();
    _page.dispose();
    super.dispose();
  }

  void _changed() {
    final r = session.copy;
    if (r == null) {
      _shown = null;
      _ready = false;
      _finder = null;
      if (mounted) setState(() {});
      return;
    }
    if (identical(r, _shown)) {
      if (mounted) setState(() {});
      return;
    }
    final version = copyVersion(r);
    final same = version == _version;
    _shown = r;
    _finder = TextFinder([for (final b in r.blocks) b.text]);
    if (same && _ready) {
      // Saved offline: the same words, so the spot and the find stay.
      if (finding) _search(_query.text, keepCurrent: true);
      if (mounted) setState(() {});
      return;
    }
    _version = version;
    _ready = false;
    _initial = null;
    if (mounted) setState(() {});
    positions.spot(widget.id, version).then((spot) {
      if (!mounted || _version != version) return;
      setState(() {
        _initial = spot;
        _spot = spot;
        _ready = true;
        if (finding) _search(_query.text);
      });
    });
  }

  void _onSpot(ReaderSpot spot) {
    _spot = spot;
    _spotDirty = true;
    _spotTimer?.cancel();
    _spotTimer = Timer(const Duration(milliseconds: 600), _flushSpot);
  }

  /// Writes the spot once scrolling has rested (or the reader closes).
  void _flushSpot() {
    _spotTimer?.cancel();
    _spotTimer = null;
    final v = _version;
    if (_spotDirty && v != null) positions.remember(widget.id, v, _spot);
    _spotDirty = false;
  }

  Future<void> _set(String key, Object value) => scope.run(
    context,
    () => scope.c.update((l) => l, prefs: {...scope.c.preferences, key: value}),
  );

  void _size(double step) {
    final next = (size + step).clamp(_minSize, _maxSize);
    if (next != size) _set('readerSize', next);
  }

  // Find ---------------------------------------------------------------

  bool get _canFind => _ready && _shown != null;

  void _openFind() {
    if (!_canFind) return;
    setState(() {
      finding = true;
      _search(_query.text);
    });
    _query.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _query.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _findFocus.requestFocus();
    });
  }

  void _closeFind() {
    setState(() {
      finding = false;
      _matches = const [];
      _current = null;
    });
    _page.requestFocus();
  }

  /// Runs the search; the first match is the first one from where the
  /// person is reading, not from the top.
  void _search(String q, {bool keepCurrent = false}) {
    final finder = _finder;
    final before = _current;
    _matches = finder == null ? const [] : finder.search(q, limit: _findLimit);
    if (_matches.isEmpty) {
      _current = null;
    } else if (keepCurrent && before != null && before < _matches.length) {
      _current = before;
    } else {
      final from = _spot?.block ?? 0;
      final i = _matches.indexWhere((m) => m.block >= from);
      _current = i < 0 ? 0 : i;
      _reveal++;
    }
  }

  void _step(int by) {
    if (_matches.isEmpty) return;
    setState(() {
      _current = ((_current ?? -by) + by) % _matches.length;
      _reveal++;
    });
  }

  // Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final page = _scaffold(context);
      return switch (tone) {
        'light' => Theme(
          data: bookmarkTheme(buildHandyTheme(saveAccent, Brightness.light)),
          child: page,
        ),
        'dark' => Theme(
          data: bookmarkTheme(buildHandyTheme(saveAccent, Brightness.dark)),
          child: page,
        ),
        _ => page,
      };
    },
  );

  Widget _scaffold(BuildContext context) {
    final b = scope.find(widget.id);
    final linked = b != null && b.hasUrl && !b.isImage;
    void original() {
      if (b != null) scope.open(context, b);
    }

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
          SingleActivator(LogicalKeyboardKey.keyF, control: !meta, meta: meta):
              _openFind,
          SingleActivator(
            LogicalKeyboardKey.keyG,
            control: !meta,
            meta: meta,
          ): () =>
              _step(1),
          SingleActivator(
            LogicalKeyboardKey.keyG,
            control: !meta,
            meta: meta,
            shift: true,
          ): () =>
              _step(-1),
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            finding ? _closeFind() : Navigator.maybePop(context),
      },
      child: Focus(
        focusNode: _page,
        autofocus: true,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  key: const Key('reader-highlights'),
                  tooltip: tr(context, 'Highlights', 'Đoạn đánh dấu'),
                  onPressed: _shown == null
                      ? null
                      : () => _openHighlights(context, b),
                  // A count in the app's hue, never a red alert.
                  icon: Badge(
                    backgroundColor: BookmarkPalette.of(context).primary,
                    textColor: BookmarkPalette.of(context).onPrimary,
                    isLabelVisible: highlightsOf(scope.c, widget.id).isNotEmpty,
                    label: Text('${highlightsOf(scope.c, widget.id).length}'),
                    child: const Icon(Icons.format_quote_rounded),
                  ),
                ),
                IconButton(
                  key: const Key('reader-find'),
                  tooltip: tr(context, 'Find in article', 'Tìm trong bài'),
                  onPressed: _canFind ? _openFind : null,
                  icon: const Icon(Icons.search),
                ),
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
                if (linked)
                  IconButton(
                    key: const Key('reader-original'),
                    tooltip: tr(context, 'Open original', 'Mở bản gốc'),
                    icon: const Icon(Icons.open_in_new),
                    onPressed: original,
                  ),
                const SizedBox(width: HandySpace.xs),
              ],
            ),
            body: Column(
              children: [
                if (finding && _canFind)
                  ReaderFindBar(
                    controller: _query,
                    focus: _findFocus,
                    count: _matches.length,
                    current: _current,
                    capped: _matches.length >= _findLimit,
                    onChanged: (q) => setState(() => _search(q)),
                    onNext: () => _step(1),
                    onPrevious: () => _step(-1),
                    onClose: _closeFind,
                  ),
                Expanded(child: _body(context, b, linked ? original : null)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Bookmark? b, VoidCallback? original) {
    switch (session.state) {
      case ReaderState.opening:
        return const ReaderLoading();
      case ReaderState.fetching:
        return ReaderLoading(
          host: Uri.tryParse(b?.originalUrl ?? '')?.host ?? '',
          onCancel: session.cancel,
        );
      case ReaderState.failed:
        return ReaderNotice(
          problem: session.problem ?? '',
          address: Uri.tryParse(b?.originalUrl ?? '')?.host ?? '',
          onOpenOriginal: original,
          onRetry: session.readOnline,
        );
      case ReaderState.unreadable:
        final p = session.problem ?? '';
        return ReaderNotice(
          problem: p,
          onOpenOriginal: p == 'browser' || p == 'notWeb' ? original : null,
        );
      case ReaderState.reading:
        final r = _shown;
        if (r == null || !_ready) return const ReaderLoading();
        return ArticleView(
          key: _articles.putIfAbsent(_version ?? '', GlobalKey.new),
          copy: r,
          marks: _marks(r),
          onHighlight: (text) => _highlight(context, text),
          fallbackTitle: b?.title ?? '',
          size: size,
          online: session.online,
          saving: session.saving,
          onSaveOffline: _saveOffline,
          onOpenOriginal: original,
          onSpot: _onSpot,
          matches: finding ? _matches : const [],
          current: finding ? _current : null,
          reveal: _reveal,
          initialSpot: _initial,
        );
    }
  }

  Future<void> _saveOffline() async {
    final ok = await session.saveOffline();
    if (!mounted) return;
    showHandyMessage(
      context,
      ok
          ? tr(context, 'Saved for offline reading.', 'Đã lưu bản đọc offline.')
          : tr(
              context,
              'Could not save the copy. Nothing was changed.',
              'Chưa lưu được bản đọc. Không có gì thay đổi.',
            ),
    );
  }
}
