import 'dart:convert';

class SubtitleCue {
  final int startMs, endMs;
  final String text;
  const SubtitleCue(this.startMs, this.endMs, this.text);
}

int _time(String text) {
  final match = RegExp(
    r'^(?:(\d{1,3}):)?(\d{2}):(\d{2})[,.](\d{3})$',
  ).firstMatch(text);
  if (match == null) throw const FormatException('Invalid subtitle timestamp');
  final h = int.parse(match[1] ?? '0'),
      m = int.parse(match[2]!),
      s = int.parse(match[3]!);
  if (m > 59 || s > 59) throw const FormatException('Invalid subtitle time');
  return ((h * 60 + m) * 60 + s) * 1000 + int.parse(match[4]!);
}

List<SubtitleCue> parseSubtitles(String source) {
  if (source.length > 1000000 || utf8.encode(source).length > 1000000)
    throw const FormatException('Subtitle exceeds 1 MB');
  var text = source
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceFirst('\uFEFF', '')
      .trim();
  if (text.startsWith('WEBVTT'))
    text = text
        .substring(text.indexOf('\n') < 0 ? text.length : text.indexOf('\n'))
        .trim();
  final result = <SubtitleCue>[];
  if (text.isEmpty) return result;
  for (final block in text.split(RegExp(r'\n\s*\n'))) {
    final lines = block.split('\n');
    if (lines.first.startsWith('NOTE')) continue;
    final timing = lines.indexWhere((l) => l.contains('-->'));
    if (timing < 0 || timing > 1)
      throw const FormatException('Cue timing missing');
    final parts = lines[timing].split(RegExp(r'\s+-->\s+'));
    if (parts.length != 2) throw const FormatException('Invalid cue timing');
    final start = _time(parts[0].trim()), end = _time(parts[1].trim());
    final body = lines.skip(timing + 1).join('\n');
    if (end <= start || body.isEmpty)
      throw const FormatException('Invalid subtitle cue');
    result.add(SubtitleCue(start, end, body));
    if (result.length > 10000)
      throw const FormatException('Subtitle cue limit');
  }
  return List.unmodifiable(result);
}

String _stamp(int ms, String separator) {
  if (ms < 0 || ms > 3599999999)
    throw const FormatException('Subtitle offset out of range');
  String pad(int v, int n) => v.toString().padLeft(n, '0');
  return '${pad(ms ~/ 3600000, 2)}:${pad(ms ~/ 60000 % 60, 2)}:${pad(ms ~/ 1000 % 60, 2)}$separator${pad(ms % 1000, 3)}';
}

String renderSubtitles(
  List<SubtitleCue> cues, {
  bool vtt = false,
  int offsetMs = 0,
}) {
  if (cues.length > 10000) throw const FormatException('Subtitle cue limit');
  final blocks = <String>[];
  for (var i = 0; i < cues.length; i++) {
    final cue = cues[i],
        start = cue.startMs + offsetMs,
        end = cue.endMs + offsetMs;
    if (end <= start || cue.text.isEmpty || cue.text.contains('\n\n'))
      throw const FormatException('Invalid subtitle cue');
    blocks.add(
      '${vtt ? '' : '${i + 1}\n'}${_stamp(start, vtt ? '.' : ',')} --> ${_stamp(end, vtt ? '.' : ',')}\n${cue.text}',
    );
  }
  final output = '${vtt ? 'WEBVTT\n\n' : ''}${blocks.join('\n\n')}\n';
  if (output.length > 1000000 || utf8.encode(output).length > 1000000)
    throw const FormatException('Subtitle output exceeds 1 MB');
  return output;
}
