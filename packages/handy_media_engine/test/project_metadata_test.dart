import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'project_test.dart' show projectFixture;

void main() {
  test(
    'metadata edits retain v1 identity, dates, steps and unedited bug fields',
    () {
      final original = projectFixture(), before = original.serialize();
      final next = original.copyWith(
        kind: 'comparison',
        tags: [' Tiếng Việt ', 'with,comma'],
        bug: {...original.bug, 'expected': 'Changed'},
      );
      expect(next.id, original.id);
      expect(next.createdAt, original.createdAt);
      expect(
        next.steps.map((s) => s.toJson()),
        original.steps.map((s) => s.toJson()),
      );
      expect(next.bug['actual'], original.bug['actual']);
      expect(next.tags, [' Tiếng Việt ', 'with,comma']);
      expect(CaptureProject.fromText(next.serialize()).toJson(), next.toJson());
      expect(original.serialize(), before);
      for (final action in [
        () => original.copyWith(kind: 'unknown'),
        () => original.copyWith(tags: List.filled(33, 'x')),
        () => original.copyWith(tags: ['x' * 41]),
        () => original.copyWith(bug: {'actual': 'missing fields'}),
      ]) {
        expect(action, throwsFormatException);
      }
      expect(original.serialize(), before);
    },
  );
  CaptureProject twoSteps() {
    final source = projectFixture();
    return source.copyWith(
      steps: [
        ...source.steps,
        ProjectStep.parse({
          ...source.steps.first.toJson(),
          'id': 'target-step',
          'imageWidth': 48,
          'imageHeight': 32,
          'annotations': [],
        }),
      ],
    );
  }

  test(
    'repeated mask retains relative geometry across different screenshot dimensions',
    () {
      final source = twoSteps(), before = source.serialize();
      final mask = source.steps.first.annotations.firstWhere(
        (a) => a.kind == 'redact',
      );
      final result = repeatProjectMask(
        source,
        source.steps.first.id,
        mask.id,
        newLayerId: () => 'new-mask',
      );
      expect(result.steps.first.toJson(), source.steps.first.toJson());
      final next = result.steps.last.annotations.single;
      expect(next.kind, 'redact');
      expect(next.color, '#000000');
      expect(next.text, '');
      expect(next.geometry.toJson(), mask.geometry.toJson());
      expect(source.serialize(), before);
    },
  );
  test(
    'repeat rejects invalid selection, duplicate IDs and full targets atomically',
    () {
      final source = twoSteps(), before = source.serialize();
      for (final pair in [
        ('missing', 'missing'),
        (source.steps.first.id, 'layer-0'),
      ]) {
        expect(
          () => repeatProjectMask(
            source,
            pair.$1,
            pair.$2,
            newLayerId: () => 'new-mask',
          ),
          throwsFormatException,
        );
      }
      final mask = source.steps.first.annotations.firstWhere(
        (a) => a.kind == 'redact',
      );
      final full = source.copyWith(
        steps: [
          source.steps.first,
          source.steps.last.copyWith(
            annotations: [
              for (var i = 0; i < 100; i++) defaultLayer('target-$i', 'rect'),
            ],
          ),
        ],
      );
      final fullBefore = full.serialize();
      expect(
        () => repeatProjectMask(
          full,
          source.steps.first.id,
          mask.id,
          newLayerId: () => 'new-mask',
        ),
        throwsFormatException,
      );
      expect(full.serialize(), fullBefore);
      final occupied = source.copyWith(
        steps: [
          source.steps.first,
          source.steps.last.copyWith(
            annotations: [defaultLayer('existing', 'rect')],
          ),
        ],
      );
      expect(
        () => repeatProjectMask(
          occupied,
          source.steps.first.id,
          mask.id,
          newLayerId: () => 'existing',
        ),
        throwsFormatException,
      );
      expect(source.serialize(), before);
    },
  );
}
