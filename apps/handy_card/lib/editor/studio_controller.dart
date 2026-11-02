import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;
import 'package:flutter/foundation.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import '../data/library.dart';
import 'paint.dart';

/// Elements copied with Ctrl/⌘ C, kept as JSON for the session (shared by
/// every open design, so cards can borrow from each other).
List<Map<String, Object?>> cardClipboard = [];

/// One open design in the studio: the editing session, the view (zoom and
/// scroll), tool settings, and the autosave that writes the document 600 ms
/// after the last change, one write at a time.
class StudioController extends ChangeNotifier {
  final CardLibrary library;
  final CardImages images;
  final EditorSession session;
  final measurer = FlutterMeasurer();
  StudioController(this.library, this.images, CardDocument doc)
    : session = EditorSession(doc, registry: library.registry) {
    session.addListener(_changed);
    images.addListener(notifyListeners);
  }

  // View: screen pixels per point, and where the card's top-left sits.
  double zoom = 1;
  Offset origin = Offset.zero;
  Size viewport = Size.zero;
  bool fitted = false;

  bool panMode = false;
  bool showGuides = true;
  List<SnapGuide> guides = const [];
  Rect? marquee;
  String? editingText;

  SnapOptions get snap => SnapOptions(
    toCard: library.flag('snapCard'),
    toObjects: library.flag('snapObjects'),
    toGrid: library.flag('snapGrid', fallback: false),
    toSafe: library.flag('snapSafe'),
    grid: 4 * pointsPerMm / 2,
  );

  CardDocument get doc => session.document;
  CardProfile? get profile => library.profiles[doc.profileId];
  PaintContext get paintContext => PaintContext(
    profile: profile,
    measurer: measurer,
    image: (id) => images[id],
  );

  Timer? _save;
  Future<void>? _writing;
  String saveState = 'saved';
  Object? saveError;

  void _changed() {
    if (session.dirty && !session.inTransaction) {
      saveState = 'pending';
      _save?.cancel();
      _save = Timer(const Duration(milliseconds: 600), save);
    }
    notifyListeners();
  }

