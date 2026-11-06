import 'dart:convert';
import 'dart:typed_data';
import 'models.dart';

/// A collection as one self-contained HTML page to send to someone: its
/// name, how many things it holds, and each one with its picture, title,
/// source and (when asked) the person's notes. Links open the original;
/// pictures are embedded, so the page needs no network and no account.
///
/// [pictures] maps item ids to JPEG bytes that are already stripped of
/// camera metadata (the app passes its re-encoded previews). Nothing else
/// from the library leaves: no tags, reminders, read state or other
/// collections. Sub-collections are included as sections.
String collectionPage(
  SaveLibrary library,
  String collectionId, {
  Map<String, Uint8List> pictures = const {},
  bool notes = false,
  bool vietnamese = false,
  required DateTime now,
}) {
  final byId = {for (final c in library.collections) c.id: c};
  final root = byId[collectionId];
  if (root == null) throw const FormatException('No such collection');
  String esc(String s) => const HtmlEscape(HtmlEscapeMode.element).convert(s);
  String attr(String s) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert(s);
  final sections = <(SaveCollection, int)>[];
  void walk(SaveCollection c, int depth) {
    sections.add((c, depth));
    final children =
        library.collections.where((x) => x.parentId == c.id).toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    if (depth < 8) {
      for (final x in children) {
        walk(x, depth + 1);
      }
    }
  }

  walk(root, 0);
  final items = {
    for (final (c, _) in sections)
      c.id: [
        for (final b in library.bookmarks)
          if (b.collectionId == c.id && !b.isArchived) b,
      ]..sort((a, b) => b.savedAt.compareTo(a.savedAt)),
  };
  final total = items.values.fold(0, (n, l) => n + l.length);
  final date =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final out = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="${vietnamese ? 'vi' : 'en'}"><head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<meta name="referrer" content="no-referrer">')
    ..writeln('<title>${esc(root.name)}</title>')
    ..writeln('<style>$_style</style>')
    ..writeln('</head><body><main>')
    ..writeln('<header><h1>${esc(root.name)}</h1>')
    ..writeln(
      '<p class="meta">${vietnamese ? '$total mục · chia sẻ ngày $date từ Handy Bookmark' : '$total ${total == 1 ? 'item' : 'items'} · shared $date from Handy Bookmark'}</p>',
    );
  if (root.description.trim().isNotEmpty)
    out.writeln('<p>${esc(root.description)}</p>');
  out.writeln('</header>');
  for (final (c, depth) in sections) {
    final list = items[c.id]!;
    if (depth > 0) {
      if (list.isEmpty) continue;
      out.writeln('<h2>${esc(c.name)}</h2>');
    }
    out.writeln('<ul>');
    for (final b in list) {
      final picture = pictures[b.id];
      final title = b.title.trim().isNotEmpty
          ? b.title
          : (b.hasUrl ? b.sourceDomain : (vietnamese ? 'Ảnh' : 'Picture'));
      out.write('<li>');
      if (picture != null)
        out.write(
          '<img alt="" loading="lazy" src="data:image/jpeg;base64,${base64Encode(picture)}">',
        );
      out.write('<div>');
      out.write(
        b.hasUrl
            ? '<a href="${attr(b.originalUrl)}" rel="noopener noreferrer">${esc(title)}</a>'
            : '<strong>${esc(title)}</strong>',
      );
      final source = b.hasUrl
          ? b.sourceDomain.replaceFirst(RegExp(r'^www\.'), '')
          : (vietnamese ? 'Ảnh' : 'Picture');
      out.write('<span class="meta">${esc(source)}</span>');
      final about = (b.description ?? '').trim();
      if (about.isNotEmpty) out.write('<p>${esc(about)}</p>');
      if (notes && b.note.trim().isNotEmpty)
        out.write('<p class="note">${esc(b.note)}</p>');
      out.writeln('</div></li>');
    }
    out.writeln('</ul>');
  }
  out.writeln('</main></body></html>');
  return out.toString();
}

const _style = '''
:root{--ground:#FAF8F3;--ink:#111;--muted:#5f5f5f;--rule:#111;--card:#fff;--line:#e6e2d8;--accent:#0E7490}
@media (prefers-color-scheme:dark){:root{--ground:#111;--ink:#f2f2f2;--muted:#b4b4b4;--rule:#f2f2f2;--card:#1a1a1a;--line:#2e2e2e;--accent:#5fb7cc}}
*{box-sizing:border-box}body{margin:0;background:var(--ground);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:760px;margin:0 auto;padding:32px 16px 64px}
h1,h2{font-family:Newsreader,Georgia,"Times New Roman",serif;font-weight:500;margin:0}
h1{font-size:36px;line-height:1.15;border-bottom:2px solid var(--rule);padding-bottom:8px}
h2{font-size:22px;margin-top:32px;border-bottom:1px solid var(--rule);padding-bottom:4px}
.meta{color:var(--muted);font-size:14px;display:block}
ul{list-style:none;margin:16px 0 0;padding:0}
li{display:flex;gap:12px;padding:12px 0;border-bottom:1px solid var(--line)}
li img{width:96px;height:72px;object-fit:cover;border-radius:2px;flex:none;background:var(--card)}
li a,li strong{font-family:Newsreader,Georgia,serif;font-size:18px;color:var(--ink);text-decoration:none}
li a:hover,li a:focus{color:var(--accent);text-decoration:underline}
li p{margin:4px 0 0}.note{color:var(--muted);font-style:italic}
@media (max-width:420px){li img{width:72px;height:54px}}
''';
