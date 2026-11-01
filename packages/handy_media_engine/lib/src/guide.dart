import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'images.dart';
import 'project.dart';

/// Already-flattened renderer output. Removes every ancillary PNG chunk;
/// this class cannot itself establish whether the caller applied the masks.
class GuideRaster {
  final String stepId;
  final int width, height;
  final Uint8List png;
  const GuideRaster._(this.stepId, this.width, this.height, this.png);
  factory GuideRaster(String stepId, Uint8List input) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$').hasMatch(stepId) ||
        input.length < 45 ||
        input.length > 8000000 ||
        input.take(8).join(',') != '137,80,78,71,13,10,26,10') {
      throw const FormatException(
        'Flattened guide images require PNG up to 8 MB',
      );
    }
    final raster = decodeBoundedImage(input);
    final output = BytesBuilder()..add(input.sublist(0, 8));
    final view = ByteData.sublistView(input);
    // The shared strict decoder has already verified ranges, CRCs and IEND.
    for (var at = 8; at < input.length;) {
      final end = at + 12 + view.getUint32(at);
      final type = ascii.decode(input.sublist(at + 4, at + 8));
      if (const {'IHDR', 'PLTE', 'tRNS', 'IDAT', 'IEND'}.contains(type)) {
        output.add(input.sublist(at, end));
      }
      at = end;
    }
    return GuideRaster._(
      stepId,
      raster.width,
      raster.height,
      output.takeBytes().asUnmodifiableView(),
    );
  }
}

CaptureProject _guide(CaptureProject input, List<GuideRaster> images) {
  final project = CaptureProject.parse(input.toJson());
  if (project.steps.isEmpty ||
      images.length != project.steps.length ||
      images.map((e) => e.stepId).toSet().length != images.length ||
      images.any((image) => !project.steps.any((s) => s.id == image.stepId))) {
    throw const FormatException(
      'Exactly one flattened image per guide step is required',
    );
  }
  if (images.fold<int>(0, (n, e) => n + e.png.length) > 18000000) {
    throw const FormatException('Guide image limit: 18 MB; split the guide');
  }
  return project;
}

String buildGuideHtml(
  CaptureProject input,
  List<GuideRaster> images, {
  String locale = 'en',
}) {
  if (!{'en', 'vi'}.contains(locale))
    throw const FormatException('Unsupported guide language');
  final project = _guide(input, images), vi = locale == 'vi';
  const escape = HtmlEscape(HtmlEscapeMode.attribute);
  String e(String text) => escape.convert(text);
  final byId = {for (final image in images) image.stepId: image};
  final stepWord = vi ? 'Bước' : 'Step';
  String title(ProjectStep step, int index) =>
      step.title.isEmpty ? '$stepWord ${index + 1}' : step.title;
  final bug = project.kind != 'bug'
      ? ''
      : '<section>${[
          for (final key in ['environment', 'expected', 'actual', 'reproduction']) '<h2>${e(key[0].toUpperCase() + key.substring(1))}</h2><p>${e(project.bug[key]!)}</p>',
        ].join()}</section>';
  final toc =
      '<nav aria-label="${vi ? 'Các bước hướng dẫn' : 'Guide steps'}"><ol>${[for (var i = 0; i < project.steps.length; i++) '<li><a href="#snap-step-${i + 1}">${e(title(project.steps[i], i))}</a></li>'].join()}</ol></nav>';
  final sections = [
    for (var i = 0; i < project.steps.length; i++)
      '<section class="step" id="snap-step-${i + 1}" aria-labelledby="snap-heading-${i + 1}">'
          '<div class="progress"><input type="checkbox" id="snap-done-${i + 1}">'
          '<label for="snap-done-${i + 1}">${vi ? 'Đánh dấu đã hoàn thành' : 'Mark complete'}: $stepWord ${i + 1}</label></div>'
          '<h2 id="snap-heading-${i + 1}">${i + 1}. ${e(title(project.steps[i], i))}</h2>'
          '<img loading="lazy" alt="${e(title(project.steps[i], i))}" src="data:image/png;base64,${base64Encode(byId[project.steps[i].id]!.png)}">'
          '<p>${e(project.steps[i].body)}</p></section>',
  ].join();
  final heading = e(project.title.isEmpty ? 'Handy Media' : project.title);
  final html =
      '<!doctype html><html lang="$locale"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width">'
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src data:; style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'">'
      '<title>$heading</title><style>body{font-family:system-ui,sans-serif;max-width:960px;margin:24px auto;padding:0 20px;line-height:1.6;color:#172033;overflow-wrap:anywhere}h1,h2{line-height:1.25}p{white-space:pre-wrap}img{display:block;max-width:100%;height:auto;border:1px solid #dce2ed}.step{break-inside:avoid;margin:30px 0;scroll-margin-top:16px}.progress{display:flex;align-items:center;gap:10px}.progress input{width:24px;height:24px}.progress label{display:inline-flex;align-items:center;min-height:48px;padding:0 8px;cursor:pointer}.progress input:checked+label{font-weight:bold}a:focus-visible,input:focus-visible{outline:3px solid #2563eb;outline-offset:3px}.comparison{display:grid;grid-template-columns:1fr 1fr;gap:20px}@media(max-width:600px){.comparison{display:block}}@media print{body{margin:0;max-width:none}.step{page-break-inside:avoid}.progress,nav,.progress-note{display:none}img{max-height:780px;object-fit:contain}}</style></head>'
      '<body><h1>$heading</h1>$bug$toc<p class="progress-note">${vi ? 'Dấu hoàn thành chỉ ở trang này, không cập nhật project Media.' : 'Checkmarks stay on this page and do not update the Media project.'}</p>'
      '<main class="${project.kind == 'comparison' ? 'comparison' : 'guide'}">$sections</main></body></html>';
  if (utf8.encode(html).length > 30000000)
    throw const FormatException('Guide HTML exceeds 30 MB');
  return html;
}

