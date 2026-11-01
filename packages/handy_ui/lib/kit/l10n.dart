import 'package:flutter/widgets.dart';

String tr(BuildContext context, String en, String vi) =>
    Localizations.localeOf(context).languageCode == 'vi' ? vi : en;

/// Groups a plain number for reading ("11478623.25" → "11,478,623.25", or
/// "11.478.623,25" in Vietnamese). A trailing unit is kept. Anything that is
/// not a plain number (dates, codes) is returned unchanged. Copy and export
/// keep the engine's raw value.
String formatFigure(BuildContext context, String raw) {
  final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?( .*)?$').firstMatch(raw);
  if (m == null) return raw;
  final vi = Localizations.localeOf(context).languageCode == 'vi';
  final digits = m[2]!, out = StringBuffer(m[1]!);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(vi ? '.' : ',');
    out.write(digits[i]);
  }
  if (m[3] != null) out.write('${vi ? ',' : '.'}${m[3]}');
  return '$out${m[4] ?? ''}';
}

const _accented =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _plain =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Lower case without Vietnamese diacritics, for search that forgives
/// missing accents ("may tinh" finds "Máy tính").
String foldAccents(String s) {
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = _accented.indexOf(ch);
    out.write(i < 0 ? ch : _plain[i]);
  }
  return out.toString();
}

/// An error in the reader's language. Messages written "English / Tiếng Việt"
/// are split; anything else is shown as it came, without the class prefix.
String errorText(BuildContext c, Object e) {
  final raw = e is FormatException
      ? e.message
      : '$e'.replaceFirst(RegExp(r'^(Exception|Bad state): '), '');
  final parts = raw.split(' / ');
  return parts.length == 2 ? tr(c, parts[0], parts[1]) : raw;
}
