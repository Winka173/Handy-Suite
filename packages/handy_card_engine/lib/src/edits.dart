part of '../handy_card_engine.dart';

// Pure edits on a page's layer list. Each takes the list and returns a new
// one; the session records them as undo steps.

/// Moves [ids] by [delta] in page coordinates, whatever their parents.
List<CardElement> moveBy(
  List<CardElement> elements,
  Set<String> ids,
  Vec delta,
) {
  var out = elements;
  for (final id in topmostOnly(elements, ids)) {
    final local = parentMatrix(elements, id).inverse().applyVector(delta);
    out = updateElement(
      out,
      id,
      (e) => e.copyWith(frame: e.frame.moved(local)),
    );
  }
  return out;
}

List<CardElement> setFrame(
  List<CardElement> elements,
  String id,
  Frame frame,
  ElementRegistry registry,
) => updateElement(elements, id, (e) {
  if (!e.isGroup || e.frame.width == 0 || e.frame.height == 0)
    return e.copyWith(frame: frame);
  return _scaleGroup(e, frame, registry);
});

/// A group given a new box: its children scale with it, text included.
CardElement _scaleGroup(CardElement g, Frame to, ElementRegistry registry) {
  final kx = to.width / g.frame.width, ky = to.height / g.frame.height;
  CardElement scale(CardElement e) {
    final f = e.frame;
    final spec = registry.lookup(e.type);
    final k = math.sqrt((kx * ky).abs());
    return e.copyWith(
      frame: f.copyWith(
        x: f.x * kx,
        y: f.y * ky,
        width: f.width * kx,
        height: f.height * ky,
      ),
      props: spec?.scaleProps == null ? e.props : spec!.scaleProps!(e.props, k),
      children: [for (final c in e.children) scale(c)],
    );
  }

  return g.copyWith(
    frame: to,
    children: [for (final c in g.children) scale(c)],
  );
}

/// The frame after dragging a resize handle of [original] by [delta]
/// (page coordinates). [handle] says which side moves on each axis: -1 the
/// left/top, 1 the right/bottom, 0 neither. The opposite side stays put
/// (or the centre, with [fromCenter]); [keepAspect] keeps the ratio. Works
/// in the element's own rotated axes, so a turned box resizes along them.
Frame resizeFrame(
  Frame original,
  Affine parent,
  Vec handle,
  Vec delta, {
  bool keepAspect = false,
  bool fromCenter = false,
  double minSize = 1,
}) {
  final r = original.rotation * math.pi / 180;
  final inParent = parent.inverse().applyVector(delta);
  final d = Affine.rotate(-r).applyVector(inParent);
  final hx = handle.x.sign, hy = handle.y.sign;
  final grow = fromCenter ? 2.0 : 1.0;
  var w = original.width + hx * d.x * grow;
  var h = original.height + hy * d.y * grow;
  if (keepAspect && original.width > 0 && original.height > 0) {
    final ratio = original.width / original.height;
    if (hx != 0 && hy != 0) {
      final k = math.max(w / original.width, h / original.height);
      w = original.width * k;
      h = original.height * k;
    } else if (hx != 0) {
      h = w / ratio;
    } else {
      w = h * ratio;
    }
  }
  w = math.max(minSize, w);
  h = math.max(minSize, h);
  if (fromCenter) {
    return original.copyWith(width: w, height: h).centredAt(original.center);
  }
  // The point that must not move: the opposite edge or corner.
  final ax = hx == 0 ? 0.5 : (hx > 0 ? 0.0 : 1.0);
  final ay = hy == 0 ? 0.5 : (hy > 0 ? 0.0 : 1.0);
  final anchor = original.matrix.apply(
    Vec(ax * original.width, ay * original.height),
  );
  final centre =
      anchor -
      Affine.rotate(r).applyVector(Vec(ax * w - w / 2, ay * h - h / 2));
  return original.copyWith(width: w, height: h).centredAt(centre);
}

/// Several elements fitted from box [from] into box [to] (page
/// coordinates), each keeping its place relative to the others.
List<CardElement> scaleSelection(
  List<CardElement> elements,
  Set<String> ids,
  Box from,
  Box to,
  ElementRegistry registry,
) {
  if (from.width <= 0 || from.height <= 0) return elements;
  final kx = to.width / from.width, ky = to.height / from.height;
  var out = elements;
  for (final id in topmostOnly(elements, ids)) {
    final parent = parentMatrix(elements, id);
    final e = findElement(elements, id)!;
    final c = parent.apply(e.frame.center);
    final moved = Vec(to.x + (c.x - from.x) * kx, to.y + (c.y - from.y) * ky);
    final local = parent.inverse().apply(moved);
    final next = e.frame
        .copyWith(width: e.frame.width * kx, height: e.frame.height * ky)
        .centredAt(local);
    out = setFrame(out, id, next, registry);
  }
  return out;
}

