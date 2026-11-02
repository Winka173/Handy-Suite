part of '../handy_card_engine.dart';

String _html(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// A self-contained profile page: one HTML file with no scripts, no
/// external requests and no trackers. Every value is escaped; links are
/// only tel:, mailto: and https: built by the checks above; the contact
/// card downloads from a data: URL. [cardPng] (the rendered front) is
/// embedded when given. Opening it from a phone needs the file to be
/// hosted by the person; a QR code cannot point at a local file.
String profileHtml(
  CardProfile p, {
  Uint8List? cardPng,
  Uint8List? photo,
  String photoMime = 'image/jpeg',
  String accent = '1450F5',
  String lang = 'vi',
}) {
  final vcf = base64Encode(utf8.encode(vcardFor(p, version: '3.0')));
  final name = p.displayName.trim().isEmpty ? p.organization : p.displayName;
  final rows = StringBuffer();
  void row(String label, String text, String? href) {
    if (text.trim().isEmpty) return;
    final value = href == null
        ? _html(text)
        : '<a href="${_html(href)}" rel="noopener noreferrer">${_html(text)}</a>';
    rows.write(
      '<li><span class="k">${_html(label)}</span><span class="v">$value</span></li>',
    );
  }

  final vi = lang == 'vi';
  for (final t in p.phones.where((v) => !v.private))
    row(
      t.label.isEmpty ? (vi ? 'Điện thoại' : 'Phone') : t.label,
      t.value,
      telUri(t.value),
    );
  for (final e in p.emails.where((v) => !v.private))
    row(
      e.label.isEmpty ? 'Email' : e.label,
      e.value,
      isEmail(e.value) ? 'mailto:${e.value.trim()}' : null,
    );
  for (final w in p.websites.where((v) => !v.private))
    row(w.label.isEmpty ? 'Web' : w.label, w.value, safeHttpsUrl(w.value));
  for (final s in p.socials.where((v) => !v.private))
    row(
      s.label.isEmpty ? (vi ? 'Mạng xã hội' : 'Social') : s.label,
      s.value,
      safeHttpsUrl(s.value),
    );
  for (final a in p.addresses.where((v) => !v.private))
    row(
      a.label.isEmpty ? (vi ? 'Địa chỉ' : 'Address') : a.label,
      a.value,
      null,
    );
  for (final c in p.custom.where((v) => !v.private))
    row(c.label, c.value, null);
  final hue = RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(accent) ? accent : '1450F5';
  return '''<!doctype html>
<html lang="${vi ? 'vi' : 'en'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
<meta name="referrer" content="no-referrer">
<title>${_html(name)}</title>
<style>
:root{--ink:#111;--muted:#5f6670;--ground:#f2f4f7;--card:#fff;--hue:#$hue}
@media (prefers-color-scheme:dark){:root{--ink:#f2f2f2;--muted:#a7adb5;--ground:#0f1113;--card:#181a1d}}
*{box-sizing:border-box}body{margin:0;background:var(--ground);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:560px;margin:0 auto;padding:32px 16px 48px}
.card{width:100%;border-radius:8px;display:block;margin:0 0 24px}
.photo{width:88px;height:88px;border-radius:50%;object-fit:cover;display:block;margin:0 0 16px}
h1{font-size:28px;line-height:1.2;margin:0}p.role{margin:4px 0 0;color:var(--muted)}
p.bio{margin:16px 0 0}ul{list-style:none;padding:0;margin:24px 0 0;background:var(--card);border-radius:8px}
li{display:flex;gap:16px;justify-content:space-between;padding:12px 16px;border-top:1px solid rgba(127,127,127,.18)}li:first-child{border-top:0}
.k{color:var(--muted);flex:none}.v{text-align:right;overflow-wrap:anywhere}a{color:var(--hue)}
.save{display:inline-block;margin:24px 0 0;padding:12px 18px;border-radius:6px;background:var(--ink);color:var(--ground);text-decoration:none;font-weight:600}
</style>
</head>
<body>
<main>
${cardPng == null ? '' : '<img class="card" alt="${_html(vi ? 'Danh thiếp của $name' : 'Card of $name')}" src="data:image/png;base64,${base64Encode(cardPng)}">'}
${photo == null ? '' : '<img class="photo" alt="" src="data:${_html(photoMime)};base64,${base64Encode(photo)}">'}
<h1>${_html(name)}</h1>
${[p.role, p.organization].where((s) => s.trim().isNotEmpty).isEmpty ? '' : '<p class="role">${_html([p.role, p.organization].where((s) => s.trim().isNotEmpty).join(' · '))}</p>'}
${p.bio.trim().isEmpty ? '' : '<p class="bio">${_html(p.bio.trim())}</p>'}
${rows.isEmpty ? '' : '<ul>$rows</ul>'}
<a class="save" href="data:text/vcard;charset=utf-8;base64,$vcf" download="${_html(_safeName(name))}.vcf">${vi ? 'Lưu danh bạ' : 'Save contact'}</a>
</main>
</body>
</html>
''';
}

/// A file name from free text: letters, digits, dash; never empty.
String _safeName(String s) {
  final clean = s
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .trim();
  return clean.isEmpty
      ? 'contact'
      : (clean.length > 60 ? clean.substring(0, 60) : clean);
}

String safeCardFileName(String s) => _safeName(s);

/// A conservative email signature: a table with inline styles and plain
/// links, which most mail clients keep. Images are left out because many
/// clients block embedded ones.
String emailSignatureHtml(CardProfile p, {String accent = '1450F5'}) {
  final hue = RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(accent) ? accent : '1450F5';
  final lines = <String>[];
  for (final t in p.phones.where((v) => !v.private)) {
    final href = telUri(t.value);
    if (href != null)
      lines.add(
        '<a href="${_html(href)}" style="color:#$hue;text-decoration:none">${_html(t.value)}</a>',
      );
  }
  for (final e in p.emails.where((v) => !v.private && isEmail(v.value))) {
    lines.add(
      '<a href="mailto:${_html(e.value.trim())}" style="color:#$hue;text-decoration:none">${_html(e.value.trim())}</a>',
    );
  }
  for (final w in p.websites.where((v) => !v.private)) {
    final href = safeHttpsUrl(w.value);
    if (href != null)
      lines.add(
        '<a href="${_html(href)}" style="color:#$hue;text-decoration:none">${_html(w.value.trim())}</a>',
      );
  }
  final sub = [
    p.role,
    p.organization,
  ].where((s) => s.trim().isNotEmpty).join(' · ');
  return '<table cellpadding="0" cellspacing="0" border="0" style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:1.5;color:#111111">'
      '<tr><td style="font-size:15px;font-weight:bold">${_html(p.displayName)}</td></tr>'
      '${sub.isEmpty ? '' : '<tr><td style="color:#5f6670">${_html(sub)}</td></tr>'}'
      '${lines.isEmpty ? '' : '<tr><td>${lines.join(' &nbsp;|&nbsp; ')}</td></tr>'}'
      '</table>';
}