  /// Writes the document now (after any write still running).
  Future<void> save() async {
    _save?.cancel();
    if (!session.dirty) return;
    while (_writing != null) {
      await _writing;
    }
    final revision = session.revision;
    final completer = Completer<void>();
    _writing = completer.future;
    saveState = 'saving';
    notifyListeners();
    try {
      await library.saveDesign(session.document);
      if (session.revision == revision) session.markSaved(revision);
      saveError = null;
      saveState = session.dirty ? 'pending' : 'saved';
    } catch (e) {
      saveError = e;
      saveState = 'error';
    } finally {
      _writing = null;
      completer.complete();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _save?.cancel();
    session.removeListener(_changed);
    images.removeListener(notifyListeners);
    super.dispose();
  }

  // View helpers.
  Offset toScreen(Vec p) => origin + Offset(p.x * zoom, p.y * zoom);
  Vec toDoc(Offset s) =>
      Vec((s.dx - origin.dx) / zoom, (s.dy - origin.dy) / zoom);

  void fit([Size? size]) {
    final v = size ?? viewport;
    if (v.isEmpty) return;
    final pad = v.width < 600 ? 24.0 : 56.0;
    final b = doc.bleed;
    zoom = math
        .min(
          (v.width - 2 * pad) / (doc.width + 2 * b),
          (v.height - 2 * pad) / (doc.height + 2 * b),
        )
        .clamp(0.05, 40);
    origin = Offset(
      (v.width - doc.width * zoom) / 2,
      (v.height - doc.height * zoom) / 2,
    );
    fitted = true;
    notifyListeners();
  }

  void fitSelection() {
    final box = boundsOf(session.elements, session.selected);
    if (box == null || viewport.isEmpty) return fit();
    zoom = math
        .min(
          viewport.width * 0.6 / math.max(1, box.width),
          viewport.height * 0.6 / math.max(1, box.height),
        )
        .clamp(0.05, 40);
    final c = box.center;
    origin = Offset(
      viewport.width / 2 - c.x * zoom,
      viewport.height / 2 - c.y * zoom,
    );
    notifyListeners();
  }

  /// Zooms by [factor] keeping the point [at] (screen) still.
  void zoomBy(double factor, [Offset? at]) {
    final focus = at ?? Offset(viewport.width / 2, viewport.height / 2);
    final before = toDoc(focus);
    zoom = (zoom * factor).clamp(0.05, 40);
    origin = focus - Offset(before.x * zoom, before.y * zoom);
    notifyListeners();
  }

  void panBy(Offset delta) {
    origin += delta;
    notifyListeners();
  }

  /// Repaints after a view-only change (guides, marquee).
  void refresh() => notifyListeners();

  void setPanMode(bool on) {
    if (panMode == on) return;
    panMode = on;
    notifyListeners();
  }

  // Edits, each one undo step.
  List<CardElement> get els => session.elements;
  ElementRegistry get registry => library.registry;

  void edit(
    String label,
    List<CardElement> Function(List<CardElement>) change, {
    Set<String>? select,
    String? coalesce,
  }) {
    session.apply(
      label,
      (d) => withPageElements(
        d,
        session.page,
        change(d.page(session.page).elements),
      ),
      select: select,
      coalesce: coalesce,
    );
  }

  void editDoc(
    String label,
    CardDocument Function(CardDocument) change, {
    String? coalesce,
  }) => session.apply(label, change, coalesce: coalesce);

  /// A new element of [type] in the middle of what is in view.
  void add(
    String type, {
    Map<String, Object?> props = const {},
    ElementBinding? binding,
    String? name,
  }) {
    final centre = viewport.isEmpty
        ? Vec(doc.width / 2, doc.height / 2)
        : toDoc(Offset(viewport.width / 2, viewport.height / 2));
    final at = Vec(
      centre.x.clamp(0, doc.width).toDouble(),
      centre.y.clamp(0, doc.height).toDouble(),
    );
    var e = registry.create(
      type,
      at: at,
      props: props,
      binding: binding,
      name: name,
    );
    // New elements stay readable on a small card.
    final scale = math.min(
      1.0,
      math.min(
        doc.width / (e.frame.width * 1.5),
        doc.height / (e.frame.height * 1.5),
      ),
    );
    if (scale < 1)
      e = e.copyWith(
        frame: e.frame
            .copyWith(
              width: e.frame.width * scale,
              height: e.frame.height * scale,
            )
            .centredAt(at),
      );
    final parent = session.entered;
    edit(
      'Add ${registry.spec(type).en}',
      (l) => insertElements(l, [e], parent: parent),
      select: {e.id},
    );
  }

  Future<void> addPicture(
    Uint8List bytes,
    String name, {
    String? replace,
  }) async {
    final asset = await library.addAsset(bytes, name: name);
    final assets = [...doc.assets.where((a) => a.id != asset.id), asset];
    if (replace != null) {
      session.apply('Replace picture', (d) {
        final next = d.copyWith(assets: assets);
        return withPageElements(
          next,
          session.page,
          setPropsIn(
            next.page(session.page).elements,
            {replace},
            {'asset': asset.id, 'cropX': 0, 'cropY': 0, 'cropW': 1, 'cropH': 1},
            registry,
          ),
        );
      });
      return;
    }
    final ratio = asset.width > 0 && asset.height > 0
        ? asset.width / asset.height
        : 1.0;
    final side = math.min(doc.width, doc.height) * 0.5;
    final w = ratio >= 1 ? side : side * ratio,
        h = ratio >= 1 ? side / ratio : side;
    final e = registry.create(
      'image',
      at: Vec(doc.width / 2, doc.height / 2),
      props: {'asset': asset.id},
    );
    final placed = e.copyWith(
      frame: e.frame
          .copyWith(width: w, height: h)
          .centredAt(Vec(doc.width / 2, doc.height / 2)),
    );
    session.apply('Add picture', (d) {
      final next = d.copyWith(assets: assets);
      return withPageElements(
        next,
        session.page,
        insertElements(next.page(session.page).elements, [
          placed,
        ], parent: session.entered),
      );
    }, select: {placed.id});
  }

  void deleteSelection() {
    final ids = session.selected;
    if (ids.isEmpty) return;
    edit('Delete', (l) => removeElements(l, ids), select: {});
    _dropUnusedAssets();
  }

  /// Pictures no element uses any more leave the document (the store keeps
  /// the bytes until the next start, so undo can bring them back).
  void _dropUnusedAssets() {
    final used = {
      for (final p in doc.pages)
        for (final e in p.all) ?e.props['asset'] as String?,
    };
    if (doc.assets.every((a) => used.contains(a.id))) return;
    final kept = [
      for (final a in doc.assets)
        if (used.contains(a.id)) a,
    ];
    session.apply(
      'Delete',
      (d) => d.copyWith(assets: kept),
      coalesce: 'assets',
    );
  }

  void duplicateSelection() {
    final ids = session.selected;
    if (ids.isEmpty) return;
    late Set<String> created;
    edit('Duplicate', (l) {
      final r = duplicate(l, ids);
      created = r.created;
      return r.elements;
    });
    session.select(created);
  }

  void copySelection() {
    cardClipboard = [
      for (final id in session.selected)
        if (findElement(els, id) case final e?)
          {
            ...e.toJson(),
            // Keep where it is seen, even if it was inside a group.
            'frame': e.frame
                .centredAt(
                  worldMatrix(
                    els,
                    id,
                  ).apply(Vec(e.frame.width / 2, e.frame.height / 2)),
                )
                .copyWith(rotation: e.frame.rotation)
                .toJson(),
          },
    ];
  }

  void cutSelection() {
    copySelection();
    deleteSelection();
  }

  /// Pasted copies get fresh ids; pictures they use must already be in this
  /// design or the library (copying between designs carries the asset ref).
  void paste() {
    if (cardClipboard.isEmpty) return;
    final pasted = <CardElement>[];
    for (final raw in cardClipboard) {
      try {
        pasted.add(
          cloneElement(
            CardElement.fromJson(jsonDecode(jsonEncode(raw)), registry),
          ),
        );
      } on FormatException {
        continue;
      }
    }
    final needed = {
      for (final e in pasted)
        for (final d in e.descendants) ?d.props['asset'] as String?,
    };
    final known = {
      for (final d in library.designs.values)
        for (final a in d.assets) a.id: a,
    };
    final assets = [
      ...doc.assets,
      for (final id in needed)
        if (!doc.assets.any((a) => a.id == id) && known[id] != null) known[id]!,
    ];
    final usable = pasted
        .where(
          (e) => e.descendants.every(
            (d) =>
                d.props['asset'] == null ||
                assets.any((a) => a.id == d.props['asset']),
          ),
        )
        .toList();
    if (usable.isEmpty) return;
    session.apply('Paste', (d) {
      final next = d.copyWith(assets: assets);
      return withPageElements(
        next,
        session.page,
        insertElements(next.page(session.page).elements, [
          for (final e in usable)
            e.copyWith(frame: e.frame.moved(const Vec(6, 6))),
        ]),
      );
    }, select: {for (final e in usable) e.id});
  }

  void selectAll() => session.select([
    for (final e
        in session.entered == null
            ? els
            : (findElement(els, session.entered!)?.children ??
                  const <CardElement>[]))
      if (e.visible && !e.locked) e.id,
  ]);

  void nudge(Vec by) {
    final ids = session.selected;
    if (ids.isEmpty) return;
    edit('Nudge', (l) => moveBy(l, ids, by), coalesce: 'nudge');
  }

  void group() {
    late String? g;
    edit('Group', (l) {
      final r = groupElements(l, session.selected);
      g = r.group;
      return r.elements;
    });
    if (g != null) session.select({g!});
  }

  void ungroupSelection() {
    final single = session.single;
    if (single == null || !single.isGroup) return;
    late Set<String> freed;
    edit('Ungroup', (l) {
      final r = ungroup(l, single.id);
      freed = r.children;
      return r.elements;
    });
    session.select(freed);
  }

  void align(CardAlign how) {
    final ids = session.selected;
    if (ids.isEmpty) return;
    edit(
      'Align',
      (l) => alignElements(l, ids, how, to: ids.length == 1 ? doc.trim : null),
    );
  }

  void arrangeSelection(Arrange how) {
    final ids = session.selected;
    if (ids.isEmpty) return;
    edit('Arrange', (l) => arrange(l, ids, how));
  }

  void setProps(
    Set<String> ids,
    Map<String, Object?> props, {
    String label = 'Edit',
    String? coalesce,
  }) => edit(label, (l) => setPropsOf(l, ids, props), coalesce: coalesce);

  List<CardElement> setPropsOf(
    List<CardElement> l,
    Set<String> ids,
    Map<String, Object?> props,
  ) => setPropsIn(l, ids, props, registry);

  void setFrameOf(String id, Frame f, {String? coalesce}) =>
      edit('Resize', (l) => setFrame(l, id, f, registry), coalesce: coalesce);

  void update(
    String id,
    CardElement Function(CardElement) change, {
    String label = 'Edit',
    String? coalesce,
  }) => edit(label, (l) => updateElement(l, id, change), coalesce: coalesce);

  void bind(String id, ElementBinding? binding) => update(
    id,
    (e) => binding == null
        ? e.copyWith(clearBinding: true)
        : e.copyWith(binding: binding),
    label: 'Link to profile',
  );

  void unlink(String id) => update(
    id,
    (e) => unlinkElement(e, profile),
    label: 'Unlink from profile',
  );
}

List<CardElement> setPropsIn(
  List<CardElement> l,
  Set<String> ids,
  Map<String, Object?> props,
  ElementRegistry r,
) => setProps(l, ids, props, r);
