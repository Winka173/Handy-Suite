part of '../handy_tools_engine.dart';

class VietQrBank {
  /// NAPAS bank identification number (6 digits).
  final String bin;
  final String code, shortName, name;
  const VietQrBank(this.bin, this.code, this.shortName, this.name);
}

VietQrBank? vietQrBank(String bin) {
  for (final b in vietQrBanks) {
    if (b.bin == bin) return b;
  }
  return null;
}

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) over the UTF-8 bytes, as
/// four upper-case hex digits. EMVCo QR tag 63.
String crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in utf8.encode(data)) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}

String _tlv(String id, String value) {
  if (value.length > 99) throw const FormatException('QR field too long');
  return '$id${value.length.toString().padLeft(2, '0')}$value';
}

/// The transfer message as banks accept it: accents removed, letters,
/// digits and spaces only, at most 25 characters.
String vietQrMessage(String message) {
  final plain = removeAccents(message.trim()).replaceAll(RegExp(r'\s+'), ' ');
  if (!RegExp(r'^[A-Za-z0-9 ]*$').hasMatch(plain)) {
    throw const FormatException('Message: letters, digits and spaces only');
  }
  if (plain.length > 25) {
    throw const FormatException('Message: at most 25 characters');
  }
  return plain;
}

/// An EMVCo merchant-presented VietQR (NAPAS 247 transfer to an account):
/// GUID A000000727, the bank's BIN and the account in tag 38, service
/// QRIBFTTA, currency 704, country VN, an optional amount (tag 54, whole
/// đồng; the code is then dynamic, 12) and message (tag 62.08), CRC16.
String vietQr({
  required String bin,
  required String account,
  String amount = '',
  String message = '',
}) {
  if (!RegExp(r'^\d{6}$').hasMatch(bin)) {
    throw const FormatException('Bank BIN is 6 digits');
  }
  final acc = account.replaceAll(' ', '');
  if (!RegExp(r'^[A-Za-z0-9]{6,19}$').hasMatch(acc)) {
    throw const FormatException('Account: 6–19 letters or digits');
  }
  var money = amount.replaceAll(' ', '');
  // Grouped thousands (1.250.000 or 1,250,000) only; 1.5 stays a decimal
  // and is refused below.
  if (RegExp(r'^\d{1,3}([.,])\d{3}(\1\d{3})*$').hasMatch(money)) {
    money = money.replaceAll(RegExp(r'[.,]'), '');
  }
  if (money.isNotEmpty && !RegExp(r'^[1-9]\d{0,12}$').hasMatch(money)) {
    throw const FormatException(
      'Amount: a whole number of đồng, up to 13 digits',
    );
  }
  final note = vietQrMessage(message);
  final consumer = _tlv('00', bin) + _tlv('01', acc);
  final merchant =
      _tlv('00', 'A000000727') + _tlv('01', consumer) + _tlv('02', 'QRIBFTTA');
  final body = StringBuffer()
    ..write(_tlv('00', '01'))
    ..write(_tlv('01', money.isEmpty ? '11' : '12'))
    ..write(_tlv('38', merchant))
    ..write(_tlv('53', '704'))
    ..write(money.isEmpty ? '' : _tlv('54', money))
    ..write(_tlv('58', 'VN'))
    ..write(note.isEmpty ? '' : _tlv('62', _tlv('08', note)))
    ..write('6304');
  final payload = body.toString();
  return _qrBound(payload + crc16Ccitt(payload));
}

/// Reads a VietQR transfer payload back into its fields after checking
/// its CRC; null when [value] is not one.
({String bin, String account, String amount, String message})? readVietQr(
  String value,
) {
  if (value.length < 8 || !value.contains('A000000727')) return null;
  final body = value.substring(0, value.length - 4);
  if (!body.endsWith('6304') ||
      crc16Ccitt(body) != value.substring(value.length - 4)) {
    return null;
  }
  Map<String, String>? fields(String s) {
    final out = <String, String>{};
    var i = 0;
    while (i < s.length) {
      if (i + 4 > s.length) return null;
      final id = s.substring(i, i + 2),
          n = int.tryParse(s.substring(i + 2, i + 4));
      if (n == null || i + 4 + n > s.length) return null;
      out[id] = s.substring(i + 4, i + 4 + n);
      i += 4 + n;
    }
    return out;
  }

  final top = fields(body.substring(0, body.length - 4));
  final merchant = top == null ? null : fields(top['38'] ?? '');
  final consumer = merchant == null ? null : fields(merchant['01'] ?? '');
  if (top == null ||
      merchant == null ||
      consumer == null ||
      merchant['00'] != 'A000000727' ||
      consumer['00'] == null ||
      consumer['01'] == null) {
    return null;
  }
  final extra = fields(top['62'] ?? '');
  return (
    bin: consumer['00']!,
    account: consumer['01']!,
    amount: top['54'] ?? '',
    message: extra?['08'] ?? '',
  );
}
