import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import 'package:timezone/timezone.dart' as tz;

Map<String, String> choices(BoardsState s, String kind, String board) => {
  for (final r in s.rows(kind).where((r) => r.str('board') == board))
    r.id: r.str('title'),
};
Future<void> editBoard(
  BuildContext context,
  BoardsScope scope, {
  String? id,
}) async {
  final old = scope.state.maybe('boards', id),
      vi = Localizations.localeOf(context).languageCode == 'vi';
  await boardForm(
    context,
    tr(
      context,
      old == null ? 'New board' : 'Edit board',
      old == null ? 'Bảng mới' : 'Sửa bảng',
    ),
    [
      const BoardField('title', 'Board name', 'Tên bảng'),
      if (scope.state.rows('workspaces').isNotEmpty)
        BoardField(
          'workspace',
          'Workspace',
          'Không gian',
          kind: 'select',
          options: {
            for (final w in scope.state.rows('workspaces'))
              w.id: w.str('title'),
          },
        ),
      if (old == null)
        BoardField(
          'template',
          'Start from',
          'Bắt đầu từ',
          kind: 'select',
          options: {
            'blank': tr(context, 'Blank board', 'Bảng trống'),
            'study': tr(context, 'Study / Semester', 'Học tập / Học kỳ'),
            'software': tr(context, 'Software project', 'Dự án phần mềm'),
            'game': tr(context, 'Indie game', 'Game độc lập'),
            'personal': tr(context, 'Personal tasks', 'Việc cá nhân'),
            'content': tr(context, 'Content production', 'Sản xuất nội dung'),
            'event': tr(context, 'Event planning', 'Tổ chức sự kiện'),
            'business': tr(
              context,
              'Business / Clients',
              'Kinh doanh / Khách hàng',
            ),
            'exam': tr(context, 'Exam preparation', 'Ôn thi'),
            'sprint': tr(context, 'Sprint', 'Sprint'),
            'household': tr(context, 'Household', 'Gia đình'),
          },
        ),
      const BoardField('zone', 'Board timezone (IANA)', 'Múi giờ bảng (IANA)'),
    ],
    {
      'title': old?.str('title') ?? '',
      'template': 'blank',
      'workspace':
          old?.data['workspace'] ??
          scope.state.rows('workspaces').firstOrNull?.id,
      'zone': old?.str('zone') ?? 'Asia/Ho_Chi_Minh',
    },
    (v) async {
      zone(v['zone']);
      await scope.controller.change((s) {
        if (old != null)
          return s.put(
            'boards',
            old.copy({
              'title': v['title'],
              'zone': v['zone'],
              'workspace': v['workspace'] ?? old.str('workspace'),
            }),
          );
        final id = newId(),
            created = createBoard(
              s,
              v['title'],
              template: v['template'],
              boardId: id,
              workspace: v['workspace'],
              vi: vi,
              now: scope.clock(),
            );
        return created.put(
          'boards',
          created.get('boards', id).copy({'zone': v['zone']}),
        );
      });
    },
    footer: [
      Text(
        tr(
          context,
          'Templates create editable categories, not tasks or accounts. All names can be changed.',
          'Mẫu tạo các nhóm có thể sửa, không tạo task hay tài khoản. Mọi tên đều đổi được.',
        ),
      ),
    ],
  );
}

