part of '../handy_tools_engine.dart';

/// Matrix is row-major, excludes the quiet zone and is immutable. All three
/// renderers use this same UTF-8 byte encoding and M error correction. qr 3.x
/// supports the workspace's Dart 3.12 SDK but has no explicit ECI marker; scanners
/// must infer UTF-8 for non-ASCII payloads. Do not promise every legacy scanner.
List<List<bool>> qrMatrix(String value) {
  _qrBound(value);
  final code = qr.QrCode.fromData(
    data: value,
    errorCorrectLevel: qr.QrErrorCorrectLevel.M,
  );
  final matrix = qr.QrImage(code);
  return List.unmodifiable(
    List.generate(
      matrix.moduleCount,
      (row) => List<bool>.unmodifiable(
        List.generate(
          matrix.moduleCount,
          (column) => matrix.isDark(row, column),
        ),
      ),
    ),
  );
}

Uint8List qrPng(String value) {
  final matrix = qrMatrix(value), count = matrix.length;
  const quiet = 4, scale = 8;
  final side = (count + quiet * 2) * scale;
  final bitmap = image.Image(width: side, height: side);
  image.fill(bitmap, color: image.ColorRgb8(255, 255, 255));
  for (var row = 0; row < count; row++)
    for (var column = 0; column < count; column++)
      if (matrix[row][column]) {
        image.fillRect(
          bitmap,
          x1: (column + quiet) * scale,
          y1: (row + quiet) * scale,
          x2: (column + quiet + 1) * scale - 1,
          y2: (row + quiet + 1) * scale - 1,
          color: image.ColorRgb8(0, 0, 0),
        );
      }
  final bytes = image.encodePng(bitmap);
  final reopened = image.decodePng(bytes);
  if (reopened == null || reopened.width != side || reopened.height != side)
    throw const FormatException('QR PNG verification failed');
  return bytes;
}

String qrSvg(String value) {
  final matrix = qrMatrix(value),
      side = matrix.length + 8,
      path = StringBuffer();
  for (var row = 0; row < matrix.length; row++)
    for (var column = 0; column < matrix.length; column++)
      if (matrix[row][column]) path.write('M${column + 4} ${row + 4}h1v1h-1z');
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $side $side" width="${side * 8}" height="${side * 8}" shape-rendering="crispEdges"><rect width="$side" height="$side" fill="white"/><path d="$path" fill="black"/></svg>';
}

Future<Uint8List> qrPdf(String value) async {
  final matrix = qrMatrix(value), count = matrix.length;
  final document = pw.Document(
    compress: false,
    version: pdf.PdfVersion.pdf_1_4,
  );
  document.addPage(
    pw.Page(
      pageFormat: const pdf.PdfPageFormat(420, 420),
      margin: const pw.EdgeInsets.all(30),
      build: (_) => pw.CustomPaint(
        size: const pdf.PdfPoint(360, 360),
        painter: (canvas, size) {
          final scale = size.x / (count + 8);
          canvas.setFillColor(pdf.PdfColors.white);
          canvas.drawRect(0, 0, size.x, size.y);
          canvas.fillPath();
          canvas.setFillColor(pdf.PdfColors.black);
          for (var row = 0; row < count; row++)
            for (var column = 0; column < count; column++)
              if (matrix[row][column])
                canvas.drawRect(
                  (column + 4) * scale,
                  size.y - (row + 5) * scale,
                  scale,
                  scale,
                );
          canvas.fillPath();
        },
      ),
    ),
  );
  final bytes = await document.save();
  verifyQrPdf(bytes);
  return bytes;
}

/// Structural reopening for our uncompressed one-page PDF output: inspect trailer,
/// classic xref offsets and object references. This is deliberately not a general
/// PDF importer and does not claim to validate arbitrary third-party PDFs.
void verifyQrPdf(Uint8List bytes) {
  if (bytes.length < 100 || bytes.length > 2000000)
    throw const FormatException('Invalid QR PDF size');
  final source = latin1.decode(bytes),
      trailer = RegExp(r'startxref\s+(\d+)\s+%%EOF\s*$').firstMatch(source);
  if (!source.startsWith('%PDF-1.4') || trailer == null)
    throw const FormatException('Invalid QR PDF header or trailer');
  final offset = int.parse(trailer[1]!);
  if (offset < 0 ||
      offset >= source.length ||
      !source.substring(offset).startsWith('xref'))
    throw const FormatException('Invalid QR PDF xref');
  final xref = source.substring(offset),
      sections = RegExp(
        r'(\d+) (\d+)\r?\n((?:\d{10} \d{5} [nf] ?\r?\n)+)',
      ).allMatches(xref);
  var checked = 0;
  for (final section in sections) {
    final first = int.parse(section[1]!),
        count = int.parse(section[2]!),
        rows = section[3]!.trimRight().split(RegExp(r'\r?\n'));
    if (rows.length != count)
      throw const FormatException('Invalid QR PDF xref count');
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i].split(RegExp(r' +'));
      if (entry[2] != 'n') continue;
      final start = int.parse(entry[0]), generation = int.parse(entry[1]);
      if (start >= source.length ||
          !source.substring(start).startsWith('${first + i} $generation obj'))
        throw const FormatException('QR PDF xref points outside object');
      checked++;
    }
  }
  if (checked < 3 ||
      !RegExp(r'/Type\s*/Catalog\b').hasMatch(source) ||
      !RegExp(r'/Type\s*/Pages\b').hasMatch(source) ||
      RegExp(r'/Type\s*/Page\b').allMatches(source).length != 1 ||
      !RegExp(r'/Count\s+1\b').hasMatch(source) ||
      !source.contains('/MediaBox'))
    throw const FormatException('Invalid QR PDF page structure');
}
