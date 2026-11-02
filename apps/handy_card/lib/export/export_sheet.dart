import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import '../editor/controls.dart';
import '../editor/paint.dart';
import '../editor/studio_controller.dart';
import '../scope.dart';

enum ExportFormat {
  png,
  jpeg,
  pdf,
  sheet,
  svg,
  vcard,
  qr,
  html,
  signature,
  project,
}

Future<void> openExport(
  BuildContext context,
  CardScope scope,
  StudioController c,
) async {
  await c.save();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: ExportSheet(scope: scope, c: c),
    ),
  );
}

/// Choosing what to hand over: the format, the side, the size and the
/// print options, then one save through the platform's own dialog.
class ExportSheet extends StatefulWidget {
  final CardScope scope;
  final StudioController c;
  const ExportSheet({super.key, required this.scope, required this.c});
  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  ExportFormat format = ExportFormat.png;
  late String side = widget.c.session.page;
  double dpi = 300;
  bool transparent = false, bleed = false, cropMarks = false;
  String vcardVersion = '3.0';
  bool letter = false;
  int copies = 10;
  bool busy = false;
  String? error;
  List<String> warnings = const [];

  CardDocument get doc => widget.c.doc;
  CardProfile? get profile => widget.c.profile;

  String label(ExportFormat f) => switch (f) {
    ExportFormat.png => 'PNG',
    ExportFormat.jpeg => 'JPEG',
    ExportFormat.pdf => 'PDF',
    ExportFormat.sheet => tr(context, 'Print sheet', 'Tờ in'),
    ExportFormat.svg => 'SVG',
    ExportFormat.vcard => tr(context, 'Contact (.vcf)', 'Danh bạ (.vcf)'),
    ExportFormat.qr => tr(context, 'Contact QR', 'QR danh bạ'),
    ExportFormat.html => tr(context, 'Profile page', 'Trang hồ sơ'),
    ExportFormat.signature => tr(context, 'Email signature', 'Chữ ký email'),
    ExportFormat.project => tr(
      context,
      'Editable copy (.zip)',
      'Bản sửa được (.zip)',
    ),
  };

  bool get needsProfile => const {
    ExportFormat.vcard,
    ExportFormat.qr,
    ExportFormat.html,
    ExportFormat.signature,
  }.contains(format);

  String get baseName =>
      safeCardFileName(doc.name.isEmpty ? 'handy-card' : doc.name);

