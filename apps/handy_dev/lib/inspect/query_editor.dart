import 'package:flutter/widgets.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

/// The query parameters of one URL while they are edited. The engine
/// rebuilds the URL; this only keeps the rows.
class QueryEditor extends ChangeNotifier {
  final UrlParts parts;
  final rows = <(TextEditingController, TextEditingController)>[];
  QueryEditor(this.parts) {
    for (final (n, v) in parts.query) {
      _add(n, v);
    }
  }

  void _add(String name, String value) {
    final row = (
      TextEditingController(text: name),
      TextEditingController(text: value),
    );
    row.$1.addListener(notifyListeners);
    row.$2.addListener(notifyListeners);
    rows.add(row);
  }

  List<(String, String)> get pairs => [
    for (final (n, v) in rows) (n.text, v.text),
  ];

  bool get edited {
    final p = pairs;
    if (p.length != parts.query.length) return true;
    for (var i = 0; i < p.length; i++) {
      if (p[i] != parts.query[i]) return true;
    }
    return false;
  }

  bool get full => rows.length >= maxQueryParameters;

  /// The URL with the rows as its query.
  String get url => parts.rebuild(pairs);

  void add() {
    if (full) return;
    _add('', '');
    notifyListeners();
  }

  void remove(int i) {
    final (n, v) = rows.removeAt(i);
    n.dispose();
    v.dispose();
    notifyListeners();
  }

  void reset() {
    for (final (n, v) in rows) {
      n.dispose();
      v.dispose();
    }
    rows.clear();
    for (final (n, v) in parts.query) {
      _add(n, v);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final (n, v) in rows) {
      n.dispose();
      v.dispose();
    }
    super.dispose();
  }
}
