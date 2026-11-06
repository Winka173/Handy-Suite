import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a person stopped in one text: the block at the top of the screen
/// and how far into that block (0 to 1), so a new text size lands on the
/// same sentence instead of the same pixel.
class ReaderSpot {
  final int block;
  final double into;
  const ReaderSpot(this.block, this.into);
  bool get atStart => block == 0 && into < .02;
}

/// A short fingerprint of a text's words. A copy saved again, or a live
/// page that changed, gets a new one, and an old spot no longer applies.
String copyVersion(ReadingCopy r) {
  final text = [for (final b in r.blocks) '${b.kind}\u0001${b.text}'];
  return sha256
      .convert(utf8.encode(text.join('\u0002')))
      .toString()
      .substring(0, 16);
}

/// One text value kept on this device.
abstract interface class SpotStore {
  Future<String?> read();
  Future<void> write(String text);
}

/// The device's own preferences: never inside the library, never in a
/// backup or a sync folder. The key keeps the app's old name on purpose.
class DeviceSpotStore implements SpotStore {
  static const key = 'handy-save-reader-spots-v1';
  SharedPreferencesAsync? _prefs;
  SharedPreferencesAsync get _p => _prefs ??= SharedPreferencesAsync();
  @override
  Future<String?> read() => _p.getString(key);
  @override
  Future<void> write(String text) => _p.setString(key, text);
}

/// For tests and for a device whose preferences cannot be opened.
class MemorySpotStore implements SpotStore {
  String? text;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String value) async => text = value;
}

/// Remembers the reading spot per item and per copy version, for the
/// [keep] items read most recently. A convenience only: anything that goes
/// wrong here is forgotten quietly and the text opens at its start.
class ReadingPositions {
  ReadingPositions(this.store);

  /// The app's instance; tests swap it for one over [MemorySpotStore].
  static ReadingPositions instance = ReadingPositions(DeviceSpotStore());
  static const keep = 300;
  final SpotStore store;
  Map<String, Map<String, Object?>>? _spots;
  String? _pending;
  bool _writing = false;

  Future<Map<String, Map<String, Object?>>> _load() async {
    if (_spots != null) return _spots!;
    final spots = <String, Map<String, Object?>>{};
    try {
      final raw = await store.read();
      final map = raw == null ? null : jsonDecode(raw);
      if (map is Map) {
        for (final e in map.entries) {
          final v = e.value;
          if (e.key is String &&
              (e.key as String).length <= 200 &&
              v is Map &&
              v['v'] is String &&
              v['b'] is int &&
              v['f'] is num &&
              v['t'] is int) {
            spots[e.key as String] = Map<String, Object?>.from(v);
          }
        }
      }
    } catch (_) {
      // Unreadable or unavailable: start without remembered spots.
    }
    return _spots = spots;
  }

  /// The spot saved for [id] in this [version] of its text, or null.
  Future<ReaderSpot?> spot(String id, String version) async {
    final s = (await _load())[id];
    if (s == null || s['v'] != version) return null;
    final block = s['b'] as int;
    if (block < 0) return null;
    return ReaderSpot(block, (s['f'] as num).toDouble().clamp(0, 1));
  }

  /// Saves [spot] (or forgets it when the reader is back at the start).
  Future<void> remember(String id, String version, ReaderSpot? spot) async {
    final spots = await _load();
    if (spot == null || spot.atStart) {
      if (spots.remove(id) == null) return;
    } else {
      // Most recent last: the map keeps insertion order.
      spots.remove(id);
      spots[id] = {
        'v': version,
        'b': spot.block,
        'f': double.parse(spot.into.toStringAsFixed(3)),
        't': DateTime.now().millisecondsSinceEpoch,
      };
      while (spots.length > keep) {
        spots.remove(spots.keys.first);
      }
    }
    _pending = jsonEncode(spots);
    await _flush();
  }

  /// Writes the newest map; a write asked for meanwhile follows it.
  Future<void> _flush() async {
    if (_writing) return;
    _writing = true;
    try {
      while (_pending != null) {
        final text = _pending!;
        _pending = null;
        try {
          await store.write(text);
        } catch (_) {}
      }
    } finally {
      _writing = false;
    }
  }
}
