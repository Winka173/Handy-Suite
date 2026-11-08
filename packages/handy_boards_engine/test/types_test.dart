import 'dart:convert';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// Friday 6 November 2026, 09:00 local.
final now = DateTime(2026, 11, 6, 9);

BoardsState make(String preset, {bool sample = true, String? id}) =>
    createKanbanBoard(
      BoardsState(),
      title: preset,
      preset: presetById(preset),
      vi: true,
      now: now,
      sample: sample,
      boardId: id,
    );

String boardOf(BoardsState s) => s.rows('boards').single.id;

BoardRecord card(BoardsState s, String title) =>
    topTasks(s).firstWhere((t) => t.str('title') == title);

String column(BoardsState s, String title) =>
    s.rows('statuses').firstWhere((c) => c.str('title') == title).id;

void main() {
  group('board types', () {
    test('a board without a type is standard and nothing rewrites it', () {
      final s = createKanbanBoard(BoardsState(), title: 'Mine', now: now);
      final b = s.get('boards', boardOf(s));
      expect(boardType(b), 'standard');
      final legacy = s.put('boards', b.copy({'type': null}));
      legacy.validate();
      expect(boardType(legacy.get('boards', b.id)), 'standard');
      // An old preset id says nothing about the type.
      final old = legacy.put(
        'boards',
        legacy.get('boards', b.id).copy({'template': 'goals'}),
      );
      expect(boardType(old.get('boards', b.id)), 'standard');
    });

    test('the gallery is four kinds; look-alike presets are gone', () {
      expect(templatePresets.map((p) => p.type).toSet(), {
        'standard',
        'study',
        'shopping',
        'content',
      });
      for (final gone in ['goals', 'event', 'moodboard', 'renovation'])
        expect(presetById(gone), isNull);
      expect(
        templatePresets.where((p) => p.pro).map((p) => p.type).toSet(),
        proBoardTypes,
      );
    });

    test('module data only goes on its own kind of board', () {
      final s = createKanbanBoard(BoardsState(), title: 'Plain', now: now);
      final b = boardOf(s);
      final t = newTask(s, b, 'x');
      final s2 = saveTask(s, t, now: now);
      expect(() => setProduct(s2, t.id, price: 1), throwsFormatException);
      expect(() => setPost(s2, t.id), throwsFormatException);
      expect(() => setExam(s2, t.id, day: now), throwsFormatException);
      expect(() => setBudget(s2, b, amount: 10), throwsFormatException);
      expect(
        () => saveClass(
          s2,
          board: b,
          category: 'x',
          weekday: 1,
          startMinute: 0,
          endMinute: 60,
        ),
        throwsFormatException,
      );
    });

    test('a standard board can become a study board, never the reverse', () {
      final s = make('personal');
      final b = boardOf(s);
      final study = convertToStudy(s, b);
      expect(boardTypeOf(study, b), 'study');
      expect(categoriesOf(study, b), hasLength(categoriesOf(s, b).length));
      expect(() => convertToStudy(study, b), throwsFormatException);
    });
  });

  group('study', () {
    test(
      'the university sample has subjects, a timetable, exams and a term',
      () {
        final s = make('study');
        final b = boardOf(s);
        final subjects = categoriesOf(s, b);
        expect(subjects.map((c) => c.str('title')), [
          'Lập trình Web',
          'Cơ sở dữ liệu',
          'Mạng máy tính',
          'Tiếng Anh B2',
        ]);
        expect(subjectOf(s, subjects[1].id)!.str('code'), 'DB202');
        expect(subjectOf(s, subjects[3].id)!.number('credits'), 4);
        expect(classesOf(s, b), hasLength(6));
        final term = termOf(s.get('boards', b))!;
        expect(term.start, DateTime(2026, 11, 2)); // the Monday of that week
        expect(term.end.difference(term.start).inDays, 15 * 7 - 1);
        final exams = examsOf(s, b);
        expect(exams, hasLength(3));
        expect(exams.first.str('title'), 'Thi nói giữa kỳ Tiếng Anh');
        expect(examMoment(exams.first), DateTime(2026, 11, 12, 14));
        // An exam's moment is not its due date.
        expect(exams.first.data['due'], isNull);
      },
    );

    test('empty structure keeps the term, drops the sample subjects', () {
      final s = make('study', sample: false);
      final b = boardOf(s);
      expect(categoriesOf(s, b), isEmpty);
      expect(classesOf(s, b), isEmpty);
      expect(topTasks(s), isEmpty);
      expect(termOf(s.get('boards', b)), isNotNull);
    });

    test('next class, a day of classes, editing and deleting a slot', () {
      var s = make('study');
      final b = boardOf(s);
      // Friday 09:00: the 07:30 Lab is running until 09:30.
      final next = nextClass(s, b, now)!;
      expect(next.session.number('weekday'), 5);
      expect(next.start, DateTime(2026, 11, 6, 7, 30));
      expect(classesOn(s, b, DateTime(2026, 11, 3)).map((c) => c.str('room')), [
        'P.204',
        'P.402',
      ]);
      final web = categoriesOf(s, b).first.id;
      s = saveClass(
        s,
        board: b,
        category: web,
        weekday: 6,
        startMinute: 8 * 60,
        endMinute: 10 * 60,
        room: 'P.101',
      );
      final saturday = classesOn(s, b, DateTime(2026, 11, 7)).single;
      s = saveClass(
        s,
        id: saturday.id,
        board: b,
        category: web,
        weekday: 6,
        startMinute: 9 * 60,
        endMinute: 11 * 60,
        room: 'P.102',
      );
      expect(s.get('classes', saturday.id).str('room'), 'P.102');
      s = deleteClass(s, saturday.id);
      expect(classesOn(s, b, DateTime(2026, 11, 7)), isEmpty);
      // Outside the term nothing is held.
      expect(classesOn(s, b, DateTime(2027, 6, 1)), isEmpty);
      expect(
        () => saveClass(
          s,
          board: b,
          category: web,
          weekday: 1,
          startMinute: 600,
          endMinute: 500,
        ),
        throwsFormatException,
      );
    });

    test(
      'renaming a subject keeps its classes; deleting it keeps its cards',
      () {
        var s = make('study');
        final b = boardOf(s);
        final net = categoriesOf(s, b)[2];
        s = s.put('categories', net.copy({'title': 'Mạng'}));
        expect(
          classesOf(s, b).where((c) => c.str('category') == net.id),
          hasLength(2),
        );
        final cards = topTasks(
          s,
          board: b,
        ).where((t) => t.str('category') == net.id).length;
        final web = categoriesOf(s, b).first.id;
        s = deleteCategory(s, net.id, moveTo: web);
        s.validate();
        expect(
          classesOf(s, b).where((c) => c.str('category') == net.id),
          isEmpty,
        );
        expect(subjectOf(s, net.id), isNull);
        expect(
          topTasks(s, board: b).where((t) => t.str('category') == web).length,
          greaterThanOrEqualTo(cards),
        );
      },
    );

    test('an exam keeps its own moment; one reminder per card', () {
      var s = make('study');
      final b = boardOf(s);
      s = addExam(
        s,
        b,
        title: 'Thi cuối kỳ Web',
        category: categoriesOf(s, b).first.id,
        day: DateTime(2026, 12, 20),
        minute: 7 * 60 + 30,
        location: 'P.301',
        now: now,
        id: 'e0000000-0000-4000-8000-000000000001',
      );
      final exam = s.get('tasks', 'e0000000-0000-4000-8000-000000000001');
      expect(examMoment(exam), DateTime(2026, 12, 20, 7, 30));
      expect(exam.data['due'], isNull);
      s = setReminderAt(s, exam.id, DateTime(2026, 12, 19, 20));
      s = setReminderAt(s, exam.id, DateTime(2026, 12, 20, 6));
      expect(s.related('reminders', exam.id), hasLength(1));
      s = setReminderAt(s, exam.id, null);
      expect(s.related('reminders', exam.id), isEmpty);
      // Moving it keeps the exam and its subject.
      s = moveCard(s, exam.id, column: columnsOf(s, b)[1].id, index: 0);
      expect(examMoment(s.get('tasks', exam.id)), isNotNull);
    });
  });

  group('shopping', () {
    test('money reads and writes without floating point', () {
      expect(parseMoney('1.250.000', 'VND'), 1250000);
      expect(parseMoney('1,250,000 đ', 'VND'), 1250000);
      expect(parseMoney('12,50', 'USD'), 1250);
      expect(parseMoney('1,250,000.5', 'USD'), 125000050);
      expect(parseMoney('abc', 'VND'), isNull);
      expect(moneyText(1250000, 'VND'), '1.250.000 đ');
      expect(moneyText(1250, 'USD', vi: false), r'$12.50');
      expect(moneyText(-30000, 'VND'), '−30.000 đ');
    });

    test('planned, spent and left come from stages, not the last column', () {
      var s = make('shopping');
      final b = boardOf(s);
      var totals = shoppingTotals(s, b);
      final vnd = totals.byCurrency['VND']!;
      expect(vnd.planned, 3158000);
      expect(vnd.spent, 1070000);
      expect(vnd.toBuy, 2088000);
      expect(totals.unpriced, 1);
      expect(totals.left, 5000000 - 1070000);

      // Ordering the lamp spends its price once, however often it moves.
      final lamp = card(s, 'Đèn bàn học LED').id;
      s = moveCard(s, lamp, column: column(s, 'Đã đặt mua'), index: 0);
      s = moveCard(s, lamp, column: column(s, 'Đã nhận'), index: 0);
      totals = shoppingTotals(s, b);
      expect(totals.byCurrency['VND']!.spent, 1070000 + 350000);
      expect(totals.byCurrency['VND']!.planned, 3158000);

      // A copy of a bought product is a plan, never money spent.
      final pans = card(s, 'Bộ 2 chảo chống dính').id;
      final copied = duplicateCard(s, pans, now: now);
      final copy = topTasks(copied).firstWhere(
        (t) => t.str('title') == 'Bộ 2 chảo chống dính' && t.id != pans,
      );
      expect(cardStage(copied, copy), 'want');
      expect(
        shoppingTotals(copied, b).byCurrency['VND']!.spent,
        1070000 + 350000,
      );
      expect(
        shoppingTotals(copied, b).byCurrency['VND']!.planned,
        3158000 + 450000,
      );

      // Trash and archive leave the sums; restoring brings it back.
      final trashed = s.put(
        'tasks',
        s.get('tasks', pans).copy({'trashed': true}),
      );
      expect(
        shoppingTotals(trashed, b).byCurrency['VND']!.spent,
        1070000 + 350000 - 450000,
      );

      // A cancelled order is not spending.
      s = addColumn(s, b, 'Đã huỷ');
      final cancelled = column(s, 'Đã huỷ');
      s = setColumnStage(s, cancelled, 'cancelled');
      s = moveCard(s, pans, column: cancelled, index: 0);
      totals = shoppingTotals(s, b);
      expect(totals.byCurrency['VND']!.spent, 1070000 + 350000 - 450000);
      expect(totals.byCurrency['VND']!.planned, 3158000 - 450000);
    });

    test('mixed currencies stay apart; unit prices compare like with like', () {
      var s = make('shopping');
      final b = boardOf(s);
      final chair = card(s, 'Ghế ngồi học').id;
      s = setProduct(s, chair, price: 4999, currency: 'USD', qty: 2);
      final totals = shoppingTotals(s, b);
      expect(totals.byCurrency['USD']!.planned, 9998);
      expect(totals.unpriced, 0);
      expect(totals.left, 5000000 - 1070000);
      final big = productOf(card(s, 'Nước giặt 3,6 kg'))!;
      final small = productOf(card(s, 'Nước giặt 2,4 kg'))!;
      // 189.000 đ / 3600 g against 139.000 đ / 2400 g.
      expect(unitPrice(big)! < unitPrice(small)!, isTrue);
      expect(unitPrice(productOf(card(s, 'Bộ chăn ga gối'))!), isNull);
    });

    test('bad prices, quantities and stages are refused', () {
      final s = make('shopping');
      final pans = card(s, 'Bộ 2 chảo chống dính');
      for (final bad in [
        {'price': -1, 'currency': 'VND', 'qty': 1},
        {'price': 1.5, 'currency': 'VND', 'qty': 1},
        {'price': 1, 'currency': 'VND', 'qty': 0},
        {'price': 1, 'currency': 'XXX', 'qty': 1},
      ])
        expect(
          () => s.put('tasks', pans.copy({'product': bad})).validate(),
          throwsFormatException,
          reason: '$bad',
        );
      expect(
        () => setColumnStage(s, pans.str('status'), 'published'),
        throwsFormatException,
      );
    });
  });

  group('content', () {
    test('scheduled and published are told apart', () {
      var s = make('content');
      final b = boardOf(s);
      final upcoming = scheduledPosts(s, b);
      expect(upcoming.map((t) => t.str('title')), [
        'Ảnh: góc làm việc buổi sáng',
        'Video 30 giây: 3 thói quen học tiếng Anh buổi sáng',
        'Carousel: 5 app học miễn phí',
      ]);
      expect(postState(s, upcoming.first), 'scheduled');
      final records = publishedRecords(s, b);
      expect(records.map((r) => r.platform), ['tiktok', 'tiktok']);
      expect(records.every((r) => r.url == null), isTrue); // never made up
      final idea = card(s, 'Bài viết: cách mình lên kế hoạch tuần');
      expect(postState(s, idea), 'idea');
    });

    test('publishing asks for a record; the link is only what was typed', () {
      var s = make('content');
      final b = boardOf(s);
      final photo = card(s, 'Ảnh: góc làm việc buổi sáng').id;
      s = moveCard(s, photo, column: column(s, 'Đã đăng'), index: 0);
      expect(needsPublishRecord(s, s.get('tasks', photo)), isTrue);
      expect(postState(s, s.get('tasks', photo)), 'published');
      s = recordPublished(
        s,
        photo,
        platform: 'instagram',
        at: DateTime(2026, 11, 7, 8, 5),
        url: 'https://www.instagram.com/p/abc123/',
      );
      expect(needsPublishRecord(s, s.get('tasks', photo)), isFalse);
      expect(
        publishedRecords(s, b).first.url,
        'https://www.instagram.com/p/abc123/',
      );
      expect(
        () => recordPublished(
          s,
          photo,
          platform: 'instagram',
          at: now,
          url: 'not a link',
        ).validate(),
        throwsFormatException,
      );
      // A copy starts unpublished, unscheduled, before the published column.
      final copied = duplicateCard(s, photo, now: now);
      final copy = topTasks(copied).firstWhere(
        (t) => t.str('title') == 'Ảnh: góc làm việc buổi sáng' && t.id != photo,
      );
      expect(postOf(copy)!['published'], isEmpty);
      expect(postOf(copy)!['scheduleAt'], isNull);
      expect(cardStage(copied, copy), isNot('published'));
    });

    test('editing a post keeps what was recorded; a repeat starts clean', () {
      var s = make('content');
      final video = card(s, 'Hậu trường buổi quay tuần trước').id;
      s = setPost(
        s,
        video,
        format: 'video',
        platforms: ['tiktok', 'instagram'],
        caption: 'Hậu trường',
      );
      expect(postOf(s.get('tasks', video))!['published'], hasLength(1));
      final weekly = s.get('tasks', card(s, 'Ảnh: góc làm việc buổi sáng').id);
      s = s.put('tasks', weekly.copy({'repeat': 'weekly'}));
      s = moveCard(s, weekly.id, column: column(s, 'Đã đăng'), index: 0);
      s = recordPublished(s, weekly.id, platform: 'instagram', at: now);
      final next = s.get('tasks', s.get('tasks', weekly.id).str('repeatedAs'));
      expect(postOf(next)!['published'], isEmpty);
      expect(
        DateTime.parse(postOf(next)!['scheduleAt'] as String)
            .difference(DateTime.parse(postOf(weekly)!['scheduleAt'] as String))
            .inDays,
        7,
      );
    });
  });

  group('portability', () {
    test('backups keep every module; old backups still open', () {
      var s = make('study', id: 'b0000000-0000-4000-8000-000000000001');
      s = createKanbanBoard(
        s,
        title: 'Mua',
        preset: presetById('shopping'),
        vi: true,
        now: now,
      );
      s = createKanbanBoard(
        s,
        title: 'Kênh',
        preset: presetById('content'),
        vi: true,
        now: now,
      );
      final json = jsonDecode(jsonEncode(s.toJson()));
      expect(json['schema'], 4);
      expect(BoardsState.fromJson(json).toJson(), s.toJson());
      expect(readBackup(exportBackup(s)).toJson(), s.toJson());
      final v3 = {...json, 'schema': 3};
      expect(BoardsState.fromJson(v3).rows('classes'), hasLength(6));
    });

    test('merging a backup gives every module new ids that still agree', () {
      final s = make('study');
      final b = boardOf(s);
      final merged = restoreBackup(
        s,
        readBackup(exportBackup(s)),
        replace: false,
        confirmed: true,
      );
      merged.validate();
      final boards = merged.rows('boards').toList();
      expect(boards, hasLength(2));
      final copy = boards.firstWhere((x) => x.id != b).id;
      final cats = categoriesOf(merged, copy).map((c) => c.id).toSet();
      expect(classesOf(merged, copy), hasLength(6));
      expect(
        classesOf(merged, copy).every((c) => cats.contains(c.str('category'))),
        isTrue,
      );
      expect(
        merged
            .rows('subjects')
            .where((r) => r.str('board') == copy)
            .every((r) => cats.contains(r.str('category'))),
        isTrue,
      );
      expect(examsOf(merged, copy), hasLength(3));
    });

    test('duplicating a board copies its module, never its spending', () {
      var s = make('study');
      final b = boardOf(s);
      s = duplicateBoard(s, b, title: 'Học kỳ 2', now: now);
      final copy = s.rows('boards').firstWhere((x) => x.id != b).id;
      final cats = categoriesOf(s, copy).map((c) => c.id).toSet();
      expect(classesOf(s, copy), hasLength(6));
      expect(
        classesOf(s, copy).every((c) => cats.contains(c.str('category'))),
        isTrue,
      );
      var shop = make('shopping');
      final sb = boardOf(shop);
      shop = duplicateBoard(shop, sb, title: 'Lần sau', now: now);
      final other = shop.rows('boards').firstWhere((x) => x.id != sb).id;
      expect(shoppingTotals(shop, other).byCurrency['VND']!.spent, 0);
      expect(shoppingTotals(shop, other).byCurrency['VND']!.planned, 3158000);
    });
  });
}
