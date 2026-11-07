part of '../handy_boards_engine.dart';

class BoardsEdit {
  final BoardsState before;
  late final Map<String, Map<String, BoardRecord>> data = {
    for (final k in kinds) k: _OverlayMap(before.records[k]!),
  };
  late final Map<String, Uint8List> files = _OverlayMap(before._files);
  BoardsEdit(this.before);

  /// Removing a lazy browser file must not synchronously read its old body.
  void removeFile(String path) =>
      (files as _OverlayMap<Uint8List>).discard(path);
  void put(String kind, BoardRecord r) => data[kind]![r.id] = r;
  void remove(String kind, String id) => data[kind]!.remove(id);
  void event(
    String task,
    String action,
    DateTime now, {
    Json details = const {},
  }) => put(
    'events',
    BoardRecord({
      'id': newId(),
      'task': task,
      'action': action,
      'at': now.toUtc().toIso8601String(),
      'details': details,
    }),
  );
  BoardsState finish() {
    final s = BoardsState._(
      before.revision,
      Map.unmodifiable({
        for (final k in kinds)
          k: (data[k]! as _OverlayMap<BoardRecord>).freeze(),
      }),
      before.preferences,
      (files as _OverlayMap<Uint8List>).freeze(),
    );
    s.validate();
    return s;
  }
}

Set<String> taskDescendants(BoardsState s, Set<String> roots) {
  final children = <String, List<String>>{};
  for (final t in s.rows('tasks'))
    if (t.data['parent'] != null) (children[t.str('parent')] ??= []).add(t.id);
  final result = {...roots}, queue = roots.toList();
  for (var i = 0; i < queue.length; i++)
    for (final id in children[queue[i]] ?? const <String>[])
      if (result.add(id)) queue.add(id);
  return result;
}

const templateCategories = <String, List<String>>{
  'blank': [],
  'study': ['Mathematics', 'Java', 'English', 'Physics'],
  'software': ['Design', 'Frontend', 'Backend', 'QA', 'Release'],
  'game': ['Game Design', 'Programming', 'Art', 'Audio', 'QA', 'Publishing'],
  'personal': ['Home', 'Health', 'Money', 'Errands'],
  'content': ['Ideas', 'Research', 'Creation', 'Review', 'Publish'],
  'event': ['Venue', 'Guests', 'Supplies', 'Program'],
  'business': ['Client A', 'Client B', 'Operations', 'Follow-up'],
  'exam': ['Review', 'Practice', 'Mock exams', 'Materials'],
  'sprint': ['Planning', 'Build', 'Review', 'Release'],
  'household': ['Household', 'Work', 'Personal', 'Fitness'],
};
const _viCategories = <String, List<String>>{
  'study': ['Toán học', 'Java', 'Tiếng Anh', 'Vật lý'],
  'software': ['Thiết kế', 'Frontend', 'Backend', 'Kiểm thử', 'Phát hành'],
  'game': [
    'Thiết kế game',
    'Lập trình',
    'Mỹ thuật',
    'Âm thanh',
    'Kiểm thử',
    'Phát hành',
  ],
  'personal': ['Nhà cửa', 'Sức khỏe', 'Tiền bạc', 'Việc vặt'],
  'content': ['Ý tưởng', 'Nghiên cứu', 'Sáng tạo', 'Duyệt', 'Đăng'],
  'event': ['Địa điểm', 'Khách mời', 'Vật dụng', 'Chương trình'],
  'business': ['Khách hàng A', 'Khách hàng B', 'Vận hành', 'Theo dõi'],
  'exam': ['Ôn tập', 'Luyện tập', 'Thi thử', 'Tài liệu'],
  'sprint': ['Lập kế hoạch', 'Xây dựng', 'Duyệt', 'Phát hành'],
  'household': ['Nhà cửa', 'Công việc', 'Cá nhân', 'Thể chất'],
};
BoardsState createBoard(
  BoardsState s,
  String title, {
  String template = 'blank',
  String? workspace,
  String? boardId,
  bool vi = false,
  DateTime? now,
}) {
  text(title, empty: false);
  if (!templateCategories.containsKey(template))
    throw const FormatException('Unknown template');
  final e = BoardsEdit(s),
      w = workspace ?? s.rows('workspaces').firstOrNull?.id ?? newId(),
      b = boardId ?? newId(),
      at = (now ?? DateTime.now()).toUtc().toIso8601String();
  if (s.maybe('workspaces', w) == null)
    e.put(
      'workspaces',
      BoardRecord({
        'id': w,
        'title': vi ? 'Cá nhân' : 'Personal',
        'created': at,
      }),
    );
  if (s.maybe('boards', b) != null) throw const FormatException('Board exists');
  e.put(
    'boards',
    BoardRecord({
      'id': b,
      'workspace': w,
      'title': title,
      'zone': 'Asia/Ho_Chi_Minh',
      'created': at,
      'updated': at,
      'module': ['study', 'exam'].contains(template) ? 'study' : 'general',
    }),
  );
  final names = vi
      ? ['Chờ', 'Cần làm', 'Đang làm', 'Duyệt', 'Hoàn tất']
      : ['Backlog', 'To Do', 'Doing', 'Review', 'Done'];
  for (var i = 0; i < names.length; i++)
    e.put(
      'statuses',
      BoardRecord({
        'id': newId(),
        'board': b,
        'title': names[i],
        'order': i,
        'done': i == 4,
      }),
    );
  final groups = vi
      ? (_viCategories[template] ?? templateCategories[template]!)
      : templateCategories[template]!;
  for (var i = 0; i < groups.length; i++) {
    final id = newId();
    e.put(
      'categories',
      BoardRecord({
        'id': id,
        'board': b,
        'title': groups[i],
        'order': i,
        'color': i % 8,
        'icon': 'folder',
        'preview': 3,
      }),
    );
    if (['study', 'exam'].contains(template))
      e.put(
        'subjects',
        BoardRecord({
          'id': newId(),
          'board': b,
          'category': id,
          'code': '',
          'credits': 0,
          'professor': '',
          'room': '',
        }),
      );
  }
  return e.finish();
}

