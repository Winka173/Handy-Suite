import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../services/metadata_types.dart' show readingMaxHtmlBytes;
import 'find_in_text.dart';
import 'highlights_sheet.dart';
import 'reading_position.dart';

/// The text column: title, where the text came from, the blocks, and what
/// was left out. Highlights find matches, brings the current one into view,
/// and reports the reading spot when scrolling stops.
class ArticleView extends StatefulWidget {
  const ArticleView({
    super.key,
    required this.copy,
    required this.fallbackTitle,
    required this.size,
    required this.online,
    required this.saving,
    required this.onSaveOffline,
    required this.onOpenOriginal,
    required this.onSpot,
    this.matches = const [],
    this.current,
    this.reveal = 0,
    this.initialSpot,
    this.marks = const {},
    this.onHighlight,
  });
  final ReadingCopy copy;
  final String fallbackTitle;
  final double size;

  /// Read from the page just now and not saved on this device.
  final bool online, saving;
  final VoidCallback onSaveOffline;
  final VoidCallback? onOpenOriginal;
  final ValueChanged<ReaderSpot> onSpot;
  final List<TextMatch> matches;

  /// Index into [matches] of the one the person is on.
  final int? current;

  /// Bumped when the current match should be brought into view again.
  final int reveal;

  /// Where to open, when this text was read here before.
  final ReaderSpot? initialSpot;

  /// The person's highlights in place, per block: (start, end, colour).
  final Map<int, List<(int, int, String)>> marks;

  /// Offered in the selection menu as Highlight, with the selected text.
  final ValueChanged<String>? onHighlight;

  @override
  State<ArticleView> createState() => ArticleViewState();
}

/// Rows before the first block: title, the source line, the status strip.
const _head = 3;

