import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:timezone/timezone.dart' as tz;
import '../scope.dart';
import '../ui/form.dart';

Future<void> editExam(
  BuildContext context,
  BoardsScope scope,
  String board,
  String category, {
  BoardRecord? task,
}) async {
  final details = object(task?.data['exam'] ?? {}),
      name = scope.state.get('boards', board).str('zone');
  final due = task?.data['due'] == null ? null : object(task!.data['due']);
  String clock(Json? d) => d?['kind'] == 'time'
      ? tz.TZDateTime.from(
          DateTime.parse(d!['at']),
          zone(name),
        ).toIso8601String().substring(11, 16)
      : '';
  await boardForm(
    context,
    tr(
      context,
      task == null ? 'Add exam' : 'Edit exam',
      task == null ? 'Thêm kỳ thi' : 'Sửa kỳ thi',
    ),
    [
      const BoardField('title', 'Exam name', 'Tên kỳ thi'),
      const BoardField('day', 'Exam date', 'Ngày thi', kind: 'date'),
      const BoardField(
        'clock',
        'Start time in board timezone (HH:mm; empty = all-day)',
        'Giờ thi theo múi giờ bảng (HH:mm; trống = cả ngày)',
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
        'duration',
        'Duration in minutes (empty = unknown)',
        'Thời lượng phút (trống = chưa rõ)',
        kind: 'number',
        optional: true,
      ),
      const BoardField(
        'location',
        'Room / location',
        'Phòng / địa điểm',
        optional: true,
      ),
      const BoardField(
        'materials',
        'Permitted materials / preparation',
        'Tài liệu được phép / chuẩn bị',
        kind: 'note',
        optional: true,
      ),
    ],
    {
      'title': task?.str('title') ?? '',
      'day': due == null ? null : deadlineDay(due, name),
      'clock': clock(due),
      'fold': 'ask',
      'duration': details['durationMinutes']?.toString() ?? '',
      'location': details['location'] ?? '',
      'materials': details['materials'] ?? '',
    },
    (v) async {
      final String time = v['clock'];
      final Json deadline = time.isEmpty
          ? {'kind': 'day', 'day': v['day']}
          : due?['kind'] == 'time' &&
                deadlineDay(due!, name) == v['day'] &&
                clock(due) == time
          ? due
          : {
              'kind': 'time',
              'at': wallTime(
                v['day'],
                time,
                name,
                lateFold: v['fold'] == 'ask' ? null : v['fold'] == 'late',
              ).toUtc().toIso8601String(),
              'zone': name,
            };
      await scope.controller.change((s) {
        final record = task == null
            ? newTask(s, board, v['title'], category: category)
            : s.get('tasks', task.id);
        return saveTask(
          s,
          record.copy({
            'title': v['title'],
            'kind': 'exam',
            'due': deadline,
            'exam': {
              'durationMinutes': v['duration'] == ''
                  ? null
                  : int.parse(v['duration']),
              'location': v['location'],
              'materials': v['materials'],
            },
          }),
          now: scope.clock(),
        );
      });
    },
    footer: [
      Text(
        tr(
          context,
          'This is the same task shown in Categories, Kanban and Calendar. The due timestamp marks the exam start; duration is separate from the work estimate. Add reminders and files from task detail.',
          'Đây là cùng task trong Nhóm, Kanban và Lịch. Mốc hạn là giờ bắt đầu thi; thời lượng thi tách biệt ước lượng công việc. Thêm nhắc và tệp ở chi tiết task.',
        ),
      ),
    ],
  );
}
