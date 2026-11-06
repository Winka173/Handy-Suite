import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_files/share.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import '../../collections/share_collection.dart';
import '../../design/theme.dart';
import '../../scope.dart';
import '../entitlements.dart';
import 'export_doc.dart';
import 'render_html.dart';
import 'render_pdf.dart';

/// Export Studio: a collection as a designed document. Choose a template
/// and format, set what to include, and see the real pages, built from
/// this collection on this device. Exporting needs Pro; previewing and
/// the free page share do not.
class ExportStudio extends StatefulWidget {
  final SaveScope scope;
  final String collectionId;

  /// Turns PDF bytes into page images (PDFium on devices); replaceable
  /// where no renderer exists, as in host tests.
  static Future<List<Uint8List>> Function(Uint8List pdf) rasterize = _pages;

  const ExportStudio({
    super.key,
    required this.scope,
    required this.collectionId,
  });
  @override
  State<ExportStudio> createState() => _ExportStudioState();
}

class _ExportStudioState extends State<ExportStudio> {
  int at = 0;
  bool pdf = true;
  late ExportOptions options;
  List<ExportItem>? items;
  Future<List<Uint8List>>? pages;
  ExportFonts? fonts;
  bool busy = false;

  SaveScope get scope => widget.scope;
  ExportTemplate get template => exportTemplates[at];

  @override
  void initState() {
    super.initState();
    final col = scope.library.collections
        .where((c) => c.id == widget.collectionId)
        .firstOrNull;
    options = ExportOptions(title: col?.name ?? 'Handy Bookmark');
    _load();
  }

