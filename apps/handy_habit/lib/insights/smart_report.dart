import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../scope.dart';
import 'smart_review.dart';

Future<Uint8List> smartReportPdf(
  List<ReviewSection> sections, {
  required String today,
  required String zone,
  required bool vi,
}) async {
  final font = pw.Font.ttf(await rootBundle.load('fonts/Nunito-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('fonts/Nunito-Bold.ttf'));
  final ink = PdfColor.fromHex('#54261F'), accent = PdfColor.fromHex('#B42318');
  final doc = pw.Document(title: 'Handy Habit · $today', author: 'Handy Habit');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      maxPages: 200,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Handy Habit',
              style: pw.TextStyle(
                fontSize: 21,
                fontWeight: pw.FontWeight.bold,
                color: ink,
              ),
            ),
            pw.Text(today),
          ],
        ),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            vi
                ? 'Riêng tư · Chỉ tính trên thiết bị'
                : 'Private · Calculated on your device',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text('${c.pageNumber} / ${c.pagesCount}'),
        ],
      ),
      build: (_) => [
        pw.SizedBox(height: 16),
        pw.Text(
          vi ? 'Nhìn lại nhịp sống' : 'A review of your rhythms',
          style: pw.TextStyle(fontSize: 25, color: ink),
        ),
        pw.Text('$today · $zone'),
        for (final (title, lines) in sections) ...[
          pw.SizedBox(height: 22),
          pw.Header(
            level: 1,
            text: title,
            textStyle: pw.TextStyle(
              fontSize: 16,
              color: ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          for (final line in lines.where((l) => l.isNotEmpty))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

class SmartReportPage extends StatefulWidget {
  final HabitScope scope;
  final List<ReviewSection> sections;
  final String today;
  const SmartReportPage({
    super.key,
    required this.scope,
    required this.sections,
    required this.today,
  });
  @override
  State<SmartReportPage> createState() => _SmartReportPageState();
}

class _SmartReportPageState extends State<SmartReportPage> {
  bool busy = false;
  Future<void> save() async {
    if (!widget.scope.pro(context)) return;
    setState(() => busy = true);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    try {
      final bytes = await smartReportPdf(
        widget.sections,
        today: widget.today,
        zone: widget.scope.state.zone,
        vi: vi,
      );
      if (!mounted || !widget.scope.pro(context)) return;
      final result = await widget.scope.files.exportBytes(
        'handy-habit-insights-${widget.today}.pdf',
        bytes,
        mimeType: 'application/pdf',
      );
      if (result != null && mounted)
        showHandyMessage(
          context,
          tr(context, 'Report export requested.', 'Đã yêu cầu xuất báo cáo.'),
        );
    } catch (e) {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Could not export: ${errorText(context, e)}. Try again.',
            'Chưa xuất được: ${errorText(context, e)}. Hãy thử lại.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(tr(context, 'Report preview', 'Xem trước báo cáo')),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('smart-report-save'),
          onPressed: busy || !widget.scope.pro(context) ? null : save,
          child: Text(
            tr(
              context,
              busy ? 'Preparing PDF…' : 'Save PDF',
              '${busy ? 'Đang tạo PDF…' : 'Lưu PDF'}',
            ),
          ),
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: HandyContent(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Handy Habit',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('${widget.today} · ${widget.scope.state.zone}'),
            Text(
              tr(
                context,
                'This report includes private habit and mood summaries. Save it somewhere you trust.',
                'Báo cáo chứa tóm tắt thói quen và tâm trạng riêng tư. Hãy lưu ở nơi bạn tin cậy.',
              ),
            ),
            for (final (title, lines) in widget.sections) ...[
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              for (final line in lines.where((l) => l.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(line),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