  Future<Uint8List> png(String pageId, {double? at, bool clear = false}) async {
    final image = await renderSide(
      doc,
      doc.page(pageId),
      widget.c.paintContext,
      dpi: at ?? dpi,
      bleed: bleed,
      transparent: clear,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> run() async {
    // Words for this export, taken before any wait.
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    String t(String en, String v) => vi ? v : en;
    setState(() {
      busy = true;
      error = null;
      warnings = const [];
    });
    try {
      // Pictures must be loaded before a raster export draws them.
      for (final a in doc.assets) {
        widget.scope.images[a.id];
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final assets = await widget.scope.library.assetsFor([doc]);
      final missing = doc.assets.where((a) => !assets.containsKey(a.id)).length;
      final found = <String>[
        if (missing > 0)
          t(
            '$missing pictures are missing and were left blank.',
            '$missing ảnh bị thiếu, để trống.',
          ),
      ];
      late final Uint8List bytes;
      late final String name, mime;
      switch (format) {
        case ExportFormat.png:
          bytes = await png(side, clear: transparent);
          (name, mime) = ('$baseName.png', 'image/png');
        case ExportFormat.jpeg:
          final raw = await png(side);
          bytes = Uint8List.fromList(
            img.encodeJpg(img.decodePng(raw)!, quality: 92),
          );
          (name, mime) = ('$baseName.jpg', 'image/jpeg');
        case ExportFormat.pdf:
          final out = await exportPdf(
            doc,
            profile: profile,
            measurer: widget.c.measurer,
            assets: assets,
            fonts: await cardPdfFonts(),
            bleed: bleed,
            cropMarks: cropMarks,
          );
          found.addAll(out.warnings);
          (bytes, name, mime) = (out.bytes, '$baseName.pdf', 'application/pdf');
        case ExportFormat.sheet:
          final out = await exportPrintSheet(
            doc,
            side,
            sheet: letter ? PdfPageFormat.letter : PdfPageFormat.a4,
            copies: copies,
            profile: profile,
            measurer: widget.c.measurer,
            assets: assets,
            fonts: await cardPdfFonts(),
          );
          found.addAll(out.warnings);
          (bytes, name, mime) = (
            out.bytes,
            '$baseName-sheet.pdf',
            'application/pdf',
          );
        case ExportFormat.svg:
          final out = exportSvg(
            doc,
            side,
            profile: profile,
            measurer: widget.c.measurer,
            assets: assets,
            bleed: bleed,
            families: cardSvgFamilies,
          );
          found
            ..addAll(out.warnings)
            ..add(
              t(
                'SVG names its faces; a viewer without them substitutes others. Use PDF or PNG for exact type.',
                'SVG chỉ ghi tên font; máy không có font sẽ thay font khác. Dùng PDF hoặc PNG để giữ đúng chữ.',
              ),
            );
          (bytes, name, mime) = (
            Uint8List.fromList(utf8.encode(out.svg)),
            '$baseName.svg',
            'image/svg+xml',
          );
        case ExportFormat.vcard:
          (bytes, name, mime) = (
            Uint8List.fromList(
              utf8.encode(vcardFor(profile!, version: vcardVersion)),
            ),
            '${safeCardFileName(profile!.displayName)}.vcf',
            'text/vcard',
          );
        case ExportFormat.qr:
          final payload = vcardFor(profile!);
          final m = qrMatrix(payload, ecc: 'M');
          const cell = 12;
          final size = (m.size + 8) * cell;
          final canvas = img.Image(width: size, height: size)
            ..clear(img.ColorRgb8(255, 255, 255));
          for (var r = 0; r < m.size; r++) {
            for (var col = 0; col < m.size; col++) {
              if (m.at(r, col))
                img.fillRect(
                  canvas,
                  x1: (col + 4) * cell,
                  y1: (r + 4) * cell,
                  x2: (col + 5) * cell - 1,
                  y2: (r + 5) * cell - 1,
                  color: img.ColorRgb8(0, 0, 0),
                );
            }
          }
          (bytes, name, mime) = (
            Uint8List.fromList(img.encodePng(canvas)),
            '${safeCardFileName(profile!.displayName)}-qr.png',
            'image/png',
          );
        case ExportFormat.html:
          final front = await png(doc.pages.first.id, at: 220);
          final photo = profile!.photo == null
              ? null
              : await widget.scope.library.assetBytes(profile!.photo!);
          final html = profileHtml(
            profile!,
            cardPng: front,
            photo: photo,
            photoMime: photo == null
                ? 'image/jpeg'
                : (imageMime(photo) ?? 'image/jpeg'),
            lang: vi ? 'vi' : 'en',
          );
          found.add(
            t(
              'This page works when you host it yourself (https). A QR code cannot point to a file on this device.',
              'Trang này dùng được khi bạn tự đăng lên mạng (https). Mã QR không trỏ được tới file trên máy này.',
            ),
          );
          (bytes, name, mime) = (
            Uint8List.fromList(utf8.encode(html)),
            '$baseName.html',
            'text/html',
          );
        case ExportFormat.signature:
          (bytes, name, mime) = (
            Uint8List.fromList(utf8.encode(emailSignatureHtml(profile!))),
            '$baseName-signature.html',
            'text/html',
          );
          found.add(
            t(
              'Mail apps differ: paste the signature and send yourself a test before using it.',
              'Mỗi ứng dụng mail hiển thị khác nhau: dán chữ ký và gửi thử cho chính bạn trước.',
            ),
          );
        case ExportFormat.project:
          bytes = await widget.scope.library.exportProject(only: [doc]);
          (name, mime) = ('$baseName.handycard.zip', 'application/zip');
      }
      final uri = await widget.scope.files.exportBytes(
        name,
        bytes,
        mimeType: mime,
      );
      if (!mounted) return;
      setState(() => warnings = found);
      if (uri != null)
        showHandyMessage(context, t('Saved $name', 'Đã lưu $name'));
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidesNeeded = const {
      ExportFormat.png,
      ExportFormat.jpeg,
      ExportFormat.svg,
      ExportFormat.sheet,
    }.contains(format);
    final px = (doc.width * dpi / 72).round(),
        py = (doc.height * dpi / 72).round();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          0,
          HandySpace.l,
          HandySpace.xxl,
        ),
        children: [
          Text(
            tr(context, 'Export', 'Xuất'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: HandySpace.m),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final f in ExportFormat.values)
                ChoiceChip(
                  key: Key('export-${f.name}'),
                  label: Text(label(f)),
                  selected: format == f,
                  onSelected: (_) => setState(() => format = f),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.l),
          if (needsProfile && profile == null)
            HandyNotice(
              tr(
                context,
                'Pick a profile for this design first (tap the empty canvas → Profile).',
                'Hãy chọn hồ sơ cho thiết kế trước (chạm vào chỗ trống → Hồ sơ).',
              ),
              tone: HandyTone.warning,
            ),
          if (sidesNeeded && doc.pages.length > 1)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final (i, p) in doc.pages.indexed)
                  ButtonSegment(
                    value: p.id,
                    label: Text(
                      p.name == 'Front'
                          ? tr(context, 'Front', 'Trước')
                          : p.name == 'Back'
                          ? tr(context, 'Back', 'Sau')
                          : '${i + 1}',
                    ),
                  ),
              ],
              selected: {side},
              onSelectionChanged: (v) => setState(() => side = v.first),
            ),
          if (format == ExportFormat.png || format == ExportFormat.jpeg) ...[
            const SizedBox(height: HandySpace.m),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 150, label: Text('150 dpi')),
                ButtonSegment(value: 300, label: Text('300 dpi')),
                ButtonSegment(value: 600, label: Text('600 dpi')),
              ],
              selected: {dpi},
              onSelectionChanged: (v) => setState(() => dpi = v.first),
            ),
            Text(
              '$px × $py px',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFeatures: tabular),
            ),
            if (format == ExportFormat.png)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr(context, 'Transparent background', 'Nền trong suốt'),
                ),
                value: transparent,
                onChanged: (v) => setState(() => transparent = v),
              ),
          ],
          if (const {
                ExportFormat.png,
                ExportFormat.jpeg,
                ExportFormat.pdf,
                ExportFormat.svg,
              }.contains(format) &&
              doc.bleed > 0)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  context,
                  'Include bleed (${(doc.bleed / pointsPerMm).toStringAsFixed(1)} mm)',
                  'Kèm tràn lề (${(doc.bleed / pointsPerMm).toStringAsFixed(1)} mm)',
                ),
              ),
              subtitle: Text(
                tr(
                  context,
                  'For printers who trim after printing.',
                  'Cho nhà in xén sau khi in.',
                ),
              ),
              value: bleed,
              onChanged: (v) => setState(() => bleed = v),
            ),
          if (format == ExportFormat.pdf)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, 'Crop marks', 'Dấu cắt')),
              value: cropMarks,
              onChanged: (v) => setState(() => cropMarks = v),
            ),
          if (format == ExportFormat.sheet) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('A4')),
                ButtonSegment(value: true, label: Text('Letter')),
              ],
              selected: {letter},
              onSelectionChanged: (v) => setState(() => letter = v.first),
            ),
            SliderRow(
              label: tr(context, 'Copies', 'Số thẻ'),
              shown: '$copies',
              value: copies.toDouble(),
              min: 1,
              max: 100,
              onChanged: (v) => setState(() => copies = v.round()),
            ),
          ],
          if (format == ExportFormat.vcard)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: '3.0', label: Text('vCard 3.0')),
                ButtonSegment(value: '4.0', label: Text('vCard 4.0')),
              ],
              selected: {vcardVersion},
              onSelectionChanged: (v) => setState(() => vcardVersion = v.first),
            ),
          if (busy) ...[
            const SizedBox(height: HandySpace.l),
            const LinearProgressIndicator(),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: HandyNotice(error!, tone: HandyTone.error),
            ),
          for (final w in warnings)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: HandyNotice(w, tone: HandyTone.warning),
            ),
        ],
      ),
      bottomNavigationBar: HandyBottomBar(
        child: FilledButton(
          key: const Key('export-save'),
          onPressed: busy || (needsProfile && profile == null) ? null : run,
          child: Text(
            tr(context, 'Save ${label(format)}', 'Lưu ${label(format)}'),
          ),
        ),
      ),
    );
  }
}
