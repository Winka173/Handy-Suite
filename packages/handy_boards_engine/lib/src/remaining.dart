part of '../handy_boards_engine.dart';

void validateWorkingCalendar(Json c) {
  final weekdays = (c['weekdays'] as List? ?? [1, 2, 3, 4, 5]);
  if (weekdays.isEmpty ||
      weekdays.toSet().length != weekdays.length ||
      weekdays.any((d) => d is! int || d < 1 || d > 7))
    throw const FormatException('Select at least one unique working weekday');
  final minutes = c['minutesPerDay'] ?? 480, start = c['startMinute'] ?? 540;
  if (minutes is! int ||
      minutes < 1 ||
      minutes > 1440 ||
      start is! int ||
      start < 0 ||
      start + minutes > 1440)
    throw const FormatException('Working hours must fit within one day');
  final holidays = (c['holidays'] as List? ?? []);
  if (holidays.length > 3660)
    throw const FormatException('At most 3660 holidays');
  for (final date in holidays) day(date as String);
}

Json studyReport(BoardsState s, String board, DateTime now) {
  s.get('boards', board);
  final subjects = <Json>[];
  for (final subject
      in s.rows('subjects').where((r) => r.str('board') == board)) {
    final category = s.get('categories', subject.str('category')),
        tasks = topTasks(
          s,
          board: board,
        ).where((t) => t.str('category') == category.id).toList(),
        grades = s
            .rows('grades')
            .where((g) => g.str('category') == category.id)
            .toList(),
        exams = tasks.where((t) => t.str('kind') == 'exam').toList(),
        stats = summary(s, tasks, now: now);
    Json? plan;
    String? warning;
    if (grades.isNotEmpty) {
      try {
        plan = gradePlan(
          grades,
          target: (subject.data['target'] as num? ?? 70).toDouble(),
          normalize: subject.flag('normalize'),
        );
      } on FormatException catch (e) {
        warning = e.message;
      }
    }
    final upcoming =
        exams.where((t) => !completed(s, t) && t.data['due'] != null).toList()
          ..sort(
            (a, b) => deadlineSort(
              object(a.data['due']),
            ).compareTo(deadlineSort(object(b.data['due']))),
          );
    final taskIds = tasks.map((t) => t.id).toSet();
    final sessions = s
        .rows('sessions')
        .where((r) => taskIds.contains(r.str('task')));
    subjects.add({
      'category': category.id,
      'title': category.str('title'),
      'credits': subject.number('credits'),
      'progress': stats,
      'grade': plan,
      'gradeWarning': warning,
      'graded': grades.where((g) => g.data['earned'] != null).length,
      'assessments': grades.length,
      'exams': exams.length,
      'nextExam': upcoming.firstOrNull?.id,
      'missingExamDates': exams
          .where((t) => t.data['due'] == null && !completed(s, t))
          .length,
      'savedFocusSeconds': sessions.fold<int>(
        0,
        (n, r) => n + r.number('elapsed'),
      ),
      'runningSessions': sessions
          .where((r) => r.data['runningAt'] != null)
          .length,
      'reasons': [
        if (stats['overdue'] > 0) 'overdue',
        if (warning != null) 'invalid weights',
        if (plan?['feasible'] == false) 'target infeasible',
        if (exams.any((t) => t.data['due'] == null && !completed(s, t)))
          'missing exam date',
      ],
    });
  }
  return {
    'board': board,
    'generatedAt': now.toUtc().toIso8601String(),
    'subjects': subjects,
    'unweighted': subjects.any((r) => (r['credits'] as int) == 0),
    'credits': subjects.fold<int>(0, (n, r) => n + (r['credits'] as int)),
  };
}