/// A printable guide made only from flattened, metadata-stripped screenshots.
/// Text remains selectable; no source images, editable layers or active links.
Future<Uint8List> buildGuidePdf(
  CaptureProject input,
  List<GuideRaster> images, {
  required ByteData regularFont,
  required ByteData boldFont,
  String locale = 'en',
  CancellationToken? cancellation,
}) async {
  cancellation?.check();
  if (!{'en', 'vi'}.contains(locale))
    throw const FormatException('Unsupported guide language');
  final project = _guide(input, images);
  if (images.fold<int>(
        0,
        (pixels, image) => pixels + image.width * image.height,
      ) >
      32000000)
    throw const FormatException(
      'Guide PDF image limit: 32M pixels; split the guide',
    );
  final visibleText = [
    project.title,
    if (project.kind == 'bug') ...project.bug.values,
    for (final step in project.steps) ...[step.title, step.body],
  ].join('\n');
  if (utf8.encode(visibleText).length > 100000)
    throw const FormatException(
      'Guide PDF text limit: 100 KB; split the guide',
    );
  final regular = pw.Font.ttf(regularFont), bold = pw.Font.ttf(boldFont);
  final document = pw.Document(
    creator: 'Handy Media',
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  final context = pw.Context(document: document.document);
  final faces = [regular.getFont(context), bold.getFont(context)];
  for (final rune in visibleText.runes.toSet()) {
    if ({9, 10, 13}.contains(rune)) continue;
    if (faces.any((face) => !face.isRuneSupported(rune))) {
      throw FormatException(
        'PDF font does not support U+${rune.toRadixString(16).toUpperCase()}; export HTML to preserve this character',
      );
    }
  }
  final byId = {for (final image in images) image.stepId: image};
  final blocks = <pw.Widget>[
    pw.Text(
      project.title.isEmpty ? 'Handy Media' : project.title,
      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 16),
  ];
  if (project.kind == 'bug') {
    for (final key in ['environment', 'expected', 'actual', 'reproduction']) {
      final label = locale == 'vi'
          ? {
              'environment': 'Môi trường',
              'expected': 'Kết quả mong đợi',
              'actual': 'Kết quả thực tế',
              'reproduction': 'Các bước tái hiện',
            }[key]!
          : key[0].toUpperCase() + key.substring(1);
      blocks.addAll([
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(project.bug[key]!),
        pw.SizedBox(height: 12),
      ]);
    }
  }
  for (var index = 0; index < project.steps.length; index++) {
    cancellation?.check();
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    final step = project.steps[index], image = byId[step.id]!;
    final word = locale == 'vi' ? 'Bước' : 'Step';
    final height = math.min(400.0, 490.0 * image.height / image.width);
    blocks.addAll([
      pw.Text(
        '${index + 1}. ${step.title.isEmpty ? word : step.title}',
        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.SizedBox(
        width: 490,
        height: height,
        child: pw.Image(pw.MemoryImage(image.png), fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(height: 8),
      if (step.body.isNotEmpty) pw.Text(step.body),
      pw.SizedBox(height: 20),
    ]);
  }
  try {
    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 100,
        footer: (context) {
          // MultiPage.maxPages is a debug assertion upstream. Enforce in release.
          if (context.pageNumber > 100)
            throw const FormatException('Guide PDF limit: 100 pages');
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
        },
        build: (_) => blocks,
      ),
    );
    final bytes = await document.save(enableEventLoopBalancing: true);
    cancellation?.check();
    if (bytes.length > 10000000 ||
        document.document.pdfPageList.pages.length > 100)
      throw const FormatException('Guide PDF limit: 10 MB / 100 pages');
    return bytes;
  } on Cancelled {
    rethrow;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Could not lay out this guide as PDF; export HTML or split long text',
    );
  }
}

String _md(String text) =>
    text.split('').map((c) => r'\`*_{}[]<>#!|'.contains(c) ? '\\$c' : c).join();
String buildGuideMarkdown(CaptureProject input, {bool bugReport = false}) {
  final project = CaptureProject.parse(input.toJson());
  final bug = project.kind == 'bug' || bugReport
      ? [
          for (final key in [
            'environment',
            'expected',
            'actual',
            'reproduction',
          ])
            '## ${key[0].toUpperCase()}${key.substring(1)}\n\n${_md(project.bug[key]!)}\n\n',
        ].join()
      : '';
  final output =
      '# ${_md(project.title.isEmpty ? (bugReport ? 'Bug report' : 'Handy Media') : project.title)}\n\n$bug${[for (var i = 0; i < project.steps.length; i++) '## ${bugReport ? 'Evidence ${i + 1}: ' : '${i + 1}. '}${_md(project.steps[i].title.isEmpty ? 'Step ${i + 1}' : project.steps[i].title)}\n\n${_md(project.steps[i].body)}\n\n'].join()}';
  if (utf8.encode(output).length > 1000000)
    throw const FormatException('Guide text exceeds 1 MB');
  return output;
}

/// Heuristics only, without OCR; findings contain field paths, never secret values.
List<({String field, String kind})> findSensitiveGuideText(
  CaptureProject input,
) {
  final p = CaptureProject.parse(input.toJson());
  final fields = <String, String>{
    'title': p.title,
    for (final e in p.bug.entries) 'bug.${e.key}': e.value,
    for (var i = 0; i < p.tags.length; i++) 'tags.$i': p.tags[i],
    for (var i = 0; i < p.steps.length; i++) ...{
      'steps.$i.title': p.steps[i].title,
      'steps.$i.body': p.steps[i].body,
      for (var j = 0; j < p.steps[i].annotations.length; j++)
        'steps.$i.annotations.$j.text': p.steps[i].annotations[j].text,
    },
  };
  final rules = {
    'email': RegExp(
      r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
      caseSensitive: false,
    ),
    'phone': RegExp(r'(?:\+\d[\d ()-]{7,}\d)|\b0\d[\d ()-]{6,}\d\b'),
    'secret': RegExp(
      '\\b(?:password|passwd|token|api[_ -]?key|secret|authorization|mật\\s*khẩu|khóa[_ -]?api)["\']?\\s*[:=]\\s*["\']?\\S+',
      caseSensitive: false,
    ),
    'ip': RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'),
  };
  return [
    for (final e in fields.entries)
      for (final rule in rules.entries)
        if (rule.value.hasMatch(e.value)) (field: e.key, kind: rule.key),
  ];
}

const _guideTextNames = {'guide.html', 'guide.md', 'report.txt', 'README.txt'};
bool _guidePath(String name) =>
    _guideTextNames.contains(name) ||
    RegExp(r'^steps/[0-9]{3}\.png$').hasMatch(name);
Map<String, Uint8List> parseGuideZip(Uint8List bytes) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: _guidePath,
    maxEntries: 104,
    maxEntryBytes: 26000000,
  );
  final imageNames = files.keys.where((n) => n.startsWith('steps/')).toList()
    ..sort();
  if (imageNames.isEmpty ||
      imageNames.length > 100 ||
      files.length != imageNames.length + 4 ||
      !_guideTextNames.every(files.containsKey))
    throw const FormatException('Incomplete guide ZIP');
  for (final name in _guideTextNames) {
    final data = files[name]!;
    if (data.length >
        (name == 'guide.html'
            ? 26000000
            : name == 'README.txt'
            ? 4000
            : 1000000))
      throw const FormatException('Guide text exceeds limits');
    utf8.decode(data, allowMalformed: false);
  }
  for (var i = 0; i < imageNames.length; i++) {
    final name = 'steps/${'${i + 1}'.padLeft(3, '0')}.png';
    if (imageNames[i] != name)
      throw const FormatException('Invalid guide step numbering');
    GuideRaster('step-${i + 1}', files[name]!);
  }
  // Untrusted imported HTML is data only: this API never opens or executes it.
  return Map.unmodifiable(files);
}