BoardsState saveTask(
  BoardsState s,
  BoardRecord task, {
  DateTime? now,
  bool log = true,
}) {
  final e = BoardsEdit(s),
      old = s.maybe('tasks', task.id),
      at = now ?? DateTime.now();
  if (old != null && old.str('board') != task.str('board'))
    throw const FormatException('Use explicit move across boards');
  final done = s.get('statuses', task.str('status')).flag('done'),
      statusChanged = old != null && old.str('status') != task.str('status');
  e.put(
    'tasks',
    task.copy({
      'created': old?.data['created'] ?? at.toUtc().toIso8601String(),
      'updated': at.toUtc().toIso8601String(),
      if (statusChanged || old == null)
        'completedAt': done ? at.toUtc().toIso8601String() : null,
    }),
  );
  if (log)
    e.event(
      task.id,
      old == null
          ? 'created'
          : statusChanged
          ? done
                ? 'completed'
                : 'status changed'
          : old.flag('archived') != task.flag('archived')
          ? task.flag('archived')
                ? 'archived'
                : 'unarchived'
          : 'edited',
      at,
    );
  if (statusChanged)
    for (final occurrence
        in s.rows('occurrences').where((r) => r.str('task') == task.id))
      e.put(
        'occurrences',
        occurrence.copy({'state': done ? 'completed' : 'pending'}),
      );
  return e.finish();
}