/// [ids] turned by [degrees] about [pivot] (page coordinates; the selection
/// centre by default).
List<CardElement> rotateBy(
  List<CardElement> elements,
  Set<String> ids,
  double degrees, {
  Vec? pivot,
}) {
  final top = topmostOnly(elements, ids);
  final p = pivot ?? boundsOf(elements, top)?.center ?? Vec.zero;
  final turn =
      Affine.translate(p.x, p.y) *
      Affine.rotate(degrees * math.pi / 180) *
      Affine.translate(-p.x, -p.y);
  var out = elements;
  for (final id in top) {
    final parent = parentMatrix(elements, id);
    final e = findElement(elements, id)!;
    final centre = parent.inverse().apply(
      turn.apply(parent.apply(e.frame.center)),
    );
    out = updateElement(
      out,
      id,
      (x) => x.copyWith(
        frame: x.frame
            .copyWith(rotation: x.frame.rotation + degrees)
            .centredAt(centre),
      ),
    );
  }
  return out;
}

/// Properties merged in and checked by the element's spec.
List<CardElement> setProps(
  List<CardElement> elements,
  Set<String> ids,
  Map<String, Object?> changes,
  ElementRegistry registry,
) {
  var out = elements;
  for (final id in ids) {
    out = updateElement(out, id, (e) {
      final spec = registry.lookup(e.type);
      if (spec == null) return e;
      return e.copyWith(props: spec.normalize({...e.props, ...changes}));
    });
  }
  return out;
}

/// A deep copy with fresh ids throughout.
CardElement cloneElement(CardElement e) => e.copyWith(
  id: newCardId(),
  children: [for (final c in e.children) cloneElement(c)],
);

/// Copies of [ids] placed just above their originals, moved by [offset].
({List<CardElement> elements, Set<String> created}) duplicate(
  List<CardElement> elements,
  Set<String> ids, {
  Vec offset = const Vec(6, 6),
}) {
  var out = elements;
  final created = <String>{};
  for (final id in topmostOnly(elements, ids)) {
    final e = findElement(out, id)!;
    final copy = cloneElement(e);
    final parent = parentOf(out, id);
    final siblings = siblingsOf(out, id);
    final local = parentMatrix(out, id).inverse().applyVector(offset);
    out = insertElements(
      out,
      [copy.copyWith(frame: copy.frame.moved(local))],
      parent: parent,
      index: siblings.indexWhere((s) => s.id == id) + 1,
    );
    created.add(copy.id);
  }
  return (elements: out, created: created);
}

enum Arrange { front, forward, backward, back }

/// [ids] moved in the stack among their siblings.
List<CardElement> arrange(
  List<CardElement> elements,
  Set<String> ids,
  Arrange how,
) {
  List<CardElement> inList(List<CardElement> list) {
    final picked = [
      for (final e in list)
        if (ids.contains(e.id)) e,
    ];
    if (picked.isEmpty) {
      return [
        for (final e in list)
          e.children.isEmpty ? e : e.copyWith(children: inList(e.children)),
      ];
    }
    final rest = [
      for (final e in list)
        if (!ids.contains(e.id)) e,
    ];
    switch (how) {
      case Arrange.front:
        return [...rest, ...picked];
      case Arrange.back:
        return [...picked, ...rest];
      case Arrange.forward:
      case Arrange.backward:
        final out = List.of(list);
        final step = how == Arrange.forward ? 1 : -1;
        final order = how == Arrange.forward
            ? List.generate(out.length, (i) => out.length - 1 - i)
            : List.generate(out.length, (i) => i);
        for (final i in order) {
          final j = i + step;
          if (!ids.contains(out[i].id) || j < 0 || j >= out.length) continue;
          if (ids.contains(out[j].id)) continue;
          final t = out[i];
          out[i] = out[j];
          out[j] = t;
        }
        return out;
    }
  }

  return inList(elements);
}

/// [id] moved to [index] inside [parent] (null for the top level), keeping
/// where it sits on the page. Used by the layers panel.
List<CardElement> moveInTree(
  List<CardElement> elements,
  String id,
  String? parent,
  int index,
) {
  final e = findElement(elements, id);
  if (e == null || id == parent) return elements;
  if (parent != null && pathTo(e.children, parent) != null) return elements;
  final world = worldMatrix(elements, id);
  final without = removeElements(elements, {id});
  final target = parent == null
      ? Affine.identity
      : worldMatrix(without, parent);
  final centre = target.inverse().apply(
    world.apply(Vec(e.frame.width / 2, e.frame.height / 2)),
  );
  final turn = math.atan2(world.b, world.a) - math.atan2(target.b, target.a);
  final placed = e.copyWith(
    frame: e.frame.copyWith(rotation: turn * 180 / math.pi).centredAt(centre),
  );
  return insertElements(without, [placed], parent: parent, index: index);
}

