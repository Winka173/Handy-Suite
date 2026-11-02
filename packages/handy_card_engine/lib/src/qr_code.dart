part of '../handy_card_engine.dart';

/// A QR symbol's dark modules.
class QrMatrix {
  final int size;
  final List<bool> dark;
  const QrMatrix(this.size, this.dark);
  bool at(int row, int col) => dark[row * size + col];
}

int _eccLevel(String ecc) => switch (ecc) {
  'L' => qr.QrErrorCorrectLevel.L,
  'Q' => qr.QrErrorCorrectLevel.Q,
  'H' => qr.QrErrorCorrectLevel.H,
  _ => qr.QrErrorCorrectLevel.M,
};

/// The symbol for [data] at error-correction [ecc]; throws a readable
/// FormatException when the data does not fit any QR version.
QrMatrix qrMatrix(String data, {String ecc = 'M'}) {
  if (data.isEmpty) throw const FormatException('The QR code has no content');
  try {
    final code = qr.QrCode.fromData(
      data: data,
      errorCorrectLevel: _eccLevel(ecc),
    );
    final image = qr.QrImage(code);
    final n = image.moduleCount;
    return QrMatrix(n, [
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++) image.isDark(r, c),
    ]);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Too much for one QR code; shorten it or lower error correction',
    );
  }
}

/// The dark modules as rectangles (runs merged per row) in a [size]×[size]
/// box with [quiet] modules of margin.
List<PathOp> qrPath(QrMatrix m, double size, int quiet) {
  final cell = size / (m.size + 2 * quiet);
  final ops = <PathOp>[];
  for (var r = 0; r < m.size; r++) {
    var c = 0;
    while (c < m.size) {
      if (!m.at(r, c)) {
        c++;
        continue;
      }
      final start = c;
      while (c < m.size && m.at(r, c)) c++;
      final x = (start + quiet) * cell, y = (r + quiet) * cell;
      final w = (c - start) * cell;
      ops
        ..add(MoveTo(Vec(x, y)))
        ..add(LineTo(Vec(x + w, y)))
        ..add(LineTo(Vec(x + w, y + cell)))
        ..add(LineTo(Vec(x, y + cell)))
        ..add(const ClosePath());
    }
  }
  return ops;
}

/// Whether a QR code of [sidePoints] will scan when printed: each module
/// should be at least 0.33 mm (about 0.94 pt) for phone cameras at a
/// normal distance. Returns the module size and a warning, or null.
({int modules, double moduleMm, String? warning}) qrPrintCheck(
  String data, {
  required double sidePoints,
  String ecc = 'M',
  int quiet = 4,
}) {
  final m = qrMatrix(data, ecc: ecc);
  final moduleMm = sidePoints / (m.size + 2 * quiet) / pointsPerMm;
  String? warning;
  if (moduleMm < 0.33) {
    warning =
        'Modules are ${moduleMm.toStringAsFixed(2)} mm; make the code larger, shorten the content or lower error correction';
  } else if (quiet < 2) {
    warning = 'Keep at least 2 modules of empty margin round the code';
  }
  return (modules: m.size, moduleMm: moduleMm, warning: warning);
}

/// QR payload builders. Each returns the exact text to encode.
String qrPhone(String number) =>
    telUri(number) ?? (throw const FormatException('Not a phone number'));
String qrEmail(String address, {String subject = ''}) {
  if (!isEmail(address)) throw const FormatException('Not an email address');
  return subject.isEmpty
      ? 'mailto:${address.trim()}'
      : 'mailto:${address.trim()}?subject=${Uri.encodeComponent(subject)}';
}

String qrUrl(String url) =>
    safeHttpsUrl(url) ??
    (throw const FormatException('Use an https:// address'));

/// Joining a Wi-Fi network: `WIFI:T:WPA;S:name;P:secret;;` with the
/// special characters escaped as the format asks.
String qrWifi({
  required String ssid,
  String password = '',
  String security = 'WPA',
  bool hidden = false,
}) {
  if (ssid.isEmpty || ssid.length > 64)
    throw const FormatException('Network name required');
  if (!const {'WPA', 'WEP', 'nopass'}.contains(security))
    throw const FormatException('Unknown Wi-Fi security');
  String esc(String v) =>
      v.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');
  return 'WIFI:T:$security;S:${esc(ssid)};'
      '${security == 'nopass' ? '' : 'P:${esc(password)};'}'
      '${hidden ? 'H:true;' : ''};';
}
