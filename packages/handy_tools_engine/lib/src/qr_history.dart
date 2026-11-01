part of '../handy_tools_engine.dart';

/// Preference envelope; content validation reuses the existing QR history parser.
class QrHistory {
  final bool enabled;
  final List<Map<String, String>> entries;
  QrHistory({
    this.enabled = false,
    List<Map<String, String>> entries = const [],
  }) : entries = List.unmodifiable(
         parseQrHistory(
           jsonEncode(entries),
         ).map((e) => Map<String, String>.unmodifiable(e)),
       ) {
    if (!enabled && entries.isNotEmpty)
      throw const FormatException('Disabled QR history must be empty');
  }
  factory QrHistory.parse(String source) {
    if (utf8.encode(source).length > 300000)
      throw const FormatException('QR history exceeds 300 KB');
    final value = jsonDecode(source);
    if (value is! Map ||
        value['format'] != 'handy-tools-qr-history' ||
        value['version'] != 1 ||
        value['enabled'] is! bool ||
        value['entries'] is! List)
      throw const FormatException('Unsupported QR history');
    return QrHistory(
      enabled: value['enabled'],
      entries: parseQrHistory(jsonEncode(value['entries'])),
    );
  }
  String serialize() => jsonEncode({
    'format': 'handy-tools-qr-history',
    'version': 1,
    'enabled': enabled,
    'entries': entries,
  });
  QrHistory add(String text, {String? at}) {
    if (!enabled) return this;
    final entry = {
      'text': text,
      'at': at ?? DateTime.now().toUtc().toIso8601String(),
    };
    return QrHistory(
      enabled: true,
      entries: [
        entry,
        ...entries.where((e) => e['text'] != text),
      ].take(50).toList(),
    );
  }

  QrHistory remove(int index) {
    if (index < 0 || index >= entries.length)
      throw const FormatException('Invalid history entry');
    return QrHistory(enabled: enabled, entries: [...entries]..removeAt(index));
  }
}