Future<void> editCategory(
  BuildContext context,
  BoardsScope scope,
  String board, {
  String? id,
}) async {
  final old = scope.state.maybe('categories', id);
  await boardForm(
    context,
    tr(
      context,
      old == null ? 'New category' : 'Edit category',
      old == null ? 'Nhóm mới' : 'Sửa nhóm',
    ),
    [
      const BoardField('title', 'Category name', 'Tên nhóm'),
      const BoardField(
        'description',
        'Description',
        'Mô tả',
        kind: 'note',
        optional: true,
      ),
      BoardField(
        'color',
        'Identity color',
        'Màu nhận diện',
        kind: 'select',
        options: {for (var i = 0; i < 8; i++) '$i': '${i + 1}'},
      ),
      const BoardField(
        'preview',
        'Preview tasks (0–3)',
        'Task xem trước (0–3)',
        kind: 'number',
      ),
      const BoardField(
        'priorityWeight',
        'Priority boost (0–1000)',
        'Điểm ưu tiên nhóm (0–1000)',
        kind: 'number',
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'description': old?.str('description') ?? '',
      'color':
          '${old?.number('color') ?? scope.state.rows('categories').length % 8}',
      'preview': '${old?.number('preview', 3) ?? 3}',
      'priorityWeight': '${old?.data['priorityWeight'] ?? 0}',
    },
    (v) async {
      final preview = int.parse(v['preview']);
      final weight = double.parse(v['priorityWeight']);
      if (!weight.isFinite || weight < 0 || weight > 1000)
        throw const FormatException('Priority boost 0..1000');
      if (preview < 0 || preview > 3)
        throw const FormatException('Preview 0..3');
      await scope.controller.change(
        (s) => s.put(
          'categories',
          BoardRecord({
            ...?old?.data,
            'id': id ?? newId(),
            'board': board,
            'title': v['title'],
            'description': v['description'],
            'color': int.parse(v['color']),
            'preview': preview,
            'priorityWeight': weight,
            'order': old?.number('order') ?? s.rows('categories').length,
          }),
        ),
      );
    },
  );
}

Future<void> quickTask(
  BuildContext context,
  BoardsScope scope,
  String board, {
  String? category,
  String? parent,
}) => boardForm(
  context,
  tr(context, 'Quick task', 'Thêm việc nhanh'),
  [const BoardField('title', 'Task title', 'Tên task')],
  {'title': ''},
  (v) async {
    await scope.controller.change(
      (s) => saveTask(
        s,
        newTask(s, board, v['title'], category: category, parent: parent),
        now: scope.clock(),
      ),
    );
  },
);

Future<void> editTask(
  BuildContext context,
  BoardsScope scope,
  String id,
) async {
  final t = scope.state.get('tasks', id),
      board = t.str('board'),
      due = t.data['due'] == null ? null : object(t.data['due']),
      start = t.data['start'] == null ? null : object(t.data['start']);
  final name = scope.state.get('boards', board).str('zone');
  String clock(Json? d) => d?['kind'] == 'time'
      ? tz.TZDateTime.from(
          DateTime.parse(d!['at']),
          zone(name),
        ).toIso8601String().substring(11, 16)
      : '';
  await boardForm(
    context,
    tr(context, 'Edit task', 'Sửa task'),
    [
      const BoardField('title', 'Title', 'Tên task'),
      BoardField(
        'kind',
        'Task type',
        'Loại task',
        kind: 'select',
        options: {
          'task': tr(context, 'Task', 'Task'),
          'milestone': tr(context, 'Milestone', 'Mốc'),
          'checkpoint': tr(context, 'Checkpoint', 'Điểm kiểm tra'),
          'exam': tr(context, 'Exam (optional)', 'Kỳ thi (tùy chọn)'),
        },
      ),
      const BoardField(
        'notes',
        'Markdown notes',
        'Ghi chú Markdown',
        kind: 'note',
        optional: true,
      ),
      BoardField(
        'category',
        'Category',
        'Nhóm',
        kind: 'select',
        options: {
          '': tr(context, 'Uncategorized', 'Chưa phân nhóm'),
          ...choices(scope.state, 'categories', board),
        },
      ),
      BoardField(
        'status',
        'Status',
        'Trạng thái',
        kind: 'select',
        options: choices(scope.state, 'statuses', board),
      ),
      BoardField(
        'priority',
        'Priority',
        'Ưu tiên',
        kind: 'select',
        options: {
          '0': tr(context, 'Low', 'Thấp'),
          '1': tr(context, 'Normal', 'Thường'),
          '2': tr(context, 'High', 'Cao'),
          '3': tr(context, 'Urgent', 'Khẩn'),
        },
      ),
      const BoardField(
        'start',
        'Start date',
        'Ngày bắt đầu',
        kind: 'date',
        optional: true,
      ),
      const BoardField(
        'due',
        'Due date',
        'Hạn chót',
        kind: 'date',
        optional: true,
      ),
      const BoardField(
        'startClock',
        'Start time in board timezone (HH:mm, empty = all-day)',
        'Giờ bắt đầu theo múi giờ bảng (HH:mm, trống = cả ngày)',
        optional: true,
      ),
      const BoardField(
        'clock',
        'Due time in board timezone (HH:mm, empty = all-day)',
        'Giờ hạn theo múi giờ bảng (HH:mm, trống = cả ngày)',
        optional: true,
      ),
      BoardField(
        'fold',
        'Ambiguous time',
        'Giờ bị trùng',
        kind: 'select',
        options: {
          'ask': tr(context, 'Require explicit choice', 'Cần chọn rõ'),
          'early': tr(context, 'Earlier instance', 'Lần sớm'),
          'late': tr(context, 'Later instance', 'Lần muộn'),
        },
      ),
      const BoardField(
        'estimate',
        'Estimate (minutes; 0 = unknown)',
        'Ước lượng (phút; 0 = chưa rõ)',
        kind: 'number',
      ),
      const BoardField(
        'assignee',
        'Assignee label (local only)',
        'Nhãn người phụ trách (cục bộ)',
        optional: true,
      ),
      const BoardField(
        'pinned',
        'Pin in Today',
        'Ghim vào Hôm nay',
        kind: 'bool',
        optional: true,
      ),
    ],
    {
      'title': t.str('title'),
      'kind': t.str('kind', 'task'),
      'notes': t.str('notes'),
      'category': t.str('category'),
      'status': t.str('status'),
      'priority': '${t.number('priority')}',
      'due': due == null
          ? null
          : due['kind'] == 'time'
          ? deadlineDay(due, name)
          : due['day'],
      'start': start == null ? null : deadlineDay(start, name),
      'clock': clock(due),
      'startClock': clock(start),
      'fold': 'ask',
      'estimate': '${t.number('estimate')}',
      'assignee': t.str('assignee'),
      'pinned': t.flag('pinned'),
    },
    (v) async {
      final c = v['clock'] as String;
      Json? deadline;
      if (v['due'] != null) {
        if (c.isEmpty) {
          deadline = {'kind': 'day', 'day': v['due']};
        } else {
          if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(c))
            throw const FormatException('HH:mm required');
          deadline =
              due?['kind'] == 'time' &&
                  deadlineDay(due!, name) == v['due'] &&
                  clock(due) == c
              ? due
              : {
                  'kind': 'time',
                  'at': wallTime(
                    v['due'],
                    c,
                    name,
                    lateFold: v['fold'] == 'ask' ? null : v['fold'] == 'late',
                  ).toUtc().toIso8601String(),
                  'zone': name,
                };
        }
      } else if (c.isNotEmpty) {
        throw const FormatException('Choose due date first');
      }
      final startClock = v['startClock'] as String;
      Json? startDeadline;
      if (v['start'] != null) {
        if (startClock.isEmpty) {
          startDeadline = {'kind': 'day', 'day': v['start']};
        } else {
          if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(startClock))
            throw const FormatException('HH:mm required');
          startDeadline =
              start?['kind'] == 'time' &&
                  deadlineDay(start!, name) == v['start'] &&
                  clock(start) == startClock
              ? start
              : {
                  'kind': 'time',
                  'at': wallTime(
                    v['start'],
                    startClock,
                    name,
                    lateFold: v['fold'] == 'ask' ? null : v['fold'] == 'late',
                  ).toUtc().toIso8601String(),
                  'zone': name,
                };
        }
      } else if (startClock.isNotEmpty) {
        throw const FormatException('Choose start date first');
      }
      await scope.controller.change(
        (s) => saveTask(
          s,
          s.get('tasks', id).copy({
            'title': v['title'],
            'kind': v['kind'],
            'notes': v['notes'],
            'category': v['category'] == '' ? null : v['category'],
            'status': v['status'],
            'priority': int.parse(v['priority']),
            'start': startDeadline,
            'due': deadline,
            'estimate': int.parse(v['estimate']),
            'assignee': v['assignee'],
            'pinned': v['pinned'] == true,
          }),
          now: scope.clock(),
        ),
      );
    },
  );
}