/// [ids] (siblings) gathered into one new group at the topmost one's place.
({List<CardElement> elements, String? group}) groupElements(
  List<CardElement> elements,
  Set<String> ids,
) {
  final top = topmostOnly(elements, ids);
  if (top.length < 2) return (elements: elements, group: null);
  final parent = parentOf(elements, top.first);
  if (top.any((id) => parentOf(elements, id) != parent))
    return (elements: elements, group: null);
  final siblings = siblingsOf(elements, top.first);
  final picked = [
    for (final e in siblings)
      if (top.contains(e.id)) e,
  ];
  final box = picked.map((e) => e.frame.bounds()).reduce((a, b) => a.union(b));
  final group = CardElement(
    id: newCardId(),
    type: 'group',
    frame: Frame(box.x, box.y, box.width, box.height).copyWith(),
    children: [
      for (final e in picked)
        e.copyWith(frame: e.frame.moved(Vec(-box.x, -box.y))),
    ],
  );
  final index =
      siblings.indexWhere((e) => e.id == picked.last.id) - picked.length + 1;
  final out = insertElements(
    removeElements(elements, top),
    [group],
    parent: parent,
    index: index,
  );
  return (elements: out, group: group.id);
}

/// The group's children put back in its place, each where it was seen.
({List<CardElement> elements, Set<String> children}) ungroup(
  List<CardElement> elements,
  String id,
) {
  final g = findElement(elements, id);
  if (g == null || !g.isGroup) return (elements: elements, children: {});
  final parent = parentOf(elements, id);
  final siblings = siblingsOf(elements, id);
  final index = siblings.indexWhere((e) => e.id == id);
  final m = g.frame.matrix;
  final freed = [
    for (final c in g.children)
      c.copyWith(
        frame: c.frame
            .copyWith(rotation: c.frame.rotation + g.frame.rotation)
            .centredAt(m.apply(c.frame.center)),
        opacity: c.opacity * g.opacity,
      ),
  ];
  return (
    elements: insertElements(
      removeElements(elements, {id}),
      freed,
      parent: parent,
      index: index,
    ),
    children: {for (final c in freed) c.id},
  );
}

enum Align { left, centerX, right, top, centerY, bottom }

/// [ids] lined up on one edge or centre of [to] (the selection's box, or
/// the card for a single element).
List<CardElement> alignElements(
  List<CardElement> elements,
  Set<String> ids,
  Align how, {
  Box? to,
}) {
  final top = topmostOnly(elements, ids);
  final target = to ?? boundsOf(elements, top);
  if (target == null) return elements;
  var out = elements;
  for (final id in top) {
    final b = worldBounds(out, id);
    final delta = switch (how) {
      Align.left => Vec(target.x - b.x, 0),
      Align.centerX => Vec(target.center.x - b.center.x, 0),
      Align.right => Vec(target.right - b.right, 0),
      Align.top => Vec(0, target.y - b.y),
      Align.centerY => Vec(0, target.center.y - b.center.y),
      Align.bottom => Vec(0, target.bottom - b.bottom),
    };
    out = moveBy(out, {id}, delta);
  }
  return out;
}

/// Three or more elements spaced with equal gaps between their boxes,
/// the outer two staying put.
List<CardElement> distribute(
  List<CardElement> elements,
  Set<String> ids, {
  required bool horizontal,
}) {
  final top = topmostOnly(elements, ids).toList();
  if (top.length < 3) return elements;
  final boxes = {for (final id in top) id: worldBounds(elements, id)};
  top.sort(
    (a, b) => horizontal
        ? boxes[a]!.x.compareTo(boxes[b]!.x)
        : boxes[a]!.y.compareTo(boxes[b]!.y),
  );
  final first = boxes[top.first]!, last = boxes[top.last]!;
  final span = horizontal ? last.right - first.x : last.bottom - first.y;
  final used = top.fold<double>(
    0,
    (a, id) => a + (horizontal ? boxes[id]!.width : boxes[id]!.height),
  );
  final gap = (span - used) / (top.length - 1);
  var cursor = horizontal ? first.x : first.y;
  var out = elements;
  for (final id in top) {
    final b = boxes[id]!;
    final at = horizontal ? b.x : b.y;
    if (id != top.first && id != top.last) {
      out = moveBy(out, {
        id,
      }, horizontal ? Vec(cursor - at, 0) : Vec(0, cursor - at));
    }
    cursor += (horizontal ? b.width : b.height) + gap;
  }
  return out;
}
