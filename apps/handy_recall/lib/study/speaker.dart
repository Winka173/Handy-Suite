import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads card text aloud with the voices the device already has. Offline
/// wherever the system voice is (Android, iOS and Windows voices usually
/// are; a browser may use an online voice).
abstract class Speaker {
  /// Languages the device has a voice for, as BCP 47 tags ("ja-JP"), sorted.
  /// Empty when it has none.
  Future<List<String>> languages();

  /// Reads [text] in [language]; false when no voice for it is installed.
  Future<bool> speak(String text, String language);

  Future<void> stop();
}

/// The closest of [available] to [wanted]: the same tag, else the same
/// language in another region ("en-GB" for "en-US"), else null.
String? matchLanguage(String wanted, List<String> available) {
  final w = wanted.replaceAll('_', '-').toLowerCase();
  final base = w.split('-').first;
  String? sameBase;
  for (final a in available) {
    final x = a.replaceAll('_', '-').toLowerCase();
    if (x == w) return a;
    if (sameBase == null && x.split('-').first == base) sameBase = a;
  }
  return sameBase;
}

/// [Speaker] over `flutter_tts`. Created lazily so tests and platforms
/// without a voice never touch the plugin until something is read.
class DeviceSpeaker implements Speaker {
  FlutterTts? _tts;
  List<String>? _languages;
  FlutterTts get _engine => _tts ??= FlutterTts();

  @override
  Future<List<String>> languages() async {
    if (_languages case final known? when known.isNotEmpty) return known;
    var found = await _read();
    // Browsers load their voices after the page; ask once more.
    if (found.isEmpty && kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      found = await _read();
    }
    return _languages = found;
  }

  Future<List<String>> _read() async {
    try {
      final raw = await _engine.getLanguages;
      final tags = <String>{
        if (raw is List)
          for (final l in raw)
            if (l is String && l.trim().isNotEmpty)
              l.trim().replaceAll('_', '-'),
      };
      return tags.toList()..sort();
    } catch (_) {
      // No engine, or a platform that cannot list voices: nothing to offer.
      return const [];
    }
  }

  @override
  Future<bool> speak(String text, String language) async {
    final voice = matchLanguage(language, await languages());
    if (voice == null || text.trim().isEmpty) return false;
    try {
      await _engine.stop();
      await _engine.setLanguage(voice);
      await _engine.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // Nothing is playing.
    }
  }
}