String studyReportCsv(BoardsState s, String board, DateTime now) {
  String cell(Object? v) {
    var text = v?.toString() ?? '';
    if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final report = studyReport(s, board, now);
  return [
    [
      'Subject',
      'Credits',
      'Tasks',
      'Complete',
      'Overdue',
      'Exams',
      'Graded',
      'Assessments',
      'CurrentPercent',
      'RequiredPercent',
      'TargetFeasible',
      'GradeWarning',
      'SavedFocusSeconds',
    ].map(cell).join(','),
    for (final raw in report['subjects'] as List)
      (() {
        final r = object(raw),
            p = object(r['progress']),
            g = object(r['grade'] ?? {});
        return [
          r['title'],
          r['credits'],
          p['total'],
          p['done'],
          p['overdue'],
          r['exams'],
          r['graded'],
          r['assessments'],
          g['currentPercent'],
          g['requiredPercent'],
          g['feasible'],
          r['gradeWarning'],
          r['savedFocusSeconds'],
        ].map(cell).join(',');
      })(),
  ].join('\r\n');
}

class TrelloImportPlan {
  final Json document;
  final List<String> warnings;
  TrelloImportPlan._(Json document, this.warnings)
    : document = _freeze(jsonDecode(jsonEncode(document))) as Json;
  int get cards => (document['cards'] as List).length;
  int get lists => (document['lists'] as List).length;
}

TrelloImportPlan previewTrello(dynamic input) {
  final j = object(input);
  if (j['name'] is! String || j['lists'] is! List || j['cards'] is! List)
    throw const FormatException('Not a supported Trello board export');
  final lists = (j['lists'] as List).map(object).toList(),
      cards = (j['cards'] as List).map(object).toList(),
      checks = (j['checklists'] as List? ?? []).map(object).toList();
  if (lists.isEmpty ||
      lists.length > 1000 ||
      cards.length > 50000 ||
      checks.length > 50000)
    throw const FormatException('Trello board exceeds import bounds');
  final ids = <String>{}, listIds = <String>{}, cardIds = <String>{};
  for (final r in [...lists, ...cards, ...checks])
    if (!ids.add(text(r['id'], max: 120, empty: false)))
      throw const FormatException('Duplicate Trello IDs');
  for (final l in lists) {
    text(l['name'], max: 1000, empty: false);
    listIds.add(l['id']);
  }
  var attachments = 0;
  for (final c in cards) {
    text(c['name'], max: 1000, empty: false);
    text(c['desc'] ?? '', max: 100000);
    if (!listIds.contains(c['idList']))
      throw const FormatException('Trello card references a missing list');
    for (final key in ['due', 'start']) if (c[key] != null) _instant(c[key]);
    attachments += (c['attachments'] as List? ?? []).length;
    cardIds.add(c['id']);
  }
  for (final check in checks) {
    if (!cardIds.contains(check['idCard']))
      throw const FormatException('Trello checklist references a missing card');
    if ((check['checkItems'] as List? ?? []).length > 10000)
      throw const FormatException('Trello checklist exceeds bounds');
    for (final raw in check['checkItems'] as List? ?? [])
      text(object(raw)['name'], max: 1000, empty: false);
  }
  return TrelloImportPlan._(
    j,
    List.unmodifiable([
      'Lists become workflow statuses; categories stay separate. Select completed lists explicitly.',
      'dueComplete is retained as imported metadata and never guesses workflow completion.',
      'Comments, members, automations, custom fields, covers and remote attachment contents are not imported.',
      if (attachments > 0)
        'Attachment URLs may be imported as links only; no downloads occur.',
    ]),
  );
}

BoardsState importTrello(
  BoardsState s,
  TrelloImportPlan plan, {
  required String title,
  Set<String> completedLists = const {},
  bool includeLinks = false,
  bool confirmed = false,
}) {
  if (!confirmed) throw const FormatException('Review Trello mapping first');
  final j = previewTrello(plan.document).document,
      lists = (j['lists'] as List).map(object).toList(),
      cards = (j['cards'] as List).map(object).toList();
  // Trello arrays need not arrive in visual order. Stable ID breaks ties.
  int byPosition(Json a, Json b) {
    final order = (a['pos'] as num? ?? 0).compareTo(b['pos'] as num? ?? 0);
    return order == 0 ? '${a['id']}'.compareTo('${b['id']}') : order;
  }

  lists.sort(byPosition);
  cards.sort(byPosition);
  if (completedLists.any((id) => !lists.any((l) => l['id'] == id)))
    throw const FormatException('Unknown completed Trello list');
  final board = newId(),
      base = createBoard(s, title, boardId: board),
      e = BoardsEdit(base),
      mapping = <String, String>{};
  for (final status
      in base.rows('statuses').where((r) => r.str('board') == board))
    e.remove('statuses', status.id);
  for (var i = 0; i < lists.length; i++) {
    final l = lists[i], id = newId();
    mapping[l['id']] = id;
    e.put(
      'statuses',
      BoardRecord({
        'id': id,
        'board': board,
        'title': l['name'],
        'done': completedLists.contains(l['id']),
        'order': i,
      }),
    );
  }
  final tags = <String, String>{};
  for (var i = 0; i < cards.length; i++) {
    final card = cards[i], id = newId();
    mapping[card['id']] = id;
    final tagIds = <String>[];
    for (final raw in card['labels'] as List? ?? []) {
      final label = object(raw), name = (label['name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      text(name, max: 100, empty: false);
      final key = label['id'] as String? ?? name;
      final tag = tags.putIfAbsent(key, () => newId());
      tagIds.add(tag);
      e.put('tags', BoardRecord({'id': tag, 'board': board, 'title': name}));
    }
    e.put(
      'tasks',
      BoardRecord({
        'id': id,
        'board': board,
        'category': null,
        'status': mapping[card['idList']],
        'title': card['name'],
        'notes': card['desc'] ?? '',
        'priority': 1,
        'order': i,
        'archived':
            card['closed'] == true ||
            lists.firstWhere((l) => l['id'] == card['idList'])['closed'] ==
                true,
        'tags': tagIds.toSet().toList(),
        'trelloDueComplete': card['dueComplete'] == true,
        for (final key in ['due', 'start'])
          if (card[key] != null)
            key: {
              'kind': 'time',
              'at': _instant(card[key]).toUtc().toIso8601String(),
              'zone': 'UTC',
            },
      }),
    );
    if (includeLinks)
      for (final raw in card['attachments'] as List? ?? []) {
        final a = object(raw), url = a['url'];
        if (url is! String) continue;
        safeUrl(url);
        e.put(
          'attachments',
          BoardRecord({
            'id': newId(),
            'task': id,
            'board': board,
            'url': url,
            'name': (a['name'] as String? ?? '').isEmpty
                ? 'Attachment link'
                : a['name'],
          }),
        );
      }
  }
  final checklistOrder = <String, int>{};
  final checklists = (j['checklists'] as List? ?? []).map(object).toList()
    ..sort(byPosition);
  for (final raw in checklists) {
    final c = object(raw);
    var order = checklistOrder[c['idCard']] ?? 0;
    final items = (c['checkItems'] as List? ?? []).map(object).toList()
      ..sort(byPosition);
    for (final raw in items) {
      final item = object(raw);
      e.put(
        'checklist',
        BoardRecord({
          'id': newId(),
          'task': mapping[c['idCard']],
          'title': item['name'],
          'done': item['state'] == 'complete',
          'order': order++,
        }),
      );
    }
    checklistOrder[c['idCard']] = order;
  }
  return e.finish();
}