Uint8List buildGuideZip(
  CaptureProject input,
  List<GuideRaster> images, {
  String locale = 'en',
}) {
  final project = _guide(input, images),
      byId = {for (final image in images) image.stepId: image};
  final files = <String, Uint8List>{
    'guide.html': Uint8List.fromList(
      utf8.encode(buildGuideHtml(project, images, locale: locale)),
    ),
    'guide.md': Uint8List.fromList(utf8.encode(buildGuideMarkdown(project))),
    'report.txt': Uint8List.fromList(
      utf8.encode(
        buildGuideMarkdown(project, bugReport: project.kind == 'bug'),
      ),
    ),
    'README.txt': Uint8List.fromList(
      utf8.encode(
        'Handy Media flattened guide. Editable project, source URIs, original images and annotation layers are excluded. Visible text is shared as written. Review every mask, image and caption before distributing.',
      ),
    ),
    for (var i = 0; i < project.steps.length; i++)
      'steps/${'${i + 1}'.padLeft(3, '0')}.png': byId[project.steps[i].id]!.png,
  };
  if (files.values.fold<int>(0, (n, b) => n + b.length) > 30000000)
    throw const FormatException(
      'Guide ZIP expansion limit: 30 MB; split the guide',
    );
  final archive = Archive();
  for (final e in files.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  // Stored ZIP gives an exact expansion budget, including highly repetitive HTML.
  final bytes = ZipEncoder().encodeBytes(archive, level: 0),
      reopened = parseGuideZip(bytes);
  for (final e in files.entries) {
    if (reopened[e.key]!.length != e.value.length ||
        getCrc32(reopened[e.key]!) != getCrc32(e.value))
      throw const FormatException('Guide ZIP roundtrip failed');
  }
  return bytes;
}

class GuideDifference {
  final Uint8List png;
  final int changedPixels, totalPixels;
  double get percent => changedPixels / totalPixels * 100;
  const GuideDifference(this.png, this.changedPixels, this.totalPixels);
}

Future<GuideDifference> compareGuidePng(
  GuideRaster before,
  GuideRaster after, {
  int threshold = 24,
  CancellationToken? cancellation,
}) async {
  if (threshold < 0 ||
      threshold > 255 ||
      before.width != after.width ||
      before.height != after.height ||
      before.width * before.height > 2000000)
    throw const FormatException(
      'Change map requires matching images up to 2Mpx and a threshold 0-255',
    );
  cancellation?.check();
  final a = decodeBoundedImage(before.png),
      b = decodeBoundedImage(after.png),
      output = img.Image(width: a.width, height: a.height, numChannels: 4);
  var changed = 0;
  int channel(Uint8List data, int at, int component) =>
      ((data[at + component] * data[at + 3] + 255 * (255 - data[at + 3])) / 255)
          .round();
  for (var y = 0; y < a.height; y++) {
    if (y % 32 == 0) {
      await Future<void>.delayed(Duration.zero);
      cancellation?.check();
    }
    for (var x = 0; x < a.width; x++) {
      final at = (y * a.width + x) * 4;
      var different = false;
      for (var c = 0; c < 3; c++) {
        if ((channel(a.rgba, at, c) - channel(b.rgba, at, c)).abs() >
            threshold) {
          different = true;
          break;
        }
      }
      if (different) changed++;
      output.setPixelRgba(
        x,
        y,
        different ? 239 : 226,
        different ? 68 : 232,
        different ? 68 : 240,
        255,
      );
    }
  }
  cancellation?.check();
  final png = mediaPng(output);
  cancellation?.check();
  return GuideDifference(png, changed, a.width * a.height);
}

Future<Uint8List> stitchGuidePng(
  List<GuideRaster> images, {
  int width = 1000,
  CancellationToken? cancellation,
}) async {
  if (images.isEmpty ||
      images.length > 100 ||
      width < 1 ||
      width > 4096 ||
      images.fold<int>(0, (n, e) => n + e.png.length) > 18000000)
    throw const FormatException('Invalid long-image input');
  final heights = [
    for (final image in images)
      math.max(1, (width * image.height / image.width).round()),
  ];
  final height = heights.fold<int>(0, (a, b) => a + b);
  if (width * height > 12000000 || height > 16384)
    throw const FormatException(
      'Long image exceeds 12Mpx; use a guide or split the project',
    );
  cancellation?.check();
  final canvas = img.Image(width: width, height: height, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  var y = 0;
  for (var i = 0; i < images.length; i++) {
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    final resized = img.copyResize(
      mediaBitmap(images[i].png),
      width: width,
      height: heights[i],
      interpolation: img.Interpolation.average,
    );
    img.compositeImage(canvas, resized, dstY: y);
    y += heights[i];
  }
  cancellation?.check();
  final output = mediaPng(canvas);
  cancellation?.check();
  return output;
}
