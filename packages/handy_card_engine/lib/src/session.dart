part of '../handy_card_engine.dart';

/// One undoable step: the document and selection before and after it.
class HistoryEntry {
  final String label;
  final CardDocument before, after;
  final Set<String> selectionBefore, selectionAfter;
  final String pageBefore, pageAfter;
  final String? coalesce;
  final DateTime at;
  const HistoryEntry({
    required this.label,
    required this.before,
    required this.after,
    required this.selectionBefore,
    required this.selectionAfter,
    required this.pageBefore,
    required this.pageAfter,
    required this.coalesce,
    required this.at,
  });
}

/// The editing state of one open design: the document, the side being
/// edited, the selection, the group entered for editing and the history.
///
/// Documents are immutable and share unchanged branches, so keeping every
/// step's before and after costs little; [limit] bounds the history. A
/// drag is a transaction: [begin], any number of [preview]s computed from
/// the state at [begin] (so nothing drifts), then one [commit].
class EditorSession {
  final ElementRegistry registry;
  final int limit;
  final DateTime Function() clock;
  CardDocument document;
  String page;
  Set<String> selection = {};
  String? entered;
  final _past = <HistoryEntry>[], _future = <HistoryEntry>[];
  int _revision = 0, _saved = 0;
  final _listeners = <void Function()>[];

  EditorSession(
    this.document, {
    required this.registry,
    this.limit = 200,
    DateTime Function()? clock,
    String? page,
  }) : clock = clock ?? DateTime.now,
       page = page ?? document.pages.first.id;

  void addListener(void Function() f) => _listeners.add(f);
  void removeListener(void Function() f) => _listeners.remove(f);
  void _notify() {
    for (final f in List.of(_listeners)) f();
  }

  CardPage get current => document.page(page);
  List<CardElement> get elements => current.elements;
  bool get dirty => _revision != _saved;
  int get revision => _revision;
  bool get canUndo => _past.isNotEmpty;
  bool get canRedo => _future.isNotEmpty;
  String? get undoLabel => _past.isEmpty ? null : _past.last.label;
  String? get redoLabel => _future.isEmpty ? null : _future.last.label;
  int get historyLength => _past.length;
  bool get inTransaction => _tx != null;

  /// Called after the document was written; edits after it make it dirty.
  void markSaved([int? revision]) {
    _saved = revision ?? _revision;
    _notify();
  }

  /// Selected elements that still exist, top-most only.
  Set<String> get selected => topmostOnly(
    elements,
    selection.where((id) => findElement(elements, id) != null).toSet(),
  );

  CardElement? get single =>
      selected.length == 1 ? findElement(elements, selected.first) : null;

  void select(Iterable<String> ids, {bool add = false}) {
    selection = add ? {...selection, ...ids} : ids.toSet();
    _notify();
  }

  void toggle(String id) {
    selection = selection.contains(id)
        ? ({...selection}..remove(id))
        : {...selection, id};
    _notify();
  }

  void clearSelection() {
    if (selection.isEmpty && entered == null) return;
    selection = {};
    entered = null;
    _notify();
  }

  /// Double-click into a group: its children become selectable one by one.
  void enter(String? group) {
    entered = group;
    _notify();
  }

  void showPage(String id) {
    if (page == id) return;
    page = id;
    selection = {};
    entered = null;
    _notify();
  }

  /// Applies [change] as one undo step labelled [label]. A step with the
  /// same [coalesce] key less than 1.5 s after the previous one merges into
  /// it, so typing a word or nudging with the arrows is one undo.
  void apply(
    String label,
    CardDocument Function(CardDocument) change, {
    Set<String>? select,
    String? coalesce,
  }) {
    if (_tx != null) throw StateError('Finish the transaction first');
    final before = document, selectionBefore = selection;
    final after = change(document);
    if (identical(after, before)) return;
    after.validate();
    document = after;
    if (select != null) selection = select;
    _record(label, before, selectionBefore, page, coalesce);
  }

