part of '../handy_card_engine.dart';

/// The chain of elements from the page down to one element.
List<CardElement>? pathTo(List<CardElement> elements, String id) {
  for (final e in elements) {
    if (e.id == id) return [e];
    final inner = pathTo(e.children, id);
    if (inner != null) return [e, ...inner];
  }
  return null;
}

CardElement? findElement(List<CardElement> elements, String id) =>
    pathTo(elements, id)?.last;

/// Page coordinates of the element's parent space (identity at the top).
Affine parentMatrix(List<CardElement> elements, String id) {
  final path = pathTo(elements, id);
  if (path == null) throw StateError('No element $id');
  var m = Affine.identity;
  for (final g in path.take(path.length - 1)) m = m * g.frame.matrix;
  return m;
}

/// Element-local (0..w, 0..h) to page coordinates.
Affine worldMatrix(List<CardElement> elements, String id) =>
    parentMatrix(elements, id) * findElement(elements, id)!.frame.matrix;

/// The axis-aligned box an element covers on the page.
Box worldBounds(List<CardElement> elements, String id) {
  final e = findElement(elements, id)!;
  return e.frame.bounds(parentMatrix(elements, id));
}

/// One box round several elements, or null for none.
Box? boundsOf(List<CardElement> elements, Iterable<String> ids) {
  Box? out;
  for (final id in ids) {
    final b = worldBounds(elements, id);
    out = out == null ? b : out.union(b);
  }
  return out;
}

/// Id of the parent group, or null at the top level.
String? parentOf(List<CardElement> elements, String id) {
  final path = pathTo(elements, id);
  if (path == null || path.length < 2) return null;
  return path[path.length - 2].id;
}

/// The list holding [id] (its siblings and itself).
List<CardElement> siblingsOf(List<CardElement> elements, String id) {
  final parent = parentOf(elements, id);
  return parent == null ? elements : findElement(elements, parent)!.children;
}

/// [elements] with [id] replaced by [change] of it.
List<CardElement> updateElement(
  List<CardElement> elements,
  String id,
  CardElement Function(CardElement) change,
) => [
  for (final e in elements)
    if (e.id == id)
      change(e)
    else if (e.children.isNotEmpty)
      e.copyWith(children: updateElement(e.children, id, change))
    else
      e,
];

/// [elements] without [ids] (and without their children).
List<CardElement> removeElements(List<CardElement> elements, Set<String> ids) =>
    [
      for (final e in elements)
        if (!ids.contains(e.id))
          e.children.isEmpty
              ? e
              : e.copyWith(children: removeElements(e.children, ids)),
    ];

/// [elements] with [inserted] placed at [index] inside [parent] (or at the
/// top level).
List<CardElement> insertElements(
  List<CardElement> elements,
  List<CardElement> inserted, {
  String? parent,
  int? index,
}) {
  if (parent == null) {
    final at = (index ?? elements.length).clamp(0, elements.length);
    return [...elements.take(at), ...inserted, ...elements.skip(at)];
  }
  return updateElement(
    elements,
    parent,
    (g) => g.copyWith(
      children: insertElements(g.children, inserted, index: index),
    ),
  );
}

/// The topmost element under [point] (page coordinates). Inside groups the
/// whole group answers unless [enter] names that group, so a click selects
/// what the person sees as one object. Hidden and locked elements are
/// skipped; [tolerance] widens thin lines.
String? hitTest(
  List<CardElement> elements,
  Vec point, {
  String? enter,
  double tolerance = 0,
}) {
  String? walk(List<CardElement> list, Affine parent) {
    for (final e in list.reversed) {
      if (!e.visible || e.locked) continue;
      final m = parent * e.frame.matrix;
      if (e.isGroup) {
        final inner = walk(e.children, m);
        if (inner != null) return e.id == enter ? inner : e.id;
        continue;
      }
      final local = m.inverse().apply(point);
      final slack = tolerance / math.max(1e-6, math.sqrt(m.determinant.abs()));
      if (local.x >= -slack &&
          local.y >= -slack &&
          local.x <= e.frame.width + slack &&
          local.y <= e.frame.height + slack)
        return e.id;
    }
    return null;
  }

  // A group being edited answers for its children only.
  if (enter != null && findElement(elements, enter) != null) {
    final g = findElement(elements, enter)!;
    final hit = walk(g.children, worldMatrix(elements, enter));
    if (hit != null) return hit;
  }
  return walk(elements, Affine.identity);
}

/// Ids of top-level (or [within]-level) elements whose bounds lie inside
/// [area]: the rubber-band selection.
Set<String> elementsInside(
  List<CardElement> elements,
  Box area, {
  String? within,
}) {
  final list = within == null
      ? elements
      : findElement(elements, within)!.children;
  return {
    for (final e in list)
      if (e.visible && !e.locked) ...{
        if (_inside(area, worldBounds(elements, e.id))) e.id,
      },
  };
}

bool _inside(Box outer, Box inner) =>
    inner.x >= outer.x &&
    inner.y >= outer.y &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

/// Keeps only selected ids whose ancestors are not also selected, so an
/// edit never applies twice to the same element.
Set<String> topmostOnly(List<CardElement> elements, Set<String> ids) => {
  for (final id in ids)
    if (!(pathTo(elements, id) ?? const [])
        .take(math.max(0, (pathTo(elements, id)?.length ?? 1) - 1))
        .any((a) => ids.contains(a.id)))
      id,
};
