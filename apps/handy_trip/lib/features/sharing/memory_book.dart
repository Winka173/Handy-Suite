import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';

Future<Uint8List> memoryBookPdf(
  TripState s,
  String tripId, {
  bool privateText = false,
  bool includeMoney = false,
}) async {
  final book = memoryBookData(
    s,
    tripId,
    privateText: privateText,
    includeMoney: includeMoney,
  );
  if ((book['days'] as List).length > 366)
    throw const FormatException('Choose a book up to 366 days');
  final font = pw.Font.ttf(
    await rootBundle.load(
      'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
    ),
  );
  final doc = pw.Document(),
      seen = <String>{},
      images = <String, pw.MemoryImage>{};
  pw.Widget? photo(String key) {
    final a = s.assets.firstWhere((a) => a.key == key);
    if (!a.mime.startsWith('image/')) return null;
    seen.add(key);
    if (seen.length > 100)
      throw const FormatException('Select a trip with at most 100 book photos');
    return pw.Column(
      children: [
        pw.Container(
          height: 260,
          alignment: pw.Alignment.center,
          child: pw.Image(
            images.putIfAbsent(
              key,
              () => pw.MemoryImage(publicImage(s.files[a.path]!)),
            ),
            fit: pw.BoxFit.contain,
          ),
        ),
      ],
    );
  }

  final children = <pw.Widget>[
    pw.Header(level: 0, text: book['title']),
    pw.Text('${book['start']} — ${book['end']} / ${book['zone']}'),
    pw.Text(
      '${book['visits']} visits · ${book['uniquePlaces']} unique places. Personal memories confirmed by the user, not proof of GPS.',
    ),
    pw.Text(
      privateText || includeMoney
          ? 'Private selections included. Review before sharing.'
          : 'Private text and expenses omitted. Photo metadata removed.',
    ),
  ];
  Iterable<pw.Widget> paragraphs(String text) sync* {
    final runes = text.runes.toList();
    for (var i = 0; i < runes.length; i += 400) {
      yield pw.Text(String.fromCharCodes(runes.skip(i).take(400)));
    }
  }

  void caption(String key) {
    if (privateText)
      children.addAll(
        paragraphs(s.assets.firstWhere((a) => a.key == key).text('caption')),
      );
  }

  if (book['cover'] != null) {
    final p = photo(book['cover']);
    if (p != null) {
      children.add(p);
      caption(book['cover']);
    }
  }
  for (final day in book['days'] as List) {
    children.add(pw.Header(level: 1, text: day['day']));
    for (final v in day['visits'] as List) {
      children.add(pw.Header(level: 2, text: v['place']));
      if (privateText && (v['note'] as String).isNotEmpty)
        children.addAll(paragraphs(v['note']));
      final pictures = <pw.Widget>[];
      for (final key in v['assets'] as List) {
        final p = photo(key);
        if (p != null) pictures.add(p);
      }
      children.addAll(pictures);
      for (final key in v['assets'] as List) caption(key);
    }
    for (final note in day['notes'] as List) {
      if (privateText) {
        children.add(pw.Header(level: 2, text: note['title']));
        children.addAll(paragraphs(note['body']));
      }
      for (final key in note['assets'] as List) {
        final p = photo(key);
        if (p != null) {
          children.add(p);
          caption(key);
        }
      }
    }
  }
  if (includeMoney) {
    children.add(
      pw.Header(level: 1, text: 'Spending — currencies remain separate'),
    );
    for (final e in object(book['expenses']).entries)
      children.add(pw.Text('${e.key}: ${amount(minorValue(e.value), e.key)}'));
  }
  doc.addPage(
    pw.MultiPage(
      maxPages: 500,
      theme: pw.ThemeData.withFont(base: font),
      pageFormat: PdfPageFormat.a4,
      build: (_) => children,
    ),
  );
  return doc.save();
}

Future<void> exportMemoryBook(
  BuildContext context,
  TripScope scope,
  String tripId,
) async {
  await tripForm(
    context,
    tr(context, 'Create a memory book', 'Tạo sách kỷ niệm'),
    [
      TripField(
        'format',
        'Format',
        'Định dạng',
        kind: 'choice',
        choices: {'pdf': 'PDF', 'zip': 'HTML + photos ZIP'},
      ),
      const TripField(
        'private',
        'Include private notes and captions',
        'Bao gồm ghi chú và chú thích riêng tư',
        kind: 'toggle',
      ),
      const TripField(
        'money',
        'Include spending summary',
        'Bao gồm tổng chi tiêu',
        kind: 'toggle',
      ),
      const TripField(
        'reviewed',
        'I reviewed the privacy choices and visible photo contents',
        'Tôi đã kiểm tra lựa chọn riêng tư và nội dung ảnh',
        kind: 'toggle',
      ),
    ],
    {'format': 'pdf', 'private': false, 'money': false, 'reviewed': false},
    (v) async {
      if (v['reviewed'] != true)
        throw const FormatException('Review privacy choices before exporting');
      final snapshot = scope.state,
          bytes = v['format'] == 'pdf'
              ? await memoryBookPdf(
                  snapshot,
                  tripId,
                  privateText: v['private'] == true,
                  includeMoney: v['money'] == true,
                )
              : memoryBookZip(
                  snapshot,
                  tripId,
                  privateText: v['private'] == true,
                  includeMoney: v['money'] == true,
                );
      if (bytes.length > portableLimit)
        throw const FormatException('Book exceeds 30 MB');
      final saved = await scope.files.exportBytes(
        'handy-trip-memory-book.${v['format']}',
        bytes,
        mimeType: v['format'] == 'pdf' ? 'application/pdf' : 'application/zip',
      );
      if (saved == null)
        throw const FormatException(
          'Export cancelled; your choices are preserved',
        );
    },
    saveLabel: tr(context, 'Export book', 'Xuất sách'),
    footer: [
      Text(
        tr(
          context,
          'Personal book, not an official travel document. Reencoded photos omit EXIF/GPS. User text and visible images may still contain secrets; review before sharing.',
          'Sách cá nhân, không phải giấy tờ du lịch. Ảnh xuất bỏ EXIF/GPS. Chữ do bạn nhập và nội dung ảnh vẫn có thể chứa thông tin riêng; kiểm tra trước khi chia sẻ.',
        ),
      ),
    ],
  );
}
