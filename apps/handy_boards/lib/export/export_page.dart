import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../board/board_menus.dart' show ProBadge;
import '../design/theme.dart';
import '../features/portability.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'board_report.dart';

/// The three ways a board is drawn for sharing. Plain is free.
enum PosterStyle { plain, poster, print, report }

/// Export: the board as it will be saved (a picture or a PDF), in a style;
/// data formats (CSV, Markdown, ICS, backup) one tap away.
class ExportPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const ExportPage({super.key, required this.scope, required this.board});
  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  PosterStyle style = PosterStyle.plain;

  /// Custom field values on the cards (Pro), when the board has fields.
  bool fields = false;
  final boundary = GlobalKey();
  bool busy = false;

  Future<Uint8List> _png() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> _save({required bool pdf}) async {
    if ((style != PosterStyle.plain || fields) &&
        !await requirePro(context, ProFeature.export))
      return;
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final png = await _png();
      final name = widget.scope.state
          .get('boards', widget.board)
          .str('title')
          .replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '')
          .trim();
      final file = name.isEmpty ? 'handy-board' : name;
      Uint8List bytes = png;
      if (pdf) {
        final decoded = await decodeImageFromList(png);
        final w = decoded.width / 2, h = decoded.height / 2;
        decoded.dispose();
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(w * .75, h * .75, marginAll: 0),
            build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.contain),
          ),
        );
        bytes = await doc.save();
      }
      final path = await widget.scope.files.exportBytes(
        pdf ? '$file.pdf' : '$file.png',
        bytes,
        mimeType: pdf ? 'application/pdf' : 'image/png',
      );
      if (mounted && path != null)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr(context, 'Saved', 'Đã lưu'))));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Could not save; nothing changed.',
                'Chưa lưu được; không có gì thay đổi.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final s = widget.scope.state;
    final hasFields = fieldsOf(s, widget.board).isNotEmpty;
    final locked =
        (style != PosterStyle.plain || (fields && hasFields)) &&
        !hasPro(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Export board', 'Xuất bảng'))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (v, en, vi) in const [
                  (PosterStyle.plain, 'Plain', 'Đơn giản'),
                  (PosterStyle.poster, 'Poster', 'Poster'),
                  (PosterStyle.print, 'Printable', 'Bản in'),
                  (PosterStyle.report, 'Report', 'Báo cáo'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Center(
                      child: ChoiceChip(
                        key: Key('export-style-${v.name}'),
                        label: Text(tr(context, en, vi)),
                        avatar: v == PosterStyle.plain || hasPro(context)
                            ? null
                            : const Icon(
                                Icons.workspace_premium_outlined,
                                size: 16,
                              ),
                        selected: style == v,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => style = v),
                      ),
                    ),
                  ),
                if (hasFields)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Center(
                      child: FilterChip(
                        key: const Key('export-fields'),
                        label: Text(
                          tr(context, 'Custom fields', 'Trường tuỳ chỉnh'),
                        ),
                        avatar: hasPro(context)
                            ? null
                            : const Icon(
                                Icons.workspace_premium_outlined,
                                size: 16,
                              ),
                        selected: fields,
                        onSelected: (v) => setState(() => fields = v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: p.sunk,
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 4,
                constrained: false,
                child: RepaintBoundary(
                  key: boundary,
                  child: style == PosterStyle.report
                      ? BoardReport(
                          state: s,
                          board: widget.board,
                          now: widget.scope.clock(),
                          fields: fields && hasFields,
                        )
                      : BoardPoster(
                          state: s,
                          board: widget.board,
                          style: style,
                          now: widget.scope.clock(),
                          fields: fields && hasFields,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const ProBadge(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(
                                context,
                                'Saves with Pro. Plain without custom fields '
                                    'stays free.',
                                'Lưu được khi có Pro. Đơn giản không kèm trường '
                                    'tuỳ chỉnh vẫn miễn phí.',
                              ),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('export-pdf'),
                          onPressed: busy ? null : () => _save(pdf: true),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(tr(context, 'Save PDF', 'Lưu PDF')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('export-png'),
                          onPressed: busy ? null : () => _save(pdf: false),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(tr(context, 'Save picture', 'Lưu ảnh')),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    key: const Key('export-data'),
                    onPressed: () => widget.scope.run(
                      context,
                      () => exportBoards(context, widget.scope, widget.board),
                    ),
                    child: Text(
                      tr(
                        context,
                        'Other formats (CSV, Markdown, ICS, backup)',
                        'Định dạng khác (CSV, Markdown, ICS, sao lưu)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The board drawn for a picture: its title, categories with their
/// progress, and every column's cards. Fixed light colours, so a saved
/// picture looks the same whatever the device theme.
class BoardPoster extends StatelessWidget {
  final BoardsState state;
  final String board;
  final PosterStyle style;
  final DateTime now;
  final bool fields;
  const BoardPoster({
    super.key,
    required this.state,
    required this.board,
    required this.style,
    required this.now,
    this.fields = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = state;
    final b = s.get('boards', board);
    final columns = columnsOf(s, board);
    final print = style == PosterStyle.print,
        poster = style == PosterStyle.poster;
    const ink = Color(0xFF231A21), muted = Color(0xFF62575F);
    final page = print
        ? Colors.white
        : (poster ? const Color(0xFFF3EFEE) : Colors.white);
    final column = print ? Colors.white : const Color(0xFFEAE4E3);
    final width = (columns.length * 280 + (columns.length - 1) * 16 + 64)
        .clamp(720, 2400)
        .toDouble();
    final light = Theme.of(
      context,
    ).copyWith(brightness: Brightness.light, extensions: [BoardsPalette.light]);
    final sum = boardSummary(s, board, now: now);
    final title = Text(
      b.str('title'),
      style: TextStyle(
        fontFamily: handyFontFamily('PlusJakartaSans'),
        fontSize: poster ? 44 : 30,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: ink,
      ),
    );
    final figures = Text(
      tr(
        context,
        '${sum.cards} cards · ${sum.done} done',
        '${sum.cards} thẻ · ${sum.done} xong',
      ),
      style: TextStyle(
        fontSize: 16,
        color: poster ? Colors.white.withValues(alpha: .9) : muted,
      ),
    );
    return Theme(
      data: light,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: handyFontFamily('PlusJakartaSans'),
          color: ink,
          fontSize: 15,
        ),
        child: Container(
          width: width,
          color: page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (poster) SizedBox(height: 200, child: boardCover(b)),
              Padding(
                padding: EdgeInsets.fromLTRB(32, poster ? 24 : 28, 32, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 4), figures],
                ),
              ),
              if (categoryProgress(s, board).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      for (final c in categoryProgress(s, board))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: categoryHue(context, c.category).mark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${categoryName(context, c.category)}  ${c.done}/${c.total}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: column,
                            borderRadius: BorderRadius.circular(print ? 6 : 16),
                            border: print
                                ? Border.all(color: const Color(0xFF9A9095))
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
                                child: Text(
                                  '${columns[i].str('title')}  ${cardsIn(s, columns[i].id).length}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              for (final card in cardsIn(
                                s,
                                columns[i].id,
                              ).take(30))
                                _PosterCard(
                                  state: s,
                                  card: card,
                                  style: style,
                                  done: columns[i].flag('done'),
                                  now: now,
                                  fields: fields,
                                ),
                              if (cardsIn(s, columns[i].id).length > 30)
                                Text(
                                  tr(
                                    context,
                                    '+${cardsIn(s, columns[i].id).length - 30} more',
                                    '+${cardsIn(s, columns[i].id).length - 30} thẻ nữa',
                                  ),
                                  style: const TextStyle(color: muted),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: Text(
                  'Handy Boards',
                  style: TextStyle(
                    fontSize: 12,
                    color: muted.withValues(alpha: .8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  final BoardsState state;
  final BoardRecord card;
  final PosterStyle style;
  final bool done;
  final DateTime now;
  final bool fields;
  const _PosterCard({
    required this.state,
    required this.card,
    required this.style,
    required this.done,
    required this.now,
    this.fields = false,
  });
  @override
  Widget build(BuildContext context) {
    final print = style == PosterStyle.print;
    final category = state.maybe(
      'categories',
      card.data['category'] as String?,
    );
    final progress = subtaskProgress(state, card.id);
    final due = dueDay(card);
    final cover = style == PosterStyle.poster
        ? cardCover(context, state, card)
        : null;
    const muted = Color(0xFF62575F);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(print ? 4 : 12),
        border: print ? Border.all(color: const Color(0xFFCBC1C3)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cover != null) SizedBox(height: 44, child: cover),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (print) ...[
                      Icon(
                        done
                            ? Icons.check_box_outlined
                            : Icons.check_box_outline_blank,
                        size: 18,
                        color: muted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        card.str('title'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: done && !print
                              ? TextDecoration.lineThrough
                              : null,
                          color: done && !print ? muted : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (category != null || progress.total > 0 || due != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (category != null) CategoryChip(category),
                      if (progress.total > 0)
                        Text(
                          '${progress.done}/${progress.total}',
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                      if (due != null && !done)
                        Text(
                          dueLabel(context, due, now),
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                    ],
                  ),
                ],
                if (fields)
                  for (final line in cardFieldLines(
                    state,
                    card,
                    vi: Localizations.localeOf(context).languageCode == 'vi',
                  ))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        line,
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                if (print)
                  for (final c in subtasksOf(state, card.id).take(6))
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            c.flag('done')
                                ? Icons.check_box_outlined
                                : Icons.check_box_outline_blank,
                            size: 15,
                            color: muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              c.str('title'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
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