  void _record(
    String label,
    CardDocument before,
    Set<String> selectionBefore,
    String pageBefore,
    String? coalesce,
  ) {
    final now = clock();
    final last = _past.isEmpty ? null : _past.last;
    if (coalesce != null &&
        last != null &&
        last.coalesce == coalesce &&
        _future.isEmpty &&
        now.difference(last.at) < const Duration(milliseconds: 1500)) {
      _past[_past.length - 1] = HistoryEntry(
        label: last.label,
        before: last.before,
        after: document,
        selectionBefore: last.selectionBefore,
        selectionAfter: selection,
        pageBefore: last.pageBefore,
        pageAfter: page,
        coalesce: coalesce,
        at: now,
      );
    } else {
      _past.add(
        HistoryEntry(
          label: label,
          before: before,
          after: document,
          selectionBefore: selectionBefore,
          selectionAfter: selection,
          pageBefore: pageBefore,
          pageAfter: page,
          coalesce: coalesce,
          at: now,
        ),
      );
      if (_past.length > limit) _past.removeAt(0);
    }
    // A new edit after an undo ends the old future.
    _future.clear();
    _revision++;
    _notify();
  }

  ({CardDocument doc, Set<String> sel, String label})? _tx;

  /// Starts a drag, a resize or any other gesture that ends in one step.
  void begin(String label) {
    if (_tx != null) throw StateError('A transaction is already open');
    _tx = (doc: document, sel: selection, label: label);
  }

  /// Shows [change] applied to the document as it was at [begin].
  void preview(CardDocument Function(CardDocument base) change) {
    final tx = _tx ?? (throw StateError('No transaction'));
    document = change(tx.doc);
    _notify();
  }

  /// Ends the gesture as one undo step (or none, if nothing changed).
  void commit() {
    final tx = _tx ?? (throw StateError('No transaction'));
    _tx = null;
    if (identical(document, tx.doc) ||
        jsonEncode(document.toJson()) == jsonEncode(tx.doc.toJson())) {
      document = tx.doc;
      _notify();
      return;
    }
    document.validate();
    _record(tx.label, tx.doc, tx.sel, page, null);
  }

  /// Abandons the gesture; the document is as it was at [begin].
  void cancel() {
    final tx = _tx;
    if (tx == null) return;
    _tx = null;
    document = tx.doc;
    selection = tx.sel;
    _notify();
  }

  void undo() {
    if (_tx != null) cancel();
    if (_past.isEmpty) return;
    final e = _past.removeLast();
    _future.add(e);
    document = e.before;
    selection = e.selectionBefore;
    page = document.pages.any((p) => p.id == e.pageBefore)
        ? e.pageBefore
        : document.pages.first.id;
    entered = null;
    _revision++;
    _notify();
  }

  void redo() {
    if (_tx != null) cancel();
    if (_future.isEmpty) return;
    final e = _future.removeLast();
    _past.add(e);
    document = e.after;
    selection = e.selectionAfter;
    page = document.pages.any((p) => p.id == e.pageAfter)
        ? e.pageAfter
        : document.pages.first.id;
    entered = null;
    _revision++;
    _notify();
  }

  /// Replaces the document without history (after a reload or a restore);
  /// the history is cleared because its steps no longer apply.
  void reset(CardDocument next, {bool saved = true}) {
    _tx = null;
    document = next;
    if (!next.pages.any((p) => p.id == page)) page = next.pages.first.id;
    selection = {};
    entered = null;
    _past.clear();
    _future.clear();
    _revision++;
    if (saved) _saved = _revision;
    _notify();
  }
}

/// [doc] with the elements of page [pageId] replaced.
CardDocument withPageElements(
  CardDocument doc,
  String pageId,
  List<CardElement> elements,
) => doc.copyWith(
  pages: [
    for (final p in doc.pages)
      p.id == pageId ? p.copyWith(elements: elements) : p,
  ],
);