BoardRecord newTask(
  BoardsState s,
  String board,
  String title, {
  String? category,
  String? parent,
}) => BoardRecord({
  'id': newId(),
  'board': board,
  'title': title,
  'notes': '',
  'category': category,
  'parent': parent,
  'status': s
      .rows('statuses')
      .firstWhere(
        (v) =>
            v.str('board') == board &&
            !v.flag('done') &&
            v.number('order') == 1,
        orElse: () =>
            s.rows('statuses').firstWhere((v) => v.str('board') == board),
      )
      .id,
  'priority': 1,
  'order': s.rows('tasks').where((t) => t.str('board') == board).length,
  'tags': <String>[],
  'custom': {
    for (final f
        in s
            .rows('fields')
            .where((f) => f.str('board') == board && f.data['default'] != null))
      f.id: f.data['default'],
  },
});
bool completed(BoardsState s, BoardRecord t) =>
    s.get('statuses', t.str('status')).flag('done');
bool activeTask(BoardRecord t) => !t.flag('archived') && !t.flag('trashed');
Iterable<BoardRecord> topTasks(BoardsState s, {String? board}) => s
    .rows('tasks')
    .where(
      (t) =>
          activeTask(t) &&
          t.data['parent'] == null &&
          (board == null || t.str('board') == board),
    );

BoardsState changeStatus(
  BoardsState s,
  String task,
  String status, {
  DateTime? now,
}) {
  final t = s.get('tasks', task),
      st = s.get('statuses', status),
      e = BoardsEdit(s),
      at = now ?? DateTime.now();
  if (st.str('board') != t.str('board'))
    throw const FormatException('Status outside board');
  if (status == t.str('status')) return s;
  e.put(
    'tasks',
    t.copy({
      'status': status,
      'suggestedStatus': null,
      'completedAt': st.flag('done') ? at.toUtc().toIso8601String() : null,
      'updated': at.toUtc().toIso8601String(),
    }),
  );
  e.event(
    task,
    st.flag('done') ? 'completed' : 'status changed',
    at,
    details: {'from': t.str('status'), 'to': status},
  );
  for (final occurrence
      in s.rows('occurrences').where((r) => r.str('task') == task))
    e.put(
      'occurrences',
      occurrence.copy({'state': st.flag('done') ? 'completed' : 'pending'}),
    );
  return e.finish();
}

BoardsState reorder(BoardsState s, String kind, List<String> ids) {
  if (!['categories', 'statuses', 'tasks', 'checklist'].contains(kind) ||
      ids.toSet().length != ids.length)
    throw const FormatException('Invalid reorder');
  final rows = ids.map((id) => s.get(kind, id)).toList();
  if (rows
          .map((r) => r.str(kind == 'checklist' ? 'task' : 'board'))
          .toSet()
          .length >
      1)
    throw const FormatException('Reorder scope mismatch');
  final e = BoardsEdit(s);
  for (var i = 0; i < rows.length; i++) e.put(kind, rows[i].copy({'order': i}));
  return e.finish();
}

BoardsState deleteCategory(BoardsState s, String id, {String? moveTo}) {
  final c = s.get('categories', id);
  if (moveTo == id) throw const FormatException('Choose another category');
  if (moveTo != null &&
      s.get('categories', moveTo).str('board') != c.str('board'))
    throw const FormatException('Category board mismatch');
  final e = BoardsEdit(s);
  for (final t in s.rows('tasks').where((t) => t.str('category') == id))
    e.put('tasks', t.copy({'category': moveTo}));
  for (final k in ['subjects', 'classes', 'grades'])
    for (final r in s.rows(k).where((r) => r.str('category') == id))
      e.remove(k, r.id);
  e.remove('categories', id);
  for (final v in s.rows('views')) {
    final conditions = (v.data['conditions'] as List? ?? []).map((raw) {
      final condition = object(raw);
      return condition['category'] == id
          ? {...condition, 'category': moveTo}
          : condition;
    }).toList();
    e.put('views', v.copy({'conditions': conditions}));
  }
  for (final r in s.rows('rules')) {
    final actions = (r.data['actions'] as List).where((raw) {
      final a = object(raw);
      return !(a['type'] == 'category' && a['value'] == id);
    }).toList();
    e.put(
      'rules',
      r.copy({
        'actions': actions,
        'enabled': actions.isNotEmpty && r.flag('enabled'),
      }),
    );
  }
  return e.finish();
}

