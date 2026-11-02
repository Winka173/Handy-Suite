import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card_engine/handy_card_engine.dart';

final registry = ElementRegistry.standard();
final at = DateTime.utc(2026, 11, 2);

CardElement box(
  String id,
  double x,
  double y,
  double w,
  double h, {
  double r = 0,
  List<CardElement> children = const [],
  String type = 'rect',
}) => CardElement(
  id: id,
  type: type,
  frame: Frame(x, y, w, h, r),
  props: registry.spec(type).normalize({}),
  children: children,
);

CardDocument docWith(List<CardElement> els) {
  final d = blankDocument(size: cardSizes[0], at: at, sides: 2);
  return withPageElements(d, d.pages.first.id, els);
}

void main() {
  group('geometry', () {
    test(
      'a rotated box hit-tests on its turned outline, not its square bounds',
      () {
        final els = [box('a', 0, 0, 100, 20, r: 45)];
        // The centre is inside; a corner of the axis-aligned bounds is not.
        expect(hitTest(els, const Vec(50, 10)), 'a');
        final bounds = worldBounds(els, 'a');
        expect(hitTest(els, Vec(bounds.x + 2, bounds.y + 2)), isNull);
      },
    );

    test('inside a rotated, moved group, children hit where they are drawn', () {
      final child = box('c', 10, 10, 20, 20);
      final group = box(
        'g',
        100,
        50,
        40,
        40,
        r: 90,
        type: 'group',
        children: [child],
      );
      final els = [group];
      // The group's corner (0,0) goes to (140,50) after a 90° turn about its centre.
      final m = worldMatrix(els, 'c');
      final centre = m.apply(const Vec(10, 10));
      expect(
        hitTest(els, centre),
        'g',
        reason: 'the group answers from outside',
      );
      expect(
        hitTest(els, centre, enter: 'g'),
        'c',
        reason: 'entered, its child answers',
      );
      expect(Affine.identity * m.inverse() * m, isA<Affine>());
    });

    test('hidden and locked layers are not hit', () {
      final els = [
        box('under', 0, 0, 50, 50),
        box('top', 0, 0, 50, 50).copyWith(locked: true),
      ];
      expect(hitTest(els, const Vec(10, 10)), 'under');
      expect(
        hitTest([
          box('x', 0, 0, 50, 50).copyWith(visible: false),
        ], const Vec(10, 10)),
        isNull,
      );
    });

    test('resizing a rotated box keeps the opposite corner fixed', () {
      const f = Frame(40, 40, 100, 50, 30);
      final anchorBefore = f.matrix.apply(Vec.zero);
      final next = resizeFrame(
        f,
        Affine.identity,
        const Vec(1, 1),
        const Vec(20, 10),
      );
      expect(next.matrix.apply(Vec.zero).x, closeTo(anchorBefore.x, 1e-2));
      expect(next.matrix.apply(Vec.zero).y, closeTo(anchorBefore.y, 1e-2));
      expect(next.width, greaterThan(100));
      final kept = resizeFrame(
        f,
        Affine.identity,
        const Vec(1, 1),
        const Vec(40, 0),
        keepAspect: true,
      );
      expect(kept.width / kept.height, closeTo(2, 1e-3));
    });

    test('a thousand small moves add up without drift', () {
      var els = [box('a', 0, 0, 10, 10)];
      for (var i = 0; i < 1000; i++)
        els = moveBy(els, {'a'}, const Vec(0.1, 0.1));
      expect(findElement(els, 'a')!.frame.x, closeTo(100, 1e-6));
    });
  });

  group('structure', () {
    test('group then ungroup puts every element back where it was seen', () {
      var els = [box('a', 10, 10, 30, 20, r: 20), box('b', 80, 40, 20, 20)];
      final before = {
        for (final id in ['a', 'b'])
          id: worldMatrix(els, id).apply(const Vec(5, 5)),
      };
      final g = groupElements(els, {'a', 'b'});
      expect(g.group, isNotNull);
      els = rotateBy(g.elements, {g.group!}, 0);
      for (final id in ['a', 'b']) {
        final p = worldMatrix(els, id).apply(const Vec(5, 5));
        expect(p.x, closeTo(before[id]!.x, 1e-2));
        expect(p.y, closeTo(before[id]!.y, 1e-2));
      }
      // Turn the group, ungroup: children keep the turn.
      els = rotateBy(els, {g.group!}, 90);
      final turned = worldMatrix(els, 'a').apply(const Vec(5, 5));
      els = ungroup(els, g.group!).elements;
      expect(findElement(els, g.group!), isNull);
      final after = worldMatrix(els, 'a').apply(const Vec(5, 5));
      expect(after.x, closeTo(turned.x, 1e-2));
      expect(after.y, closeTo(turned.y, 1e-2));
    });

    test('resizing a group scales its children and their text', () {
      final text = CardElement(
        id: 't',
        type: 'text',
        frame: const Frame(0, 0, 50, 10),
        props: registry.spec('text').normalize({'size': 10}),
      );
      var els = [
        box('g', 0, 0, 50, 10, type: 'group', children: [text]),
      ];
      els = setFrame(els, 'g', const Frame(0, 0, 100, 20), registry);
      final t = findElement(els, 't')!;
      expect(t.frame.width, 100);
      expect(t.prop<double>('size', 0), closeTo(20, 1e-6));
    });

    test('arrange, align and distribute', () {
      var els = [
        box('a', 0, 0, 10, 10),
        box('b', 50, 30, 10, 10),
        box('c', 200, 5, 10, 10),
      ];
      expect(arrange(els, {'a'}, Arrange.front).map((e) => e.id), [
        'b',
        'c',
        'a',
      ]);
      expect(arrange(els, {'c'}, Arrange.backward).map((e) => e.id), [
        'a',
        'c',
        'b',
      ]);
      els = alignElements(els, {'a', 'b', 'c'}, CardAlign.top);
      expect(els.map((e) => e.frame.y), [0, 0, 0]);
      els = moveBy(els, {'b'}, const Vec(-30, 0));
      els = distribute(els, {'a', 'b', 'c'}, horizontal: true);
      expect(findElement(els, 'b')!.frame.x, closeTo(100, 1e-6));
    });

    test('duplicate gives fresh ids all the way down', () {
      final els = [
        box(
          'g',
          0,
          0,
          40,
          40,
          type: 'group',
          children: [box('x', 0, 0, 10, 10)],
        ),
      ];
      final d = duplicate(els, {'g'});
      final copy = findElement(d.elements, d.created.single)!;
      expect(copy.id, isNot('g'));
      expect(copy.children.single.id, isNot('x'));
      expect(copy.frame.x, 6);
    });

    test(
      'moving a layer into a turned group keeps it in place on the card',
      () {
        var els = [
          box(
            'g',
            100,
            100,
            50,
            50,
            r: 30,
            type: 'group',
            children: [box('in', 0, 0, 5, 5)],
          ),
          box('a', 20, 20, 10, 10),
        ];
        final before = worldMatrix(els, 'a').apply(const Vec(5, 5));
        els = moveInTree(els, 'a', 'g', 0);
        expect(parentOf(els, 'a'), 'g');
        final after = worldMatrix(els, 'a').apply(const Vec(5, 5));
        expect(after.x, closeTo(before.x, 1e-2));
        expect(after.y, closeTo(before.y, 1e-2));
      },
    );
  });

  group('session and history', () {
    test('a drag is one undo step; redo ends after a different edit', () {
      final doc = docWith([box('a', 0, 0, 10, 10)]);
      final s = EditorSession(doc, registry: registry);
      s.begin('Move');
      for (var i = 1; i <= 30; i++) {
        s.preview(
          (base) => withPageElements(
            base,
            s.page,
            moveBy(base.page(s.page).elements, {'a'}, Vec(i.toDouble(), 0)),
          ),
        );
      }
      s.commit();
      expect(s.historyLength, 1);
      expect(findElement(s.elements, 'a')!.frame.x, 30);
      expect(s.dirty, isTrue);
      s.undo();
      expect(findElement(s.elements, 'a')!.frame.x, 0);
      expect(s.canRedo, isTrue);
      s.apply(
        'Nudge',
        (d) => withPageElements(
          d,
          s.page,
          moveBy(d.page(s.page).elements, {'a'}, const Vec(0, 5)),
        ),
      );
      expect(
        s.canRedo,
        isFalse,
        reason: 'a divergent edit ends the old future',
      );
    });

    test(
      'typing coalesces into one step; a cancelled drag leaves no trace',
      () {
        var now = DateTime.utc(2026);
        final doc = docWith([
          CardElement(
            id: 't',
            type: 'text',
            frame: const Frame(0, 0, 50, 10),
            props: registry.spec('text').normalize({}),
          ),
        ]);
        final s = EditorSession(doc, registry: registry, clock: () => now);
        for (final word in ['X', 'Xi', 'Xin', 'Xin chào']) {
          now = now.add(const Duration(milliseconds: 300));
          s.apply(
            'Edit text',
            (d) => withPageElements(
              d,
              s.page,
              setProps(
                d.page(s.page).elements,
                {'t'},
                {'text': word},
                registry,
              ),
            ),
            coalesce: 'text:t',
          );
        }
        expect(s.historyLength, 1);
        s.begin('Move');
        s.preview(
          (b) => withPageElements(
            b,
            s.page,
            moveBy(b.page(s.page).elements, {'t'}, const Vec(5, 5)),
          ),
        );
        s.cancel();
        expect(findElement(s.elements, 't')!.frame.x, 0);
        expect(s.historyLength, 1);
        s.undo();
        expect(findElement(s.elements, 't')!.prop<String>('text', 'x'), '');
        s.markSaved();
        expect(s.dirty, isFalse);
      },
    );

    test('history is bounded', () {
      final s = EditorSession(
        docWith([box('a', 0, 0, 10, 10)]),
        registry: registry,
        limit: 5,
      );
      for (var i = 0; i < 12; i++) {
        s.apply(
          'Move',
          (d) => withPageElements(
            d,
            s.page,
            moveBy(d.page(s.page).elements, {'a'}, const Vec(1, 0)),
          ),
        );
      }
      expect(s.historyLength, 5);
    });
  });

  group('snapping', () {
    test('an edge near the card centre snaps to it and draws a guide', () {
      final doc = docWith([box('a', 0, 0, 20, 20)]);
      final start = worldBounds(doc.pages.first.elements, 'a');
      // Centre of the card is at x = 127.56; move so the box centre is 2 pt off.
      final r = snapMove(
        doc,
        doc.pages.first.elements,
        {'a'},
        start,
        Vec(doc.width / 2 - 10 - 2, 40),
        threshold: 4,
      );
      expect(r.delta.x, closeTo(doc.width / 2 - 10, 1e-6));
      expect(r.guides.where((g) => g.vertical), isNotEmpty);
    });

    test('far from anything, nothing snaps', () {
      final doc = docWith([box('a', 0, 0, 20, 20)]);
      final r = snapMove(
        doc,
        doc.pages.first.elements,
        {'a'},
        worldBounds(doc.pages.first.elements, 'a'),
        const Vec(37, 37),
        threshold: 1,
        options: const SnapOptions(toSafe: false),
      );
      expect(r.delta, const Vec(37, 37));
      expect(snapAngle(44), 45);
      expect(snapAngle(38), 38);
    });
  });

  test('an element type this build does not know is kept through a save', () {
    final doc = docWith([box('a', 0, 0, 10, 10)]);
    final json = doc.toJson();
    final page = (json['pages'] as List).first as Map<String, Object?>;
    (page['elements'] as List).add({
      'id': 'future',
      'type': 'sticker3d',
      'frame': {'x': 1, 'y': 2, 'w': 3, 'h': 4},
      'props': {'depth': 7},
      'glow': true,
    });
    json['futureSetting'] = {'a': 1};
    final back = CardDocument.fromJson(json, registry);
    final again = CardDocument.fromJson(back.toJson(), registry).toJson();
    final el = ((again['pages'] as List).first as Map)['elements'].last as Map;
    expect(el['type'], 'sticker3d');
    expect(el['props'], {'depth': 7});
    expect(el['glow'], true);
    expect(again['futureSetting'], {'a': 1});
  });

  test('schema 0 drafts migrate; newer schemas are refused', () {
    final old = {
      'schema': 0,
      'id': 'old1',
      'width': 100,
      'height': 50,
      'elements': [
        {
          'id': 'x',
          'type': 'rect',
          'frame': {'x': 0, 'y': 0, 'w': 10, 'h': 10},
        },
      ],
    };
    final d = CardDocument.fromJson(old, registry);
    expect(d.pages.single.elements.single.id, 'x');
    expect(
      () => CardDocument.fromJson({...d.toJson(), 'schema': 99}, registry),
      throwsFormatException,
    );
    expect(
      () =>
          CardDocument.fromJson({...d.toJson(), 'width': double.nan}, registry),
      throwsFormatException,
    );
  });

  test('the badge extension saves, loads and draws like a built-in', () {
    final badge = registry.create(
      'badge',
      at: const Vec(50, 50),
      props: {'label': 'MỚI'},
    );
    final doc = docWith([badge]);
    final back = CardDocument.decode(doc.encode(), registry);
    expect(back.pages.first.elements.single.prop<String>('label', ''), 'MỚI');
    // A registry without the extension still keeps it, untouched.
    final plain = ElementRegistry()..register(builtInElements.first);
    for (final s in builtInElements.skip(1)) plain.register(s);
    final kept = CardDocument.decode(doc.encode(), plain);
    expect(
      kept.pages.first.elements.single.props,
      back.pages.first.elements.single.props,
    );
    final svg = exportSvg(back, back.pages.first.id).svg;
    expect(svg, contains('MỚI'));
    expect(math.max(1, 2), 2);
  });
}
