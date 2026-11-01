import 'package:re2/re2.dart';
import 'dart:convert';

const supported = true;
bool test(String text, String pattern) {
  final compiled = Re2(pattern, maxBytes: 4194304);
  try {
    return compiled.hasMatch(text);
  } finally {
    compiled.dispose();
  }
}

Map<String, Object?> matches(String text, String pattern) {
  final compiled = Re2(pattern, maxBytes: 4194304);
  try {
    final output = <Map<String, Object?>>[];
    var outputBytes = 0, groupValues = 0;
    for (final match in compiled.allMatches(text)) {
      final groups = <String?>[];
      for (var i = 0; i <= match.groupCount; i++) {
        final group = match.group(i);
        outputBytes += group == null ? 4 : utf8.encode(group).length + 8;
        if (++groupValues > 20000 || outputBytes > 1500000)
          throw const FormatException('RE2 capture output limit exceeded');
        groups.add(group);
      }
      output.add({'start': match.start, 'end': match.end, 'groups': groups});
      if (output.length == 1000) break;
    }
    return {
      'engine': 'RE2 (no backreferences or lookaround)',
      'matches': output,
      'truncated': output.length == 1000,
    };
  } finally {
    compiled.dispose();
  }
}