BoardsState trashTasks(
  BoardsState s,
  Set<String> ids, {
  bool restore = false,
  DateTime? now,
}) {
  final e = BoardsEdit(s), at = now ?? DateTime.now(), all = {...ids};
  all.addAll(taskDescendants(s, all));
  final batch = newId(),
      restoringBatches = {
        for (final id in ids) s.get('tasks', id).data['trashBatch'],
      };
  for (final id in all) {
    final t = s.get('tasks', id);
    if (!restore && t.flag('trashed')) continue;
    if (restore &&
        !ids.contains(id) &&
        !restoringBatches.contains(t.data['trashBatch']))
      continue;
    e.put(
      'tasks',
      t.copy({
        'trashed': !restore,
        'trashedAt': restore ? null : at.toUtc().toIso8601String(),
        'trashBatch': restore ? null : batch,
      }),
    );
    e.event(id, restore ? 'restored' : 'trashed', at);
  }
  return e.finish();
}

BoardsState permanentlyDelete(
  BoardsState s,
  Set<String> ids, {
  required bool confirmed,
}) {
  if (!confirmed)
    throw const FormatException('Permanent deletion requires confirmation');
  for (final id in ids)
    if (!s.get('tasks', id).flag('trashed'))
      throw const FormatException('Move to trash first');
  final e = BoardsEdit(s), all = {...ids};
  all.addAll(taskDescendants(s, all));
  for (final k in kinds)
    for (final r in s.rows(k))
      if (k == 'tasks'
          ? all.contains(r.id)
          : all.contains(r.str('task')) ||
                k == 'dependencies' &&
                    (all.contains(r.str('before')) ||
                        all.contains(r.str('after'))))
        e.remove(k, r.id);
  for (final r in s.rows('occurrences'))
    if (!e.data['tasks']!.containsKey(r.str('task')) ||
        !e.data['recurrence']!.containsKey(r.str('rule')))
      e.remove('occurrences', r.id);
  final retained = e.data['attachments']!.values
      .expand((r) => [r.str('path'), r.str('preview')])
      .toSet();
  for (final path in e.files.keys.toList())
    if (!retained.contains(path)) e.removeFile(path);
  return e.finish();
}

BoardsState toggleChecklist(
  BoardsState s,
  String id,
  bool done, {
  DateTime? now,
}) {
  final r = s.get('checklist', id);
  return s.put(
    'checklist',
    r.copy({
      'done': done,
      'completedAt': done
          ? (now ?? DateTime.now()).toUtc().toIso8601String()
          : null,
    }),
  );
}

bool blocked(BoardsState s, BoardRecord task) =>
    s.related('dependencies', task.id, field: 'after').any((d) {
      final p = s.get('tasks', d.str('before'));
      return !completed(s, p) || p.flag('trashed');
    });

void validateTaskFilter(Json filter) {
  const supported = {
    'category',
    'status',
    'priority',
    'assignee',
    'blocked',
    'tag',
    'dueFrom',
    'dueTo',
    'estimateMin',
    'estimateMax',
    'hasReminder',
    'archived',
    'parentOnly',
  };
  for (final e in filter.entries) {
    if (!supported.contains(e.key))
      throw const FormatException('Unsupported task filter');
    switch (e.key) {
      case 'priority':
        if (e.value is! int || e.value < 0 || e.value > 3)
          throw const FormatException('Priority 0..3');
      case 'estimateMin' || 'estimateMax':
        if (e.value is! int || e.value < 0 || e.value > 525600)
          throw const FormatException('Estimate 0..525600');
      case 'dueFrom' || 'dueTo':
        day(e.value as String);
      case 'blocked' || 'hasReminder' || 'archived' || 'parentOnly':
        if (e.value is! bool)
          throw const FormatException('Boolean condition required');
      case 'category':
        if (e.value != null) text(e.value, max: 120, empty: false);
      case 'status' || 'tag':
        text(e.value, max: 120, empty: false);
      case 'assignee':
        text(e.value, max: 1000, empty: false);
    }
  }
  if (filter['estimateMin'] != null &&
      filter['estimateMax'] != null &&
      filter['estimateMin'] > filter['estimateMax'])
    throw const FormatException('Reversed estimate range');
  if (filter['dueFrom'] != null &&
      filter['dueTo'] != null &&
      (filter['dueFrom'] as String).compareTo(filter['dueTo']) > 0)
    throw const FormatException('Reversed date range');
}