class ArticleViewState extends State<ArticleView> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  Map<int, List<int>> _byBlock = const {};
  bool _moving = false;
  ReaderSpot? _last;
  String _selected = '';

  ReadingCopy get _copy => widget.copy;
  int get _rows => _head + _copy.blocks.length + 1;

  @override
  void initState() {
    super.initState();
    _index();
    final spot = widget.initialSpot;
    if (spot != null && spot.block < _copy.blocks.length) {
      _last = spot;
      _moving = true;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _reveal(_head + spot.block, into: spot.into, lead: 0),
      );
    }
  }

  @override
  void didUpdateWidget(ArticleView old) {
    super.didUpdateWidget(old);
    if (!identical(old.matches, widget.matches)) _index();
    final c = widget.current;
    if (c != null &&
        c < widget.matches.length &&
        (old.reveal != widget.reveal || old.current != c)) {
      final m = widget.matches[c];
      final len = _copy.blocks[m.block].text.length;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _reveal(
          _head + m.block,
          into: len == 0 ? 0 : m.start / len,
          lead: .3,
          onlyIfHidden: true,
        ),
      );
    } else if (old.size != widget.size && _last != null) {
      // New text size: stay on the same sentence, not the same pixel.
      final spot = _last!;
      _moving = true;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _reveal(_head + spot.block, into: spot.into, lead: 0),
      );
    }
  }

  void _index() {
    final by = <int, List<int>>{};
    for (final (i, m) in widget.matches.indexed) {
      (by[m.block] ??= []).add(i);
    }
    _byBlock = by;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll offset at which [box]'s top meets the viewport's top.
  double _topOf(RenderBox box) =>
      RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;

  RenderBox? _box(int row) {
    final o = _keys[row]?.currentContext?.findRenderObject();
    return o is RenderBox && o.attached && o.hasSize ? o : null;
  }

  /// Brings [row] to the screen, [into] of the way down the row placed
  /// [lead] of the way down the viewport. Rows of a long text are built
  /// lazily, so this estimates, lets a frame build the rows near the
  /// estimate, and tries again until the row exists.
  void _reveal(
    int row, {
    double into = 0,
    double lead = 0,
    bool onlyIfHidden = false,
    int tries = 0,
  }) {
    if (!mounted || !_scroll.hasClients) {
      _moving = false;
      return;
    }
    final pos = _scroll.position;
    final view = pos.viewportDimension;
    double clamp(double v) =>
        v.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    final box = _box(row);
    if (box != null) {
      final point = _topOf(box) + into * box.size.height;
      final shown =
          point >= pos.pixels + view * .05 && point <= pos.pixels + view * .8;
      if (!(onlyIfHidden && shown)) pos.jumpTo(clamp(point - lead * view));
      if (tries < 30 && !onlyIfHidden) {
        // Rows above may have been measured anew; check once more.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final again = _box(row);
          if (again != null &&
              ((_topOf(again) + into * again.size.height - lead * view) -
                          pos.pixels)
                      .abs() >
                  1 &&
              pos.pixels < pos.maxScrollExtent) {
            _reveal(row, into: into, lead: lead, tries: 30);
          } else {
            _settled();
          }
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      } else {
        _settled();
      }
      return;
    }
    if (tries >= 40) return _settled();
    // Estimate from the rows that exist now.
    final built = <(int, double, double)>[];
    for (final e in _keys.entries) {
      final b = _box(e.key);
      if (b != null) built.add((e.key, _topOf(b), b.size.height));
    }
    built.sort((a, b) => a.$1.compareTo(b.$1));
    double target;
    if (built.isEmpty) {
      target = 0;
    } else {
      final avg =
          built.fold<double>(0, (n, r) => n + r.$3) / built.length.toDouble();
      final first = built.first, last = built.last;
      target = row > last.$1
          ? last.$2 + last.$3 + (row - last.$1 - 1) * avg
          : first.$2 - (first.$1 - row) * avg;
      // Always move at least a screen, so a long way converges quickly.
      if (row > last.$1) target = math.max(target, pos.pixels + view);
      if (row < first.$1) target = math.min(target, pos.pixels - view);
    }
    pos.jumpTo(clamp(target));
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _reveal(
        row,
        into: into,
        lead: lead,
        onlyIfHidden: false,
        tries: tries + 1,
      ),
    );
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _settled() {
    if (!_moving) return;
    _moving = false;
  }

  /// The block at the top of the screen and how far into it.
  ReaderSpot? spotNow() {
    if (!_scroll.hasClients) return null;
    final pos = _scroll.position;
    if (pos.pixels <= 0) return const ReaderSpot(0, 0);
    for (final e in _keys.entries) {
      final block = e.key - _head;
      if (block < 0 || block >= _copy.blocks.length) continue;
      final b = _box(e.key);
      if (b == null) continue;
      final top = _topOf(b), h = b.size.height;
      if (top <= pos.pixels + .5 && top + h > pos.pixels) {
        return ReaderSpot(block, h <= 0 ? 0 : (pos.pixels - top) / h);
      }
    }
    return null;
  }

  bool _scrolled(ScrollEndNotification n) {
    if (_moving || n.depth != 0) return false;
    // The rows are laid out at the new offset in the coming frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _moving) return;
      final spot = spotNow();
      if (spot != null) {
        _last = spot;
        widget.onSpot(spot);
      }
    });
    SchedulerBinding.instance.ensureVisualUpdate();
    return false;
  }

  /// Brings [block] to the top of the screen (a highlight, from the list).
  void jumpTo(int block) => _reveal(_head + block);

  InlineSpan _spans(int block, String text, TextStyle style) {
    final hits = _byBlock[block] ?? const <int>[];
    final marks = widget.marks[block] ?? const <(int, int, String)>[];
    if (hits.isEmpty && marks.isEmpty)
      return TextSpan(text: text, style: style);
    final p = BookmarkPalette.of(context);
    // Every place a style starts or stops; a find hit is drawn over a
    // highlight, the current hit over everything.
    final cuts = {0, text.length};
    for (final i in hits) {
      cuts
        ..add(widget.matches[i].start)
        ..add(widget.matches[i].end);
    }
    for (final (a, b, _) in marks) {
      cuts
        ..add(a.clamp(0, text.length))
        ..add(b.clamp(0, text.length));
    }
    final points = cuts.toList()..sort();
    final children = <InlineSpan>[];
    for (var k = 0; k + 1 < points.length; k++) {
      final a = points[k], b = points[k + 1];
      if (a == b) continue;
      int? hit;
      for (final i in hits) {
        final m = widget.matches[i];
        if (m.start <= a && b <= m.end) hit = i;
      }
      String? mark;
      for (final (x, y, color) in marks) {
        if (x <= a && b <= y) mark = color;
      }
      final on = hit != null && hit == widget.current;
      children.add(
        TextSpan(
          text: text.substring(a, b),
          style: hit != null
              ? TextStyle(
                  backgroundColor: on
                      ? p.primary
                      : p.warm.withValues(alpha: .3),
                  color: on ? p.onPrimary : null,
                )
              : mark != null
              ? TextStyle(backgroundColor: highlightWash(context, mark))
              : null,
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }

  Widget _block(BuildContext context, int i, TextStyle body) {
    final size = widget.size;
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final k = _copy.blocks[i];
    if (k.isPicture) {
      // A kept picture of the article, in its place; reading online shows
      // none (pictures are fetched only when the copy is kept).
      final bytes = k.picture;
      if (bytes == null) return const SizedBox.shrink();
      return Semantics(
        image: true,
        label: k.text.isEmpty ? tr(context, 'Picture', 'Ảnh') : k.text,
        child: ClipRRect(
          key: Key('reader-picture-$i'),
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          child: Image.memory(
            bytes,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    return switch (k.kind) {
      'h' => Padding(
        padding: EdgeInsets.only(top: size * .9),
        child: Semantics(
          header: true,
          child: Text.rich(
            _spans(
              i,
              k.text,
              theme.textTheme.titleLarge!.copyWith(
                fontSize: size * 1.22,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ),
      ),
      'quote' => Container(
        padding: EdgeInsetsDirectional.only(start: size * .9),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: p.control, width: 3),
          ),
        ),
        child: Text.rich(
          _spans(i, k.text, body.copyWith(fontStyle: FontStyle.italic)),
        ),
      ),
      'li' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: size * 1.2,
            child: ExcludeSemantics(
              child: Text('•', style: body.copyWith(color: p.muted)),
            ),
          ),
          Expanded(child: Text.rich(_spans(i, k.text, body))),
        ],
      ),
      'pre' => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HandySpace.m),
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text.rich(
            _spans(
              i,
              k.text,
              body.copyWith(
                fontFamily: handyFontFamily('GeistMono'),
                fontSize: size * .85,
                height: 1.45,
              ),
            ),
          ),
        ),
      ),
      _ => Text.rich(_spans(i, k.text, body)),
    };
  }

  Widget _status(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final r = _copy;
    final label = widget.online
        ? tr(
            context,
            'Reading online · not saved on this device',
            'Đang đọc trực tuyến · chưa lưu trên máy',
          )
        : tr(
            context,
            'Offline copy · saved ${formatDay(context, DateTime.parse(r.savedAt).toLocal().toIso8601String().substring(0, 10))}',
            'Bản đọc offline · lưu ${formatDay(context, DateTime.parse(r.savedAt).toLocal().toIso8601String().substring(0, 10))}',
          );
    final ink = widget.online ? p.ink : p.sage;
    return Container(
      key: Key(widget.online ? 'reader-status-online' : 'reader-status-saved'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        HandySpace.m,
        HandySpace.s,
        HandySpace.s,
        HandySpace.s,
      ),
      decoration: BoxDecoration(
        color: widget.online ? p.raised : p.sageTint,
        borderRadius: BorderRadius.circular(BookmarkRadii.field),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final text = Padding(
            padding: const EdgeInsets.symmetric(vertical: HandySpace.s),
            child: Row(
              children: [
                Icon(
                  widget.online ? Icons.language : Icons.offline_pin_outlined,
                  size: 18,
                  color: ink,
                ),
                const SizedBox(width: HandySpace.s),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (!widget.online) return text;
          final save = TextButton.icon(
            key: const Key('reader-save-offline'),
            style: TextButton.styleFrom(foregroundColor: p.primary),
            onPressed: widget.saving ? null : widget.onSaveOffline,
            icon: widget.saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(
              widget.saving
                  ? tr(context, 'Saving…', 'Đang lưu…')
                  : tr(context, 'Save offline', 'Lưu offline'),
            ),
          );
          // Beside the words when they keep room for a few, else below.
          final scale = MediaQuery.textScalerOf(context);
          if (box.maxWidth >= scale.scale(14) * 24 + 48) {
            return Row(
              children: [
                Expanded(child: text),
                save,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, save],
          );
        },
      ),
    );
  }

  Widget _tail(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final note = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: p.muted, height: 1.45);
    final r = _copy;
    return Padding(
      padding: EdgeInsets.only(top: widget.size),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: p.line, height: 1),
          const SizedBox(height: HandySpace.l),
          if (r.truncated) ...[
            Text(
              key: const Key('reader-truncated'),
              tr(
                context,
                'The page is longer. This text stops after its first ${ReadingCopy.maxChars ~/ 1000}k characters; open the original for the rest.',
                'Trang dài hơn. Bản này dừng sau ${ReadingCopy.maxChars ~/ 1000}k ký tự đầu; mở bản gốc để đọc tiếp.',
              ),
              style: note,
            ),
            const SizedBox(height: HandySpace.s),
          ],
          Text(
            tr(
              context,
              'Kept copies hold the text and up to 20 pictures; videos, forms and page layout are left out. Pages over ${readingMaxHtmlBytes ~/ (1024 * 1024)} MB are not read.',
              'Bản đã lưu giữ chữ và tối đa 20 ảnh; video, biểu mẫu và bố cục trang được bỏ qua. Trang trên ${readingMaxHtmlBytes ~/ (1024 * 1024)} MB không được đọc.',
            ),
            style: note,
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            widget.online
                ? tr(
                    context,
                    'Read online from ${r.url}',
                    'Đọc trực tuyến từ ${r.url}',
                  )
                : tr(
                    context,
                    'Offline copy of ${r.url}',
                    'Bản đọc offline của ${r.url}',
                  ),
            style: note,
          ),
          if (widget.onOpenOriginal != null)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: TextButton.icon(
                key: const Key('reader-end-original'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: widget.onOpenOriginal,
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(tr(context, 'Open original', 'Mở bản gốc')),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final size = widget.size;
    final body = theme.textTheme.bodyLarge!.copyWith(
      fontSize: size,
      height: 1.6,
      color: p.ink,
    );
    final r = _copy;
    final minutes = math.max(1, (r.words / 200).ceil());
    // About 65 characters a line at the reading size.
    final measure = MediaQuery.textScalerOf(context).scale(size) * 34;
    Widget row(int i) {
      if (i == 0) {
        return Semantics(
          header: true,
          child: Text(
            r.title.isEmpty ? widget.fallbackTitle : r.title,
            style: bookmarkSerif(context, size * 1.6).copyWith(height: 1.14),
          ),
        );
      }
      if (i == 1) {
        return Padding(
          padding: const EdgeInsets.only(top: HandySpace.s),
          child: Text(
            [
              if (r.siteName.isNotEmpty) r.siteName,
              if (r.byline.isNotEmpty) r.byline,
              tr(context, '$minutes min read', '$minutes phút đọc'),
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
        );
      }
      if (i == 2) {
        return Padding(
          padding: EdgeInsets.only(top: HandySpace.l, bottom: size * 1.2),
          child: _status(context),
        );
      }
      if (i == _rows - 1) return _tail(context);
      return Padding(
        padding: EdgeInsets.only(bottom: size * .8),
        child: _block(context, i - _head, body),
      );
    }

    return NotificationListener<ScrollEndNotification>(
      onNotification: _scrolled,
      child: SelectionArea(
        onSelectionChanged: (c) => _selected = c?.plainText ?? '',
        contextMenuBuilder: (context, state) =>
            AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: [
                ...state.contextMenuButtonItems,
                if (widget.onHighlight != null && _selected.trim().isNotEmpty)
                  ContextMenuButtonItem(
                    label: tr(context, 'Highlight', 'Đánh dấu'),
                    onPressed: () {
                      final text = _selected;
                      ContextMenuController.removeAny();
                      widget.onHighlight!(text);
                    },
                  ),
              ],
            ),
        child: ListView.builder(
          key: const Key('reader-text'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.xl,
            HandySpace.l,
            HandySpace.xxl * 2,
          ),
          itemCount: _rows,
          itemBuilder: (context, i) => KeyedSubtree(
            key: _keys.putIfAbsent(i, GlobalKey.new),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: measure),
                // Full column width, so short lines keep the left edge.
                child: SizedBox(width: double.infinity, child: row(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
