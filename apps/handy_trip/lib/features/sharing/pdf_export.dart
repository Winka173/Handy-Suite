import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:handy_trip_engine/handy_trip_engine.dart';

Future<Uint8List> tripPdf(
  TripState state, {
  bool journal = false,
  bool vietnamese = false,
}) async {
  if (state.stops.length + state.visits.length + state.notes.length > 2000)
    throw const FormatException(
      'PDF limited to 2000 entries; use JSON/CSV/ZIP for larger selections',
    );
  final regular = pw.Font.ttf(
        await rootBundle.load(
          'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
        ),
      ),
      bold = pw.Font.ttf(
        await rootBundle.load(
          'packages/handy_ui/assets/fonts/NotoSans-Bold.ttf',
        ),
      );
  final doc = pw.Document(), public = publicDocument(state);
  final children = <pw.Widget>[
    pw.Header(level: 0, text: 'Handy Trip'),
    pw.Text(
      vietnamese
          ? 'Bản chia sẻ: không chứa mã đặt chỗ, ghi chú riêng hay tọa độ chính xác.'
          : 'Shared report: no booking identifiers, private notes or precise coordinates.',
    ),
  ];
  for (final trip in public['trips'] as List) {
    children.add(pw.Header(level: 1, text: trip['title']));
    children.add(
      pw.Text('${trip['start']} - ${trip['end']} / ${trip['zone']}'),
    );
    for (final stop in (public['stops'] as List).where(
      (s) => s['trip'] == trip['id'],
    ))
      children.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(
            '${stop['day']} ${stop['time'] ?? ''} / ${stop['title']}',
          ),
        ),
      );
  }
  if (journal) {
    final used = <String>{};
    for (final v in state.visits.where((v) => v.confirmed)) {
      children.add(
        pw.Header(
          level: 2,
          text:
              '${localDay(DateTime.parse(v.at), v.zone)} / ${(public['visits'] as List).firstWhere((row) => row['id'] == v.key)['place']}',
        ),
      );
      used.addAll(v.assets);
    }
    for (final n in state.notes) {
      children.add(
        pw.Header(level: 2, text: localDay(DateTime.parse(n.at), n.zone)),
      );
      used.addAll(n.assets);
    }
    if (used.length > 100)
      throw const FormatException(
        'Select at most 100 photos for a PDF; use day selections',
      );
    for (final key in used) {
      final asset = state.assets.firstWhere((a) => a.key == key);
      if (asset.mime.startsWith('image/'))
        children.add(
          pw.Container(
            height: 260,
            alignment: pw.Alignment.center,
            child: pw.Image(
              pw.MemoryImage(publicImage(state.files[asset.path]!)),
              fit: pw.BoxFit.contain,
            ),
          ),
        );
    }
  }
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 300,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      build: (_) => children,
    ),
  );
  return doc.save();
}
