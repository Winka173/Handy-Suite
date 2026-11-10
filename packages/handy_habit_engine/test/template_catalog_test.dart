import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';

void main() {
  test('catalog IDs are unique and original habit IDs survive', () {
    expect(habitPresets.length, greaterThanOrEqualTo(32));
    expect(routineTemplateCatalog.length, greaterThanOrEqualTo(8));
    final ids = [
      ...habitPresets.map((p) => p.id),
      ...routineTemplateCatalog.map((p) => p.id),
    ];
    expect(ids.toSet().length, ids.length);
    expect(
      habitPresets.map((p) => p.id),
      containsAll([
        'water-morning',
        'make-bed',
        'stretch',
        'plan-day',
        'tidy-desk',
        'journal',
        'prep-tomorrow',
        'gratitude',
        'walk',
        'steps',
        'workout',
        'pushups',
        'read',
        'language',
        'review-cards',
        'deep-work',
        'bed-time',
        'no-caffeine',
        'wind-down',
        'same-wake',
        'cleanse',
        'sunscreen',
        'moisturise',
        'water',
        'phone-free-meal',
        'social-cap',
        'inbox-zero',
        'screen-off',
        'dishes',
        'ten-minute-tidy',
        'laundry',
        'plants',
      ]),
    );
    expect(templateCollections.length, 13);
    expect(
      habitPresets.map((p) => p.collection).toSet(),
      templateCollections.keys.toSet(),
    );
  });
  test('every habit has EN/VI content and valid, realistic defaults', () {
    for (final p in habitPresets) {
      expect(p.en.trim(), isNotEmpty, reason: p.id);
      expect(p.vi.trim(), isNotEmpty);
      expect(p.descriptionEn.trim(), isNotEmpty);
      expect(p.descriptionVi.trim(), isNotEmpty);
      expect(p.icon, greaterThan(0));
      expect(p.color >> 24, 255);
      expect(p.stored, inInclusiveRange(1000, 10000000));
      final h = Habit(
        id: p.id,
        title: p.en,
        created: '2024-01-01',
        type: p.type,
        direction: p.direction,
        unit: p.type == 'duration' ? 'min' : p.unitEn,
        schedules: [
          Schedule(
            id: 'schedule',
            from: '2024-01-01',
            kind: p.direction == 'reduce' ? 'daily' : p.schedule,
            target: p.direction == 'reduce' ? 1000 : p.stored,
            weekdays: p.weekdays,
            weeklyTarget: p.perWeek,
          ),
        ],
        negativeGoals: p.direction == 'reduce'
            ? [
                NegativeGoal(
                  id: 'limit',
                  from: '2024-01-01',
                  window: p.window,
                  limit: p.limit * 1000,
                ),
              ]
            : [],
      );
      expect(Habit.fromJson(h.toJson()).toJson(), h.toJson());
      if (p.type == 'quantity') {
        expect(p.unitEn, isNotEmpty);
        expect(p.unitVi, isNotEmpty);
      }
    }
    expect(
      habitPresets.where((p) => p.direction == 'reduce').length,
      greaterThanOrEqualTo(4),
    );
  });
  test(
    'routine previews match each locale and instantiate independent IDs',
    () {
      for (final p in routineTemplateCatalog) {
        final a = p.instantiate(), b = p.instantiate(vietnamese: true);
        expect(a.id, isNot(b.id));
        expect(a.title, p.en);
        expect(b.title, p.vi);
        expect(a.steps.length, p.steps.length);
        expect(a.steps.fold(0, (n, s) => n + s.seconds), p.seconds);
        expect(
          a.steps
              .map((s) => s.id)
              .toSet()
              .intersection(b.steps.map((s) => s.id).toSet()),
          isEmpty,
        );
        expect(a.weekdays, p.weekdays);
        expect(p.seconds, inInclusiveRange(180, 3600));
        for (var i = 0; i < a.steps.length; i++) {
          expect(a.steps[i].title, p.steps[i].$1);
          expect(b.steps[i].title, p.steps[i].$2);
          expect(a.steps[i].habit, isNull);
        }
      }
    },
  );
  test(
    'search folds precomposed and decomposed accents and both languages',
    () {
      expect(templateMatches('NUOC NGOT', ['Bớt nước ngọt']), isTrue);
      expect(templateMatches('đọc', ['Đọc sách']), isTrue);
      expect(templateMatches('doc', ['Đọc sách']), isTrue);
      expect(templateMatches('nước', ['nuo\u0301c']), isTrue);
      expect(
        templateMatches('social less', ['Check social media less often']),
        isTrue,
      );
      expect(templateMatches('zzzz', ['Đọc sách']), isFalse);
    },
  );
}
