import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'export_doc.dart';

/// The faces a PDF embeds: Geist for text, Newsreader for titles. Both
/// carry Vietnamese and are licensed (OFL) for embedding.
class ExportFonts {
  final pw.Font sans, sansBold, serif, serifBold;
  const ExportFonts(this.sans, this.sansBold, this.serif, this.serifBold);
}

Future<ExportFonts> loadExportFonts() async {
  Future<pw.Font> f(String path) async =>
      pw.Font.ttf(await rootBundle.load(path));
  return ExportFonts(
    await f('packages/handy_ui/fonts/Geist-Regular.ttf'),
    await f('packages/handy_ui/fonts/Geist-Bold.ttf'),
    await f('fonts/Newsreader-Regular.ttf'),
    await f('fonts/Newsreader-SemiBold.ttf'),
  );
}

/// A real multi-page PDF of [items] in template [t]: embedded fonts,
/// clickable links, page numbers, pictures kept at their proportions.
Future<Uint8List> renderExportPdf(
  ExportTemplate t,
  ExportOptions o,
  List<ExportItem> items,
  ExportFonts fonts,
) async {
  PdfColor c(int v) => PdfColor.fromInt(v);
  final ink = c(t.ink), muted = c(t.muted), accent = c(t.accent);
  final head = t.serifTitles ? fonts.serifBold : fonts.sansBold;
  final doc = pw.Document(
    title: o.title,
    theme: pw.ThemeData.withFont(base: fonts.sans, bold: fonts.sansBold),
  );
  pw.ImageProvider? image(ExportItem i) {
    if (!o.images || !t.usesImages || i.image == null) return null;
    try {
      return pw.MemoryImage(i.image!);
    } catch (_) {
      return null;
    }
  }

  pw.Widget picture(ExportItem i, double height, {double radius = 4}) {
    final img = image(i);
    if (img == null) return pw.SizedBox();
    return pw.ClipRRect(
      horizontalRadius: radius,
      verticalRadius: radius,
      child: pw.SizedBox(
        height: height,
        width: double.infinity,
        child: pw.Image(img, fit: pw.BoxFit.cover),
      ),
    );
  }

  pw.Widget title(ExportItem i, double size) {
    final text = pw.Text(
      i.title,
      style: pw.TextStyle(
        font: head,
        fontSize: size,
        color: ink,
        lineSpacing: 1,
      ),
    );
    return i.url == null ? text : pw.UrlLink(destination: i.url!, child: text);
  }

  pw.Widget meta(ExportItem i) => pw.Text(
    [
      if (o.sources && i.source.isNotEmpty) i.source,
      if (o.dates) i.date,
    ].join(' · '),
    style: pw.TextStyle(fontSize: 9, color: muted),
  );
  List<pw.Widget> extra(ExportItem i) => [
    if (o.descriptions && i.description != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          i.description!,
          style: pw.TextStyle(fontSize: 10, color: ink),
        ),
      ),
    if (o.notes && i.note != null)
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(left: pw.BorderSide(color: accent, width: 2)),
        ),
        child: pw.Text(i.note!, style: pw.TextStyle(fontSize: 10, color: ink)),
      ),
  ];

  final format = o.letter ? PdfPageFormat.letter : PdfPageFormat.a4;
  final width = format.availableWidth - 2 * 40;
  List<pw.Widget> body() {
    switch (t.id) {
      case 'catalog' || 'wishlist':
        final w = (width - 16) / 2;
        return [
          pw.Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final i in items)
                pw.Container(
                  width: w,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColor.fromInt(0x1F000000),
                      width: .6,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      picture(i, w * .62, radius: 6),
                      pw.SizedBox(height: 6),
                      title(i, 12),
                      meta(i),
                      ...extra(i),
                      if (i.url != null && t.id == 'wishlist')
                        pw.UrlLink(
                          destination: i.url!,
                          child: pw.Text(
                            '→ ${i.source}',
                            style: pw.TextStyle(fontSize: 9, color: accent),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ];
      case 'travel' || 'recipes':
        return [
          for (final i in items)
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 22),
              child: t.id == 'recipes'
                  ? pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (image(i) != null)
                          pw.SizedBox(
                            width: width * .42,
                            child: picture(i, width * .42 * .8),
                          ),
                        if (image(i) != null) pw.SizedBox(width: 14),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [title(i, 18), meta(i), ...extra(i)],
                          ),
                        ),
                      ],
                    )
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        picture(i, 230),
                        pw.SizedBox(height: 8),
                        title(i, 18),
                        meta(i),
                        ...extra(i),
                      ],
                    ),
            ),
        ];
      case 'bibliography' || 'print':
        return [
          for (final (n, i) in items.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 24,
                    child: pw.Text(
                      '${n + 1}.',
                      style: pw.TextStyle(fontSize: 10, color: muted),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          i.title,
                          style: pw.TextStyle(
                            font: fonts.sansBold,
                            fontSize: 11,
                            color: ink,
                          ),
                        ),
                        meta(i),
                        if (i.url != null)
                          pw.UrlLink(
                            destination: i.url!,
                            child: pw.Text(
                              i.url!,
                              style: pw.TextStyle(fontSize: 9, color: accent),
                            ),
                          ),
                        ...extra(i),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ];
      case 'magazine':
        final lead = items.isEmpty ? null : items.first;
        final w = (width - 20) / 2;
        return [
          if (lead != null) ...[
            picture(lead, 260, radius: 0),
            pw.SizedBox(height: 10),
            title(lead, 26),
            meta(lead),
            ...extra(lead),
            pw.SizedBox(height: 18),
          ],
          pw.Wrap(
            spacing: 20,
            runSpacing: 18,
            children: [
              for (final i in items.skip(1))
                pw.SizedBox(
                  width: w,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      picture(i, w * .6),
                      pw.SizedBox(height: 6),
                      title(i, 14),
                      meta(i),
                      ...extra(i),
                    ],
                  ),
                ),
            ],
          ),
        ];
      default: // moodboard
        final unit = (width - 12) / 3;
        return [
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (n, i) in items.indexed)
                pw.SizedBox(
                  width: n % 5 == 0 ? unit * 2 + 6 : unit,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      image(i) == null
                          ? pw.Container(
                              height: n % 5 == 0 ? unit * 1.2 : unit,
                              color: PdfColor.fromInt(0xFFE8E2D6),
                              alignment: pw.Alignment.center,
                              child: pw.Text(
                                i.source,
                                style: pw.TextStyle(fontSize: 9, color: muted),
                              ),
                            )
                          : picture(
                              i,
                              n % 5 == 0 ? unit * 1.2 : unit,
                              radius: 4,
                            ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        i.title,
                        maxLines: 2,
                        style: pw.TextStyle(fontSize: 8.5, color: ink),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ];
    }
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(40),
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: c(t.paper)),
        ),
      ),
      header: (context) => context.pageNumber == 1
          ? pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  o.title,
                  style: pw.TextStyle(font: head, fontSize: 30, color: ink),
                ),
                if (o.subtitle.isNotEmpty)
                  pw.Text(
                    o.subtitle,
                    style: pw.TextStyle(fontSize: 12, color: muted),
                  ),
                pw.SizedBox(height: 18),
              ],
            )
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                o.title,
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${context.pageNumber} / ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 9, color: muted),
        ),
      ),
      build: (context) => body(),
    ),
  );
  return doc.save();
}
