import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart' show BuildContext, tr, Text;
import '../../scope.dart';
import '../../ui/form.dart';

Future<void> exportPersonalStamp(
  BuildContext context,
  TripScope scope,
  String visitId,
) async {
  final pro = LifetimeScope.maybeOf(context)?.pro == true,
      data = stampData(scope.state, visitId);
  await tripForm(
    context,
    tr(context, 'Personal memory stamp', 'Dấu kỷ niệm cá nhân'),
    [
      TripField(
        'format',
        'Format',
        'Định dạng',
        kind: 'choice',
        choices: {'png': 'PNG', 'pdf': 'PDF'},
      ),
      TripField(
        'style',
        'Original template',
        'Mẫu thiết kế riêng',
        kind: 'choice',
        choices: {
          'ledger': tr(context, 'Daybook', 'Sổ hành trình'),
          if (pro) 'postcard': tr(context, 'Postcard · Pro', 'Bưu thiếp · Pro'),
        },
      ),
      if (pro)
        TripField(
          'accent',
          'Export accent · Pro',
          'Màu bản xuất · Pro',
          kind: 'choice',
          choices: {
            '0284C7': 'Ocean',
            '334155': 'Slate',
            '0F766E': 'Forest',
            '7E22CE': 'Plum',
          },
        ),
      const TripField(
        'reviewed',
        'I reviewed the place/date and visible content before exporting',
        'Tôi đã kiểm tra địa điểm/ngày và nội dung trước khi xuất',
        kind: 'toggle',
      ),
    ],
    {'format': 'png', 'style': 'ledger', 'accent': '0284C7', 'reviewed': false},
    (v) async {
      if (v['reviewed'] != true)
        throw const FormatException('Review the stamp before exporting');
      if ((v['style'] != 'ledger' || v['accent'] != '0284C7') &&
          LifetimeScope.maybeOf(context)?.pro != true)
        throw StateError('Pro entitlement required for custom templates');
      final color = 0xff000000 | int.parse(v['accent'], radix: 16),
          snapshot = scope.state;
      final bytes = v['format'] == 'png'
          ? await stampPng(snapshot, visitId, style: v['style'], accent: color)
          : await stampPdf(snapshot, visitId, style: v['style'], accent: color);
      final saved = await scope.files.exportBytes(
        'handy-trip-personal-stamp.${v['format']}',
        bytes,
        mimeType: v['format'] == 'png' ? 'image/png' : 'application/pdf',
      );
      if (saved == null)
        throw const FormatException('Export cancelled; selections preserved');
    },
    saveLabel: tr(context, 'Export', 'Xuất'),
    footer: [
      Text(
        '${data['place']} · ${data['day']}\n${tr(context, 'Personal design, not an official passport/government stamp or proof of GPS. Precise position and photo metadata are omitted.', 'Thiết kế cá nhân, không phải dấu hộ chiếu/cơ quan nhà nước hay bằng chứng GPS. Không chứa vị trí chính xác hoặc metadata ảnh.')}',
      ),
    ],
  );
}

Future<Uint8List> stampPng(
  TripState state,
  String visitId, {
  String style = 'ledger',
  int accent = 0xff0284c7,
}) async {
  if (!['ledger', 'postcard'].contains(style) || accent >> 24 != 255)
    throw const FormatException('Unknown stamp style/color');
  final data = stampData(state, visitId),
      recorder = ui.PictureRecorder(),
      canvas = ui.Canvas(recorder);
  const size = ui.Size(1200, 800), ink = ui.Color(0xff171717);
  final cyan = ui.Color(accent);
  canvas.drawColor(const ui.Color(0xfffafafa), ui.BlendMode.src);
  if (style == 'ledger')
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(40, 40, 1120, 720),
        const ui.Radius.circular(12),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = cyan,
    );
  if (style == 'postcard')
    canvas.drawRect(
      const ui.Rect.fromLTWH(40, 40, 1120, 12),
      ui.Paint()..color = cyan,
    );
  void text(
    String value,
    double y,
    double fontSize, {
    ui.Color color = ink,
    int lines = 3,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Geist',
          package: 'handy_ui',
          fontSize: fontSize,
          color: color,
          height: 1.25,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: ui.TextAlign.center,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: 1040);
    painter.paint(canvas, ui.Offset((size.width - painter.width) / 2, y));
    painter.dispose();
  }

  text('HANDY TRIP · PERSONAL MEMORY', 90, 26, color: cyan, lines: 1);
  text(data['place'], 190, 56, lines: 4);
  text(data['day'], 510, 40, lines: 1);
  text(data['trip'], 575, 24, lines: 2);
  text(
    'User confirmed · Not an official stamp or proof of GPS',
    700,
    20,
    lines: 1,
  );
  final picture = recorder.endRecording(),
      image = await picture.toImage(1200, 800),
      bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<Uint8List> stampPdf(
  TripState state,
  String visitId, {
  String style = 'ledger',
  int accent = 0xff0284c7,
}) async {
  if (!['ledger', 'postcard'].contains(style) || accent >> 24 != 255)
    throw const FormatException('Unknown stamp style/color');
  final data = stampData(state, visitId),
      font = pw.Font.ttf(
        await rootBundle.load(
          'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
        ),
      );
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5.landscape,
      theme: pw.ThemeData.withFont(base: font),
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(20),
        decoration: pw.BoxDecoration(
          border: style == 'ledger'
              ? pw.Border.all(
                  color: PdfColor.fromHex(
                    '#${accent.toRadixString(16).padLeft(8, '0').substring(2)}',
                  ),
                  width: 2,
                )
              : pw.Border(
                  top: pw.BorderSide(
                    color: PdfColor.fromHex(
                      '#${accent.toRadixString(16).padLeft(8, '0').substring(2)}',
                    ),
                    width: 4,
                  ),
                ),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('HANDY TRIP · PERSONAL MEMORY'),
            pw.SizedBox(height: 18),
            pw.Text(
              data['place'],
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: (data['place'] as String).length > 140 ? 14 : 24,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text(data['day'], style: const pw.TextStyle(fontSize: 18)),
            pw.Text(data['trip']),
            pw.Spacer(),
            pw.Text(data['label'], style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}
