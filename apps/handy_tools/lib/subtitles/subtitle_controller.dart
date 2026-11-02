import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_media_engine/handy_media_engine.dart';

/// A problem in words, in both languages (engine messages read the same).
typedef Problem = (String en, String vi);

/// Converts SRT ↔ WebVTT and shifts timing, using Handy Media's subtitle
/// engine. Nothing leaves without [verified]: the whole file is parsed,
/// rendered, parsed again and compared cue by cue.
class SubtitleController extends ChangeNotifier {
  final Duration wait;
  SubtitleController({this.wait = const Duration(milliseconds: 250)});

  String _source = '', _shift = '0';
  String format = 'srt';
  bool _formatChosen = false;
  List<SubtitleCue> cues = const [];
  int offset = 0;
  Problem? problem;
  String? output;

  /// The format the source is written in, once it has been read.
  String? sourceFormat;
  Timer? _timer;

  String get source => _source;
  String get shift => _shift;
  String get extension => format;
  String get mimeType => format == 'vtt' ? 'text/vtt' : 'application/x-subrip';
  String get fileName => 'handy-subtitles.$format';

  /// The first cue would start before zero with the current shift.
  bool get startsBeforeZero =>
      cues.isNotEmpty && cues.first.startMs + offset < 0;

  void setSource(String text) {
    _source = text;
    _later();
  }

  void setShift(String text) {
    _shift = text;
    _later();
  }

  void nudge(int by) {
    _shift = '${(int.tryParse(_shift.trim()) ?? 0) + by}';
    _later();
  }

  void setFormat(String next) {
    format = next == 'vtt' ? 'vtt' : 'srt';
    _formatChosen = true;
    _later();
  }

  /// A file was opened: read it now, no waiting.
  void load(String text) {
    _timer?.cancel();
    _source = text;
    read();
  }

  void _later() {
    _timer?.cancel();
    output = null;
    notifyListeners();
    _timer = Timer(wait, read);
  }

  /// Reads the source and renders it with the shift; any fault becomes one
  /// sentence and no output.
  void read() {
    _timer?.cancel();
    output = null;
    problem = null;
    final parsed = int.tryParse(_shift.trim());
    if (_source.trim().isEmpty) {
      cues = const [];
      sourceFormat = null;
      notifyListeners();
      return;
    }
    try {
      cues = parseSubtitles(_source);
      sourceFormat =
          _source.trimLeft().replaceFirst('﻿', '').startsWith('WEBVTT')
          ? 'vtt'
          : 'srt';
      // Shifting alone keeps the file's own format until the user picks one.
      if (!_formatChosen) format = sourceFormat!;
      if (parsed == null || parsed.abs() > 86400000) {
        problem = (
          'Shift must be whole milliseconds, up to 24 hours either way',
          'Độ dời phải là số mili giây nguyên, tối đa 24 giờ mỗi chiều',
        );
      } else {
        offset = parsed;
        if (cues.isEmpty) {
          problem = (
            'No subtitle lines in this file',
            'Tệp này không có câu phụ đề nào',
          );
        } else if (startsBeforeZero) {
          problem = (
            'The first line would start before 0:00. Shift it less.',
            'Câu đầu sẽ bắt đầu trước 0:00. Hãy dời ít hơn.',
          );
        } else {
          output = _render();
        }
      }
    } on FormatException catch (e) {
      cues = const [];
      problem = (e.message, e.message);
    }
    notifyListeners();
  }

  String _render() {
    final text = renderSubtitles(cues, vtt: format == 'vtt', offsetMs: offset);
    final back = parseSubtitles(text);
    if (back.length != cues.length) {
      throw const FormatException('Subtitle output could not be verified');
    }
    for (var i = 0; i < cues.length; i++) {
      if (back[i].startMs != cues[i].startMs + offset ||
          back[i].endMs != cues[i].endMs + offset ||
          back[i].text != cues[i].text) {
        throw FormatException('Line ${i + 1} changed while converting');
      }
    }
    return text;
  }

  /// The whole file, checked again right now; throws instead of returning
  /// anything partial.
  String verified() {
    read();
    final text = output;
    if (text == null) {
      throw FormatException(problem?.$1 ?? 'Nothing to save');
    }
    return text;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// `01:02.345`, or `1:02:03.456` past an hour; a sign when negative.
String subtitleClock(int ms) {
  final sign = ms < 0 ? '−' : '';
  ms = ms.abs();
  final h = ms ~/ 3600000, m = ms ~/ 60000 % 60, s = ms ~/ 1000 % 60;
  final rest = (ms % 1000).toString().padLeft(3, '0');
  String two(int n) => n.toString().padLeft(2, '0');
  return '$sign${h > 0 ? '${two(h)}:' : ''}${two(m)}:${two(s)}.$rest';
}
