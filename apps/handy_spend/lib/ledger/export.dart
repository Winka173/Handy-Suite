import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../scope.dart';
import 'ledger_filter.dart';

/// Asks first: an export is a copy of private figures outside the app.
Future<bool> confirmExport(BuildContext context) => confirmHandy(
  context,
  title: tr(context, 'Export private data?', 'Xuất dữ liệu riêng tư?'),
  message: tr(
    context,
    'The file holds your amounts, payees and notes, unencrypted. Keep it somewhere only you can open.',
    'File chứa số tiền, đối tác và ghi chú của bạn, không mã hóa. Hãy cất ở nơi chỉ bạn mở được.',
  ),
  confirmLabel: tr(context, 'Export', 'Xuất'),
);

/// Writes [rows] (and the expenses their refunds point at) as CSV, XLSX,
/// JSON or PDF. True when a file was written.
Future<bool> exportEntries(
  BuildContext context,
  SpendScope scope,
  String format,
  List<Entry> rows,
  LedgerFilter period,
) async {
  if (!await confirmExport(context) || !context.mounted) return false;
  final s = scope.state;
  final byId = {for (final e in s.entries) e.id: e};
  final ids = rows.map((e) => e.id).toSet();
  for (final e in rows) {
    if (e.refundOf != null) ids.add(e.refundOf!);
  }
  final chosen = ids.map((id) => byId[id]!).toList();
  final table = transactionRows(s, chosen);
  final name = 'handy-spend-${DateTime.now().millisecondsSinceEpoch}.$format';
  late Uint8List bytes;
  late String mime;
  switch (format) {
    case 'csv':
      bytes = Uint8List.fromList(utf8.encode(csvEncode(table)));
      mime = 'text/csv';
    case 'xlsx':
      bytes = await compute(xlsxEncode, table);
      mime =
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'json':
      bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'app': 'handy-spend-transactions',
            'version': 1,
            'currency': s.currency,
            'reportTimezone': s.zone,
            'from': period.from,
            'untilExcluded': period.until,
            'accounts': s.accounts
                .where(
                  (a) => chosen.any(
                    (e) => e.account == a.id || e.toAccount == a.id,
                  ),
                )
                .map((a) => a.toJson())
                .toList(),
            'categories': s.categories.map((c) => c.toJson()).toList(),
            'entries': chosen.map((e) => e.toJson()).toList(),
          }),
        ),
      );
      mime = 'application/json';
    case 'pdf':
      if (chosen.length > 5000)
        throw const FormatException(
          'PDF holds 5000 rows at most; use CSV or XLSX / PDF tối đa 5000 dòng; hãy dùng CSV hoặc XLSX',
        );
      if (!context.mounted) return false;
      bytes = await _pdf(context, s, table, period);
      mime = 'application/pdf';
    default:
      throw ArgumentError('Unsupported export');
  }
  if (bytes.length > 30000000)
    throw const FormatException('Export exceeds 30MB / File xuất vượt 30MB');
  final result = await scope.files.exportBytes(name, bytes, mimeType: mime);
  if (!context.mounted || result == null) return false;
  showHandyMessage(
    context,
    kIsWeb
        ? tr(
            context,
            'Download requested; check the saved file.',
            'Đã yêu cầu tải; hãy kiểm tra file đã lưu.',
          )
        : tr(context, 'Exported.', 'Đã xuất file.'),
  );
  return true;
}

Future<Uint8List> _pdf(
  BuildContext context,
  SpendState s,
  List<List<String>> table,
  LedgerFilter period,
) async {
  final note = tr(
    context,
    'Actual records; refunds may include original expense dependencies. Amounts retain original currency.',
    'Dữ liệu thật; hoàn tiền có thể kèm khoản chi gốc liên quan. Giữ tiền tệ ban đầu.',
  );
  final headers = [
    tr(context, 'Date', 'Ngày'),
    tr(context, 'Payee', 'Đối tác'),
    tr(context, 'Amount', 'Số tiền'),
    tr(context, 'Currency', 'Tiền'),
  ];
  final font = pw.Font.ttf(
    await rootBundle.load(
      'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
    ),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('packages/handy_ui/assets/fonts/NotoSans-Bold.ttf'),
  );
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 200,
      theme: pw.ThemeData.withFont(
        base: font,
        bold: bold,
        italic: font,
        boldItalic: bold,
      ),
      build: (_) => [
        pw.Text('Handy Spend', style: const pw.TextStyle(fontSize: 22)),
        pw.Text('${period.from} - ${period.until} (${s.zone}; end excluded)'),
        pw.Text(note),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: [
            for (final row in table.skip(1))
              [reportDay(row[0], s.zone), row[1], row[2], row[3]],
          ],
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}
