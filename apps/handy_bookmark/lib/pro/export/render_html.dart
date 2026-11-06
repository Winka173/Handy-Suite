import 'dart:convert';
import 'dart:typed_data';
import 'export_doc.dart';

/// A self-contained web page: inline styles, pictures inlined, no script,
/// no remote fonts or files, every text escaped, only web links linked.
String renderExportHtml(
  ExportTemplate t,
  ExportOptions o,
  List<ExportItem> items, {
  String lang = 'en',

  /// The title face (Newsreader, OFL) to embed, so titles read the same
  /// everywhere, Vietnamese included; without it, a Vietnamese-safe stack.
  Uint8List? serifFont,
}) {
  final esc = const HtmlEscape();
  String hex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  final serif = serifFont == null
      ? "'Noto Serif', 'Times New Roman', serif"
      : "'Export Serif', 'Noto Serif', 'Times New Roman', serif";
  final face = serifFont == null || !t.serifTitles
      ? ''
      : "@font-face{font-family:'Export Serif';font-weight:600;src:url(data:font/ttf;base64,${base64Encode(serifFont)}) format('truetype')}";
  const sans =
      "system-ui, -apple-system, 'Segoe UI', Roboto, Arial, sans-serif";
  final head = t.serifTitles ? serif : sans;
  String img(Uint8List? bytes, {String cls = ''}) {
    if (!o.images || !t.usesImages || bytes == null) return '';
    final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return '<img class="$cls" alt="" src="data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}">';
  }

  String link(ExportItem i, String text) => i.url == null
      ? esc.convert(text)
      : '<a href="${esc.convert(i.url!)}" rel="noopener noreferrer">${esc.convert(text)}</a>';
  String meta(ExportItem i) => [
    if (o.sources && i.source.isNotEmpty) esc.convert(i.source),
    if (o.dates) esc.convert(i.date),
  ].join(' · ');
  String extra(ExportItem i) => [
    if (o.descriptions && i.description != null)
      '<p class="desc">${esc.convert(i.description!)}</p>',
    if (o.notes && i.note != null)
      '<p class="note">${esc.convert(i.note!)}</p>',
  ].join();

  final body = StringBuffer();
  switch (t.id) {
    case 'catalog' || 'wishlist':
      body.write('<div class="grid">');
      for (final i in items) {
        body.write(
          '<article class="card">${img(i.image, cls: 'thumb')}<div class="pad">'
          '<h2>${link(i, i.title)}</h2><p class="meta">${meta(i)}</p>${extra(i)}',
        );
        if (i.tags.isNotEmpty)
          body.write(
            '<p class="tags">${i.tags.map((x) => '#${esc.convert(x)}').join(' ')}</p>',
          );
        body.write('</div></article>');
      }
      body.write('</div>');
    case 'travel' || 'recipes':
      final lead = items.isEmpty ? null : items.first;
      final hero = t.id == 'travel' && lead != null;
      if (hero) body.write(img(lead.image, cls: 'hero'));
      for (final i in items) {
        // The cover already shows the first place's picture.
        final picture = hero && identical(i, lead)
            ? ''
            : img(i.image, cls: 'big');
        body.write(
          '<section class="entry">$picture'
          '<h2>${link(i, i.title)}</h2><p class="meta">${meta(i)}</p>${extra(i)}</section>',
        );
      }
    case 'bibliography' || 'print':
      body.write('<ol class="refs">');
      for (final i in items) {
        body.write(
          '<li><span class="t">${esc.convert(i.title)}.</span> '
          '<span class="meta">${meta(i)}</span>',
        );
        if (i.url != null)
          body.write(
            '<br><a class="url" href="${esc.convert(i.url!)}">${esc.convert(i.url!)}</a>',
          );
        body.write(extra(i));
        body.write('</li>');
      }
      body.write('</ol>');
    case 'magazine':
      final lead = items.isEmpty ? null : items.first;
      if (lead != null)
        body.write(
          '<section class="cover">${img(lead.image, cls: 'hero')}<h2 class="lead">${link(lead, lead.title)}</h2>'
          '<p class="meta">${meta(lead)}</p>${extra(lead)}</section>',
        );
      body.write('<div class="cols">');
      for (final i in items.skip(1)) {
        body.write(
          '<article>${img(i.image, cls: 'thumb')}<h3>${link(i, i.title)}</h3>'
          '<p class="meta">${meta(i)}</p>${extra(i)}</article>',
        );
      }
      body.write('</div>');
    case 'moodboard':
      body.write('<div class="quilt">');
      for (final (n, i) in items.indexed) {
        body.write(
          '<figure class="${n % 5 == 0 ? 'wide' : ''}">${img(i.image)}'
          '<figcaption>${link(i, i.title)}</figcaption></figure>',
        );
      }
      body.write('</div>');
  }

  final css =
      '''
*{box-sizing:border-box}body{margin:0;background:${hex(t.paper)};color:${hex(t.ink)};font:16px/1.55 $sans}
main{max-width:920px;margin:0 auto;padding:40px 24px 64px}
header h1{font:600 40px/1.1 $head;margin:0 0 8px;letter-spacing:-.5px}header p{color:${hex(t.muted)};margin:0 0 32px}
a{color:${hex(t.accent)};text-decoration:none}a:hover{text-decoration:underline}
h2,h3{font-family:$head;margin:0 0 4px;line-height:1.25}h2{font-size:22px}h3{font-size:18px}
.meta{color:${hex(t.muted)};font-size:13px;margin:0 0 8px}.desc{margin:0 0 8px}.note{margin:0 0 8px;padding:8px 12px;border-left:3px solid ${hex(t.accent)};background:rgba(0,0,0,.03)}
.tags{color:${hex(t.muted)};font-size:13px}img{display:block;width:100%;object-fit:cover}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:18px}.card{background:${hex(t.paper)};border:1px solid rgba(0,0,0,.08);border-radius:14px;overflow:hidden}.card .thumb{aspect-ratio:4/3}.pad{padding:12px 14px}
.hero{aspect-ratio:16/9;border-radius:${t.id == 'travel' ? 4 : 0}px;margin-bottom:28px}.entry{margin:0 0 40px}.entry .big{aspect-ratio:3/2;border-radius:6px;margin-bottom:12px}
.refs{padding-left:24px}.refs li{margin:0 0 14px}.refs .t{font-weight:600}.url{font-size:13px;word-break:break-all}
.cover .lead{font-size:34px}.cols{column-count:2;column-gap:28px;margin-top:28px}.cols article{break-inside:avoid;margin:0 0 24px}.cols .thumb{aspect-ratio:3/2;margin-bottom:8px}
.quilt{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.quilt figure{margin:0}.quilt .wide{grid-column:span 2;grid-row:span 2}.quilt img{aspect-ratio:1;border-radius:6px;height:100%}.quilt figcaption{font-size:12px;margin-top:4px}
@media (max-width:600px){.cols{column-count:1}header h1{font-size:30px}}
@media print{main{padding:0}.card{break-inside:avoid}}
''';
  return '<!doctype html><html lang="$lang"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1">'
      '<title>${esc.convert(o.title)}</title><style>$face$css</style></head><body><main>'
      '<header><h1>${esc.convert(o.title)}</h1>'
      '${o.subtitle.isEmpty ? '' : '<p>${esc.convert(o.subtitle)}</p>'}</header>'
      '$body</main></body></html>';
}
