import 'dart:convert';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Friday 6 November 2026, 09:00 local.
final now = DateTime(2026, 11, 6, 9);

BoardTemplate t(String id) => templateById(id)!;

String boardOf(BoardsState s) => s.rows('boards').single.id;

void main() {
  group('catalog rules (every template)', () {
    test('30 templates: 14 Free and 16 Pro, six per group', () {
      expect(boardTemplates, hasLength(30));
      expect(boardTemplates.where((t) => !t.pro), hasLength(14));
      expect(boardTemplates.where((t) => t.pro), hasLength(16));
      final free = {
        TemplateGroup.study: 4,
        TemplateGroup.work: 3,
        TemplateGroup.personal: 2,
        TemplateGroup.creative: 2,
        TemplateGroup.planning: 3,
      };
      // The owner's list (2026-11-08): Personal Course Free, Moving Pro.
      expect(
        {
          for (final t in boardTemplates)
            if (!t.pro) t.id,
        },
        {
          'semester',
          'group-assignment',
          'exam-revision',
          'course',
          'project',
          'weekly',
          'ideas',
          'personal',
          'shopping',
          'content',
          'inspiration',
          'trip',
          'monthly',
          'daily',
        },
      );
      expect(freeTemplateCount, 14);
      expect(proTemplateCount, 16);
      for (final g in TemplateGroup.values) {
        final inGroup = boardTemplates.where((t) => t.group == g);
        expect(inGroup, hasLength(6), reason: '$g');
        expect(inGroup.where((t) => !t.pro), hasLength(free[g]), reason: '$g');
      }
      expect(boardTemplates.where((t) => t.featured != null), hasLength(6));
    });

    test('ids are unique, covers exist, featured ranks are unique', () {
      final ids = boardTemplates.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, isNot(contains('blank')));
      final featured = [
        for (final t in boardTemplates)
          if (t.featured != null) t.featured,
      ];
      expect(featured.toSet(), hasLength(featured.length));
      expect(
        boardTemplates.where((t) => t.featured != null).every((t) => !t.pro),
        isTrue,
        reason: 'featured templates are free',
      );
    });

    for (final x in boardTemplates)
      test('${x.id}: a complete, honest definition', () {
        for (final l in [x.name, x.goal, x.example]) {
          expect(l.en.trim(), isNotEmpty);
          expect(l.vi.trim(), isNotEmpty);
        }
        expect(x.tags, isNotEmpty);
        expect(coverById(x.cover), isNotNull, reason: x.cover);
        if (!x.pro) expect(coverById(x.cover)!.pro, isFalse, reason: x.cover);
        // Columns: 3 to 5, exactly one finished column, never by position.
        expect(x.columns.length, inInclusiveRange(3, 5));
        expect(x.columns.where((c) => c.done), hasLength(1));
        for (final c in x.columns) {
          expect(c.name.en.trim(), isNotEmpty);
          expect(c.name.vi.trim(), isNotEmpty);
          if (c.onlyWith != null)
            expect(
              x.fields.any(
                (f) =>
                    f.id == c.onlyWith && f.role == FieldRole.optionalColumns,
              ),
              isTrue,
            );
        }
        // Questions: a title, then at most four more; every one changes
        // something and explains what.
        expect(x.fields.first.role, FieldRole.title);
        expect(x.fields.length, inInclusiveRange(2, 5));
        expect(x.fields.map((f) => f.id).toSet(), hasLength(x.fields.length));
        for (final f in x.fields) {
          expect(f.label.vi.trim(), isNotEmpty, reason: f.id);
          expect(f.help.en.trim(), isNotEmpty, reason: f.id);
          expect(f.help.vi.trim(), isNotEmpty, reason: f.id);
          final allowed = switch (f.role) {
            FieldRole.title => [FieldKind.text],
            FieldRole.categories => [FieldKind.chips],
            FieldRole.milestone => [FieldKind.date, FieldKind.dateRange],
            FieldRole.optionalColumns => [FieldKind.toggle],
            _ => [FieldKind.select],
          };
          expect(allowed, contains(f.kind), reason: '${x.id}.${f.id}');
          if (f.kind == FieldKind.select) {
            expect(f.options.length, greaterThanOrEqualTo(2));
            if (f.role == FieldRole.columnSet)
              for (final o in f.options)
                expect(o.columns!.where((c) => c.done), hasLength(1));
            if (f.role == FieldRole.timeRange)
              expect(f.options.every((o) => o.time != null), isTrue);
            if (f.role == FieldRole.presentation)
              expect(
                f.options.every(
                  (o) => ['compact', 'detailed'].contains(o.presentation),
                ),
                isTrue,
              );
            if (f.role == FieldRole.sampleSet)
              for (final o in f.options)
                expect(x.samples.any((c) => c.set == o.id), isTrue);
          }
          if (f.kind == FieldKind.chips)
            expect(f.chipsDefault.length, inInclusiveRange(2, f.maxChips));
        }
        // Examples: 2 to 6, real columns and categories, valid anchors.
        expect(x.samples.length, inInclusiveRange(2, 8));
        final chips =
            x.fieldFor(FieldRole.categories)?.chipsDefault.length ?? 0;
        final dates = {
          for (final f in x.fields.where(
            (f) => f.role == FieldRole.milestone,
          )) ...[f.id, if (f.kind == FieldKind.dateRange) '${f.id}.end'],
        };
        for (final c in x.samples) {
          expect(c.title.vi.trim(), isNotEmpty);
          expect(c.column, inInclusiveRange(0, x.columns.length - 1));
          if (c.category != null) expect(c.category, lessThan(chips));
          expect(c.subtasks.length, lessThanOrEqualTo(6));
          expect(c.done, inInclusiveRange(0, c.subtasks.length));
          if (c.cover != null) {
            expect(coverById(c.cover), isNotNull, reason: c.cover);
            if (!x.pro) expect(coverById(c.cover)!.pro, isFalse);
          }
          if (c.anchor != null) expect(dates, contains(c.anchor));
        }
      });

    test('every template makes a valid board in both languages, twice, '
        'with fresh ids each time', () {
      for (final x in boardTemplates)
        for (final vi in [true, false]) {
          var s = createFromTemplate(
            BoardsState(),
            x,
            vi: vi,
            examples: true,
            now: now,
          );
          s = createFromTemplate(s, x, vi: vi, now: now);
          s.validate();
          final boards = s.rows('boards').toList();
          expect(boards, hasLength(2));
          final first = boards.first.id, second = boards.last.id;
          final firstCats = categoriesOf(s, first).map((c) => c.id).toSet();
          expect(
            categoriesOf(
              s,
              second,
            ).map((c) => c.id).toSet().intersection(firstCats),
            isEmpty,
          );
          // Examples only where asked for.
          expect(topTasks(s, board: second), isEmpty, reason: x.id);
          expect(topTasks(s, board: first), isNotEmpty, reason: x.id);
          expect(boards.first.str('template'), x.id);
          expect(boards.first.data['templateVersion'], x.version);
        }
    });
  });

  group('the generator', () {
    test('answers set the title, categories, key date and time view', () {
      final x = t('semester');
      final a = {
        ...defaultAnswers(x, vi: true, now: now),
        'title': 'HK2 2026–2027',
        'subjects': ['Giải tích', 'Vật lý'],
        'end': '2027-01-15',
        'range': 'month',
      };
      final s = buildBoard(BoardsState(), planBoard(x, a, vi: true, now: now));
      final b = s.rows('boards').single;
      expect(b.str('title'), 'HK2 2026–2027');
      expect(categoriesOf(s, b.id).map((c) => c.str('title')), [
        'Giải tích',
        'Vật lý',
      ]);
      expect(milestonesOf(b).single.label, 'Kết thúc học kỳ');
      expect(milestonesOf(b).single.day, DateTime(2027, 1, 15));
      expect(b.data['span'], {'unit': 'month', 'count': 1});
      expect(timePinned(b), isTrue);
      expect(topTasks(s), isEmpty); // examples are off by default
      final done = columnsOf(s, b.id).where((c) => c.flag('done'));
      expect(done.single.str('title'), 'Hoàn thành');
    });

    test('a skipped date stays skipped; examples never invent one', () {
      final x = t('semester');
      final a = {...defaultAnswers(x, vi: false, now: now), examplesKey: true};
      final s = buildBoard(BoardsState(), planBoard(x, a, vi: false, now: now));
      final b = s.rows('boards').single;
      expect(milestonesOf(b), isEmpty);
      final lab = topTasks(
        s,
      ).firstWhere((c) => c.str('title') == 'Lab 1: set up the project');
      // Counted from today when the example says so.
      expect(dueDay(lab), DateTime(2026, 11, 9));
    });

    test('a toggle drops its column; a select swaps the column set', () {
      var x = t('project');
      var a = {...defaultAnswers(x, vi: true, now: now), 'review': false};
      var s = buildBoard(BoardsState(), planBoard(x, a, vi: true, now: now));
      expect(columnsOf(s, boardOf(s)).map((c) => c.str('title')), [
        'Việc chờ',
        'Đang làm',
        'Xong',
      ]);
      expect(timePinned(s.rows('boards').single), isFalse);
      x = t('shopping');
      a = {...defaultAnswers(x, vi: true, now: now), 'style': 'store'};
      s = buildBoard(BoardsState(), planBoard(x, a, vi: true, now: now));
      final cols = columnsOf(s, boardOf(s));
      expect(cols.last.str('title'), 'Đã mua');
      expect(cols.where((c) => c.flag('done')).single.str('title'), 'Đã mua');
    });

    test('answers are checked before anything is made', () {
      final x = t('semester');
      final base = defaultAnswers(x, vi: true, now: now);
      expect(validateAnswers(x, base), isEmpty);
      expect(validateAnswers(x, {...base, 'title': '  '}).keys, ['title']);
      expect(
        validateAnswers(x, {
          ...base,
          'subjects': ['Toán', 'toán'],
        }).keys,
        ['subjects'],
      );
      expect(
        validateAnswers(x, {
          ...base,
          'subjects': List.generate(13, (i) => 'M$i'),
        }).keys,
        ['subjects'],
      );
      expect(
        () => planBoard(x, {...base, 'title': ''}, vi: true),
        throwsFormatException,
      );
    });

    test('a blank board takes its own column names; the last is finished', () {
      final s = buildBoard(
        BoardsState(),
        blankPlan(title: 'Của tôi', vi: true, columns: ['Ý tưởng', 'Làm', '']),
      );
      final cols = columnsOf(s, boardOf(s));
      expect(cols.map((c) => c.str('title')), ['Ý tưởng', 'Làm']);
      expect(cols.last.flag('done'), isTrue);
      expect(categoriesOf(s, boardOf(s)), isEmpty);
      expect(topTasks(s), isEmpty);
    });

    test('key dates can be added to any board later', () {
      var s = createKanbanBoard(BoardsState(), title: 'X', now: now);
      final b = boardOf(s);
      s = setMilestones(s, b, [
        (label: 'Demo', day: DateTime(2026, 12, 1), minute: null),
        (label: 'Kickoff', day: DateTime(2026, 11, 10), minute: null),
      ]);
      s.validate();
      expect(milestonesOf(s.get('boards', b)).map((m) => m.label), [
        'Kickoff',
        'Demo',
      ]);
    });
  });

  group('compatibility', () {
    test('fields from other builds are kept, untouched and unread', () {
      var s = createFromTemplate(
        BoardsState(),
        t('semester'),
        vi: true,
        examples: true,
        now: now,
      );
      final b = s.rows('boards').single;
      final card = topTasks(s).first;
      // Data an unreleased build may have written: a board type, a
      // product, a post, an exam, subjects and classes rows.
      s = s.put(
        'boards',
        b.copy({
          'type': 'shopping',
          'budget': {'x': 1},
        }),
      );
      s = s.put(
        'tasks',
        card.copy({
          'product': {'price': 120000, 'currency': 'VND'},
          'post': {'format': 'video'},
          'exam': {'day': '2026-12-01', 'time': '08:00'},
        }),
      );
      final cat = categoriesOf(s, b.id).first.id;
      s = s.put(
        'subjects',
        BoardRecord({
          'id': 'sub0',
          'board': b.id,
          'category': cat,
          'code': 'WEB201',
        }),
      );
      s = s.put(
        'classes',
        BoardRecord({
          'id': 'cls0',
          'board': b.id,
          'category': cat,
          'weekday': 1,
          'startMinute': 420,
          'endMinute': 570,
          'zone': 'Asia/Ho_Chi_Minh',
        }),
      );
      s.validate();
      // Round trips keep every field exactly.
      final json = jsonDecode(jsonEncode(s.toJson()));
      expect(BoardsState.fromJson(json).toJson(), s.toJson());
      expect(readBackup(exportBackup(s)).toJson(), s.toJson());
      // Moving, duplicating and merging keep them too.
      final moved = moveCard(
        s,
        card.id,
        column: columnsOf(s, b.id).last.id,
        index: 0,
      );
      expect(moved.get('tasks', card.id).data['product'], {
        'price': 120000,
        'currency': 'VND',
      });
      final merged = restoreBackup(
        s,
        readBackup(exportBackup(s)),
        replace: false,
        confirmed: true,
      );
      merged.validate();
      expect(merged.rows('classes'), hasLength(2));
      // The board works like any other.
      expect(columnsOf(s, b.id), hasLength(3));
    });

    test('older boards without the new fields keep working', () {
      var s = createKanbanBoard(BoardsState(), title: 'Cũ', now: now);
      final b = s.rows('boards').single;
      final legacy = BoardRecord({
        for (final e in b.data.entries)
          if (![
            'timePinned',
            'span',
            'view',
            'templateVersion',
          ].contains(e.key))
            e.key: e.value,
      });
      s = s.put('boards', legacy);
      s.validate();
      expect(timePinned(s.get('boards', b.id)), isTrue);
      expect(milestonesOf(s.get('boards', b.id)), isEmpty);
    });
  });
}