Future<void> editStatus(
  BuildContext context,
  BoardsScope scope,
  String board, {
  String? id,
}) async {
  final old = scope.state.maybe('statuses', id);
  await boardForm(
    context,
    tr(context, 'Workflow status', 'Trạng thái quy trình'),
    [
      const BoardField('title', 'Name', 'Tên'),
      const BoardField(
        'position',
        'Column position (0-based)',
        'Vị trí cột (từ 0)',
        kind: 'number',
      ),
      BoardField(
        'color',
        'Status color identity',
        'Màu nhận diện trạng thái',
        kind: 'select',
        options: {for (var i = 0; i < 8; i++) '$i': '${i + 1}'},
      ),
      const BoardField(
        'done',
        'Counts as complete',
        'Được tính hoàn tất',
        kind: 'bool',
        optional: true,
      ),
      const BoardField(
        'wip',
        'WIP limit (0 = none)',
        'Giới hạn đang làm (0 = không giới hạn)',
        kind: 'number',
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'position':
          '${old?.number('order') ?? scope.state.rows('statuses').where((r) => r.str('board') == board).length}',
      'color': '${old?.number('color', 7) ?? 7}',
      'done': old?.flag('done') ?? false,
      'wip': '${old?.number('wip') ?? 0}',
    },
    (v) async {
      final n = int.parse(v['wip']);
      if (n < 0) throw const FormatException('Nonnegative limit required');
      await scope.controller.change((s) {
        final statusId = id ?? newId();
        final next = s.put(
          'statuses',
          BoardRecord({
            ...?old?.data,
            'id': statusId,
            'board': board,
            'title': v['title'],
            'done': v['done'] == true,
            'wip': n,
            'color': int.parse(v['color']),
            'order':
                old?.number('order') ??
                s.rows('statuses').where((r) => r.str('board') == board).length,
          }),
        );
        final ids =
            next
                .rows('statuses')
                .where((r) => r.str('board') == board && r.id != statusId)
                .toList()
              ..sort((a, b) => a.number('order').compareTo(b.number('order')));
        final position = int.parse(v['position']);
        if (position < 0 || position > ids.length)
          throw const FormatException('Position out of range');
        final order = ids.map((r) => r.id).toList()..insert(position, statusId);
        return reorder(next, 'statuses', order);
      });
    },
  );
}