  Future<void> _load() async {
    final rows = [
      for (final b in scope.library.bookmarks)
        if (b.collectionId == widget.collectionId && !b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final loaded = await exportItems(scope.c, rows);
    final f = await loadExportFonts();
    if (!mounted) return;
    setState(() {
      items = loaded;
      fonts = f;
    });
    _render();
  }

  /// Rebuilds the real PDF and renders its pages for the preview.
  void _render() {
    final list = items, f = fonts;
    if (list == null || f == null) return;
    final next = () async {
      final bytes = await renderExportPdf(template, options, list, f);
      return ExportStudio.rasterize(bytes);
    }();
    // A render replaced before it finishes has no one listening; its
    // failure is not an error of the screen.
    next.ignore();
    setState(() {
      pages = next;
    });
  }

  void _set(ExportOptions o) {
    options = o;
    _render();
  }

  Future<void> _export() async {
    if (!await requirePro(context, ProFeature.premiumExport) || !mounted)
      return;
    final list = items, f = fonts;
    if (list == null || f == null) return;
    setState(() => busy = true);
    try {
      final name = '${options.title}.${pdf ? 'pdf' : 'html'}';
      final lang = Localizations.localeOf(context).languageCode;
      final serif = pdf
          ? null
          : (await rootBundle.load(
              'fonts/Newsreader-SemiBold.ttf',
            )).buffer.asUint8List();
      final bytes = pdf
          ? await renderExportPdf(template, options, list, f)
          : Uint8List.fromList(
              utf8.encode(
                renderExportHtml(
                  template,
                  options,
                  list,
                  lang: lang,
                  serifFont: serif,
                ),
              ),
            );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box == null
          ? const Rect.fromLTWH(0, 0, 10, 10)
          : box.localToGlobal(Offset.zero) & box.size;
      final result = await const LocalShare().bytes(
        name,
        bytes,
        mimeType: pdf ? 'application/pdf' : 'text/html',
        origin: origin,
      );
      if (mounted && result == LocalShareResult.selected)
        showHandyMessage(context, tr(context, 'Exported.', 'Đã xuất.'));
    } on UnsupportedError {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Sharing a file is not available on this device.',
            'Thiết bị này chưa chia sẻ được tệp.',
          ),
        );
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not build the file.', 'Chưa tạo được tệp.'),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final pro = hasPro(context);
    Widget toggle(
      String key,
      String label,
      bool value,
      ExportOptions Function(bool) next,
    ) => SwitchListTile(
      key: Key(key),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: (v) => _set(next(v)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Design an export', 'Thiết kế bản xuất')),
      ),
      body: ListView(
        key: const Key('export-studio'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: exportTemplates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t = exportTemplates[i];
                final on = i == at;
                return SizedBox(
                  width: 168,
                  child: Material(
                    key: Key('export-${t.id}'),
                    color: on ? p.tint : p.surface,
                    borderRadius: BorderRadius.circular(BookmarkRadii.item),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(BookmarkRadii.item),
                      onTap: () {
                        at = i;
                        _render();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Color(t.accent),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    tr(context, t.en, t.vi),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(context, t.tagEn, t.tagVi),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            key: const Key('export-format'),
            segments: const [
              ButtonSegment(value: true, label: Text('PDF')),
              ButtonSegment(value: false, label: Text('HTML')),
            ],
            selected: {pdf},
            onSelectionChanged: (s) => setState(() => pdf = s.first),
          ),
          const SizedBox(height: 8),
          toggle(
            'export-images',
            tr(context, 'Pictures', 'Ảnh'),
            options.images,
            (v) => options.copyWith(images: v),
          ),
          toggle(
            'export-descriptions',
            tr(context, 'Descriptions', 'Mô tả'),
            options.descriptions,
            (v) => options.copyWith(descriptions: v),
          ),
          toggle(
            'export-sources',
            tr(context, 'Sources', 'Nguồn'),
            options.sources,
            (v) => options.copyWith(sources: v),
          ),
          toggle(
            'export-dates',
            tr(context, 'Dates saved', 'Ngày lưu'),
            options.dates,
            (v) => options.copyWith(dates: v),
          ),
          if (template.showsNotes)
            toggle(
              'export-notes',
              tr(context, 'My notes (private)', 'Ghi chú của tôi (riêng tư)'),
              options.notes,
              (v) => options.copyWith(notes: v),
            ),
          if (pdf)
            toggle(
              'export-letter',
              tr(
                context,
                'US Letter paper (otherwise A4)',
                'Khổ US Letter (không thì A4)',
              ),
              options.letter,
              (v) => options.copyWith(letter: v),
            ),
          const SizedBox(height: 12),
          Text(
            pdf
                ? tr(
                    context,
                    'Preview: the real pages of the PDF',
                    'Xem trước: các trang thật của PDF',
                  )
                : tr(
                    context,
                    'Preview: the same design as printed pages; the web page shows it as one scrolling page.',
                    'Xem trước: cùng thiết kế ở dạng trang in; trang web hiển thị thành một trang cuộn.',
                  ),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (items != null && items!.isEmpty)
            Text(
              tr(
                context,
                'This collection is empty.',
                'Bộ sưu tập này đang trống.',
              ),
            )
          else
            FutureBuilder<List<Uint8List>>(
              future: pages,
              builder: (context, snap) {
                if (snap.hasError)
                  return Text(
                    tr(
                      context,
                      'The page preview needs this device\'s PDF renderer; the export itself still works.',
                      'Xem trước trang cần trình dựng PDF của thiết bị; việc xuất vẫn chạy.',
                    ),
                    key: const Key('export-preview-unavailable'),
                  );
                if (snap.data == null)
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                return Column(
                  children: [
                    for (final page in snap.data!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: p.line),
                          ),
                          child: Image.memory(page, gaplessPlayback: true),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('export-quick'),
                  onPressed: () =>
                      scope.shareCollection(context, widget.collectionId),
                  child: Text(
                    tr(
                      context,
                      'Quick share (free)',
                      'Chia sẻ nhanh (miễn phí)',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('export-go'),
                  onPressed: busy || items == null ? null : _export,
                  child: Text(
                    pro
                        ? tr(
                            context,
                            'Export ${pdf ? 'PDF' : 'HTML'}',
                            'Xuất ${pdf ? 'PDF' : 'HTML'}',
                          )
                        : tr(context, 'Export with Pro', 'Xuất với Pro'),
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

/// The first six pages of [pdf] as images.
Future<List<Uint8List>> _pages(Uint8List pdf) async {
  final doc = await LocalPdf.open(pdf);
  try {
    return [
      for (var i = 0; i < doc.pages.length && i < 6; i++)
        await doc.renderPng(i, maxEdge: 1100),
    ];
  } finally {
    await doc.close();
  }
}
