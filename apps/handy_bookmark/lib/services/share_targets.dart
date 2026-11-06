import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

/// The collections to offer in the top row of the system share sheet: the
/// ones saved into most recently, then the rest in the person's own order.
/// Not sorted is never one of them: sharing to the app already goes there.
List<SaveCollection> shareTargets(SaveLibrary l, {int max = 4}) {
  final last = <String, String>{};
  for (final b in l.bookmarks) {
    final id = b.collectionId;
    if (id == null) continue;
    final seen = last[id];
    if (seen == null || b.savedAt.compareTo(seen) > 0) last[id] = b.savedAt;
  }
  final list = [...l.collections]
    ..sort((a, b) {
      final x = last[a.id], y = last[b.id];
      if (x != null && y != null) return y.compareTo(x);
      if (x != null) return -1;
      if (y != null) return 1;
      return a.position.compareTo(b.position);
    });
  return list.take(max).toList();
}
