import 'dart:convert';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../security/app_lock.dart' show appLockKey;

/// What the share sheet may know of the library, kept on the device by the
/// app after each change: the collections' names, colours, marks and how
/// many links each holds, and the person's theme, language and settings.
/// Never a link. With the app lock on, no collection is listed.
String sheetSnapshot(
  SaveLibrary l,
  Map<String, dynamic> prefs, {
  String theme = 'system',
  String locale = 'system',
}) {
  final locked = prefs[appLockKey] == true;
  final count = <String, int>{};
  for (final b in l.bookmarks) {
    final id = b.collectionId;
    if (id != null) count[id] = (count[id] ?? 0) + 1;
  }
  return jsonEncode({
    'v': 1,
    'locked': locked,
    'read': prefs['automaticMetadata'] != false,
    'theme': theme,
    'locale': locale,
    'collections': locked
        ? const []
        : [
            for (final c in l.collections)
              {...c.toJson(), 'count': count[c.id] ?? 0},
          ],
  });
}

/// The snapshot as the share sheet reads it.
class SheetSnapshot {
  final bool locked, read;
  final String theme, locale;

  /// The collections only (no links), so the app's tree order and
  /// colours apply unchanged.
  final SaveLibrary library;
  final Map<String, int> counts;

  SheetSnapshot({
    this.locked = false,
    this.read = true,
    this.theme = 'system',
    this.locale = 'system',
    SaveLibrary? library,
    this.counts = const {},
  }) : library = library ?? SaveLibrary();

  /// Before the app has ever written one, or when it cannot be read: no
  /// collections, everything else as a new install has it.
  factory SheetSnapshot.parse(String? json) {
    if (json == null || json.isEmpty) return SheetSnapshot();
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      final collections = <SaveCollection>[];
      final counts = <String, int>{};
      for (final raw in j['collections'] as List? ?? const []) {
        final c = SaveCollection.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        collections.add(c);
        counts[c.id] = raw['count'] is int ? raw['count'] as int : 0;
      }
      return SheetSnapshot(
        locked: j['locked'] == true,
        read: j['read'] != false,
        theme: j['theme'] as String? ?? 'system',
        locale: j['locale'] as String? ?? 'system',
        library: SaveLibrary(collections: collections),
        counts: counts,
      );
    } catch (_) {
      return SheetSnapshot();
    }
  }
}
