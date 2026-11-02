part of '../handy_tools_engine.dart';

class PasswordOptions {
  const PasswordOptions({
    this.length = 20,
    this.upper = true,
    this.lower = true,
    this.digits = true,
    this.symbols = true,
    this.excludeAmbiguous = false,
  });
  final int length;
  final bool upper, lower, digits, symbols, excludeAmbiguous;
}

/// Production entropy always comes from Random.secure. The injected callback is
/// intended for deterministic rejection-sampling tests, never a saved user option.
String generatePassword(
  PasswordOptions options, {
  int Function(int maximum)? randomInt,
}) {
  if (options.length < 8 || options.length > 128)
    throw const FormatException('Password length: 8–128');
  final groups =
      <String>[
            if (options.upper) 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
            if (options.lower) 'abcdefghijklmnopqrstuvwxyz',
            if (options.digits) '0123456789',
            if (options.symbols) '!@#\$%^&*()-_=+[]{}:,.?',
          ]
          .map(
            (g) => options.excludeAmbiguous
                ? g.replaceAll(RegExp('[0O1Il]'), '')
                : g,
          )
          .toList();
  if (groups.isEmpty)
    throw const FormatException('Select at least one character group');
  final secure = randomInt == null ? math.Random.secure() : null;
  int nextByte() {
    final value = randomInt?.call(256) ?? secure!.nextInt(256);
    if (value < 0 || value >= 256)
      throw const FormatException('Secure random source failed');
    return value;
  }

  final alphabet = groups.join(), ceiling = 256 - 256 % alphabet.length;
  var reads = 0;
  String choose() {
    while (++reads <= 100000) {
      final byte = nextByte();
      if (byte < ceiling) return alphabet[byte % alphabet.length];
    }
    throw const FormatException('Secure random source failed');
  }

  for (var tries = 0; tries < 2000; tries++) {
    final candidate = List.generate(options.length, (_) => choose()).join();
    if (groups.every((g) => candidate.split('').any(g.contains)))
      return candidate;
  }
  throw const FormatException(
    'Random source could not satisfy selected groups',
  );
}

String securePassword({
  int length = 20,
  bool upper = true,
  bool lower = true,
  bool digits = true,
  bool symbols = true,
  bool excludeAmbiguous = false,
}) => generatePassword(
  PasswordOptions(
    length: length,
    upper: upper,
    lower: lower,
    digits: digits,
    symbols: symbols,
    excludeAmbiguous: excludeAmbiguous,
  ),
);

String _cleanQr(String value, [int maximum = 500]) {
  if (value.length > maximum || RegExp(r'[\r\n\x00]').hasMatch(value))
    throw const FormatException('Invalid QR field');
  return value;
}

String _qrBound(String value) {
  if (value.isEmpty || value.length > 1200 || utf8.encode(value).length > 1800)
    throw const FormatException(
      'QR content limit: 1200 characters / 1800 UTF-8 bytes',
    );
  return value;
}

String _wifiEscape(String value) => _cleanQr(
  value,
).replaceAllMapped(RegExp(r'''[\\;,:"']'''), (m) => '\\${m[0]}');
String _cardEscape(String value) => _cleanQr(
  value,
).replaceAll('\\', '\\\\').replaceAll(';', '\\;').replaceAll(',', '\\,');
String wifiQr(
  String ssid,
  String password, [
  String security = 'WPA',
  bool hidden = false,
]) {
  if (ssid.trim().isEmpty || !['WPA', 'WEP', 'nopass'].contains(security))
    throw const FormatException('Wi-Fi name and supported security required');
  return _qrBound(
    'WIFI:T:$security;S:${_wifiEscape(ssid)};P:${security == 'nopass' ? '' : _wifiEscape(password)};H:${hidden ? 'true' : 'false'};;',
  );
}

String contactQr(String name, String phone, String email) {
  if (name.trim().isEmpty) throw const FormatException('Contact name required');
  if (email.isNotEmpty &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))
    throw const FormatException('Invalid email');
  return _qrBound(
    [
      'BEGIN:VCARD',
      'VERSION:3.0',
      'FN:${_cardEscape(name)}',
      'TEL:${_cleanQr(phone)}',
      'EMAIL:${_cleanQr(email)}',
      'END:VCARD',
    ].join('\r\n'),
  );
}

DateTime _utcEvent(String source) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').hasMatch(source))
    throw const FormatException('Use a real UTC date YYYY-MM-DDTHH:mm:ssZ');
  final date = DateTime.tryParse(source);
  if (date == null ||
      date.toIso8601String() != source.replaceFirst('Z', '.000Z'))
    throw const FormatException('Invalid UTC calendar date');
  return date;
}

String eventQr(String title, String start, String end, String location) {
  if (title.trim().isEmpty) throw const FormatException('Event title required');
  final a = _utcEvent(start), b = _utcEvent(end);
  if (!b.isAfter(a)) throw const FormatException('Event ends after start');
  String stamp(String value) => value.replaceAll(RegExp('[-:]'), '');
  return _qrBound(
    [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Handy Suite//QR//EN',
      'BEGIN:VEVENT',
      'SUMMARY:${_cardEscape(title)}',
      'DTSTART:${stamp(start)}',
      'DTEND:${stamp(end)}',
      'LOCATION:${_cardEscape(location)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n'),
  );
}

Map<String, String> qrPreview(String value) {
  _qrBound(value);
  if (value.toUpperCase().startsWith('WIFI:'))
    return {
      'kind': 'Wi-Fi',
      'warning':
          'Contains Wi-Fi credentials. Share only with intended recipients.',
    };
  if (value.toUpperCase().startsWith('BEGIN:VCARD'))
    return {
      'kind': 'Contact',
      'warning': 'Contains personal contact information.',
    };
  if (value.toUpperCase().startsWith('BEGIN:VCALENDAR'))
    return {
      'kind': 'Event',
      'warning': 'Review event time and location before adding.',
    };
  if (readVietQr(value) != null)
    return {
      'kind': 'VietQR',
      'warning':
          'Bank transfer. Check the account holder name in your bank app before sending.',
    };
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme)
    return {
      'kind': 'URL',
      'warning':
          uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty
          ? 'Review destination: ${uri.host}. Links never open automatically.'
          : 'Potentially unsafe scheme or embedded credentials. Links never open automatically.',
    };
  return {
    'kind': 'Text',
    'warning': 'Review content before copying or sharing.',
  };
}

List<Map<String, String>> parseQrHistory(String source) {
  _bounded(source, 150000);
  final value = jsonDecode(source);
  if (value is! List || value.length > 50)
    throw const FormatException('Invalid QR history');
  return value.map((item) {
    if (item is! Map ||
        item['text'] is! String ||
        item['at'] is! String ||
        DateTime.tryParse(item['at'] as String) == null)
      throw const FormatException('Invalid QR history entry');
    _qrBound(item['text'] as String);
    return {'text': item['text'] as String, 'at': item['at'] as String};
  }).toList();
}