bool taskMatches(
  BoardsState s,
  BoardRecord t, {
  String? board,
  String search = '',
  Json filter = const {},
  bool includeTrash = false,
}) {
  final needle = foldSearch(search);
  if (board != null && t.str('board') != board) return false;
  if (!includeTrash && t.flag('trashed')) return false;
  if (filter['archived'] is bool) {
    if (t.flag('archived') != filter['archived']) return false;
  } else if (!includeTrash && t.flag('archived'))
    return false;
  if (filter['estimateMin'] != null &&
      t.number('estimate') < filter['estimateMin'])
    return false;
  if (filter['estimateMax'] != null &&
      t.number('estimate') > filter['estimateMax'])
    return false;
  if (filter['hasReminder'] is bool &&
      s.related('reminders', t.id).any((r) => r.flag('enabled')) !=
          filter['hasReminder'])
    return false;
  if (filter['parentOnly'] == true && t.data['parent'] != null) return false;
  for (final f in ['category', 'status', 'priority', 'assignee'])
    if (filter.containsKey(f) && t.data[f] != filter[f]) return false;
  if (filter['blocked'] is bool && blocked(s, t) != filter['blocked'])
    return false;
  if (filter['tag'] != null && !t.strings('tags').contains(filter['tag']))
    return false;
  if (filter['dueFrom'] != null &&
      (t.data['due'] == null ||
          deadlineDay(
                object(t.data['due']),
                s.get('boards', t.str('board')).str('zone'),
              ).compareTo(filter['dueFrom']) <
              0))
    return false;
  if (filter['dueTo'] != null &&
      (t.data['due'] == null ||
          deadlineDay(
                object(t.data['due']),
                s.get('boards', t.str('board')).str('zone'),
              ).compareTo(filter['dueTo']) >
              0))
    return false;
  if (needle.isNotEmpty) {
    final category =
            s.maybe('categories', t.data['category'])?.str('title') ?? '',
        tags = t
            .strings('tags')
            .map((id) => s.get('tags', id).str('title'))
            .join(' ');
    if (!foldSearch(
      '${t.str('title')} ${t.str('notes')} $category $tags ${t.data['custom'] ?? {}} ${s.related('attachments', t.id).map((a) => '${a.str('url')} ${a.str('name')}').join(' ')}',
    ).contains(needle))
      return false;
  }
  return true;
}

int compareTasks(BoardRecord a, BoardRecord b, String sort) {
  final int c = switch (sort) {
    'title' => foldSearch(a.str('title')).compareTo(foldSearch(b.str('title'))),
    'priority' => b.number('priority').compareTo(a.number('priority')),
    'due' =>
      (a.data['due'] == null ? '9999' : deadlineSort(object(a.data['due'])))
          .compareTo(
            b.data['due'] == null
                ? '9999'
                : deadlineSort(object(b.data['due'])),
          ),
    'created' || 'updated' => a.str(sort).compareTo(b.str(sort)),
    _ => a.number('order').compareTo(b.number('order')),
  };
  return c == 0 ? a.id.compareTo(b.id) : c;
}

List<BoardRecord> queryTasks(
  BoardsState s, {
  String? board,
  String search = '',
  Json filter = const {},
  String sort = 'manual',
  bool includeTrash = false,
}) {
  validateTaskFilter(filter);
  final rows = s
      .rows('tasks')
      .where(
        (t) => taskMatches(
          s,
          t,
          board: board,
          search: search,
          filter: filter,
          includeTrash: includeTrash,
        ),
      )
      .toList();
  rows.sort((a, b) => compareTasks(a, b, sort));
  return rows;
}
