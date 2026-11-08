import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test('preset order and free/pro boundary are stable', () {
    expect(templatePresets.map((p) => p.id), [
      'blank',
      'study',
      'personal',
      'shopping',
      'project',
      'content',
      'goals',
      'event',
      'moodboard',
      'renovation',
    ]);
    expect(templatePresets.where((p) => !p.pro).length, 5);
    expect(templatePresets.take(5).every((p) => !p.pro), isTrue);
    expect(templatePresets.skip(5).every((p) => p.pro), isTrue);
    expect(presetById('missing'), isNull);
    final blank = presetById('blank')!;
    expect(blank.columns, [
      ('To Do', 'Cần làm'),
      ('Doing', 'Đang làm'),
      ('Done', 'Xong'),
    ]);
    expect(blank.cards, isEmpty);
    expect(blank.categories, isEmpty);
    expect(presetById('study')!.categories.map((c) => (c.nameEn, c.nameVi)), [
      ('Maths', 'Toán'),
      ('Literature', 'Văn'),
      ('English', 'Anh'),
      ('Physics', 'Lý'),
    ]);
    expect(presetById('project')!.columns.map((c) => c.$1), [
      'Backlog',
      'In Progress',
      'Review',
      'Done',
    ]);
    expect(presetById('content')!.columns.map((c) => c.$1), [
      'Ideas',
      'Draft',
      'Edit',
      'Publish',
    ]);
    expect(presetById('goals')!.columns.map((c) => c.$1), [
      'Plan',
      'Do',
      'Review',
    ]);
  });

  for (final p in templatePresets) {
    test('${p.id}: complete bilingual data and valid local references', () {
      expect(presetById(p.id), same(p));
      for (final value in [p.nameEn, p.nameVi, p.blurbEn, p.blurbVi]) {
        expect(value.trim(), isNotEmpty);
      }
      expect(coverById(p.cover), isNotNull);
      for (final column in p.columns) {
        expect(column.$1.trim(), isNotEmpty);
        expect(column.$2.trim(), isNotEmpty);
      }
      final hues = p.categories.map((c) => c.hue).toList();
      expect(hues.toSet().length, hues.length);
      for (final c in p.categories) {
        expect(c.nameEn.trim(), isNotEmpty);
        expect(c.nameVi.trim(), isNotEmpty);
        expect(c.hue, inInclusiveRange(0, 7));
      }
      if (p.id == 'blank') return;
      expect(p.cards.length, inInclusiveRange(8, 14));
      expect(p.categories.length, inInclusiveRange(3, 5));
      expect(p.cards.map((c) => c.column).toSet().length, p.columns.length);
      final checklistCount = p.cards.where((c) => c.subtasks.isNotEmpty).length;
      expect(
        checklistCount,
        inInclusiveRange(p.cards.length ~/ 2, (p.cards.length / 2).ceil() + 1),
      );
      expect(
        p.cards.any((c) => c.done > 0 && c.done < c.subtasks.length),
        isTrue,
      );
      expect(
        p.cards.where((c) => c.cover != null).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        p.cards.where((c) => c.dueInDays != null).length,
        greaterThanOrEqualTo(2),
      );
      for (final c in p.cards) {
        expect(c.titleEn.trim(), isNotEmpty);
        expect(c.titleVi.trim(), isNotEmpty);
        expect(c.noteEn.isEmpty, c.noteVi.isEmpty);
        expect(c.column, inInclusiveRange(0, p.columns.length - 1));
        if (c.category != null) {
          expect(c.category, inInclusiveRange(0, p.categories.length - 1));
        }
        expect(c.subtasks.length, lessThanOrEqualTo(6));
        expect(c.done, inInclusiveRange(0, c.subtasks.length));
        for (final s in c.subtasks) {
          expect(s.$1.trim(), isNotEmpty);
          expect(s.$2.trim(), isNotEmpty);
        }
        if (c.cover != null) {
          expect(coverById(c.cover), isNotNull, reason: '${p.id}: ${c.cover}');
          if (!p.pro) expect(coverById(c.cover)!.pro, isFalse);
        }
        if (p.id == 'moodboard') expect(c.cover, isNotNull);
      }
      if (!p.pro) expect(coverById(p.cover)!.pro, isFalse);
    });
  }
}
