import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/form.dart';
import '../ui/labels.dart';
import 'exam_editor.dart';
import 'task_detail.dart';
import 'board_views.dart';

class StudyPage extends StatefulWidget {
  final BoardsScope scope;
  final String board;
  const StudyPage({super.key, required this.scope, required this.board});
  @override
  State<StudyPage> createState() => _StudyState();
}

class _StudyState extends State<StudyPage> {
  String? category;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.scope.controller,
    builder: (context, _) {
      final scope = widget.scope,
          s = scope.state,
          categories = s
              .rows('categories')
              .where((r) => r.str('board') == widget.board)
              .toList();
      if (categories.isEmpty)
        return Scaffold(
          appBar: AppBar(),
          body: Text(tr(context, 'Add a category first', 'Thêm nhóm trước')),
        );
      category ??= categories.first.id;
      final subject = s
              .rows('subjects')
              .where((r) => r.str('category') == category)
              .firstOrNull,
          grades = s
              .rows('grades')
              .where((r) => r.str('category') == category)
              .toList(),
          classes =
              s
                  .rows('classes')
                  .where((r) => r.str('category') == category)
                  .toList()
                ..sort(
                  (a, b) => a.number('weekday').compareTo(b.number('weekday')),
                );
      Json? plan;
      String? warning;
      if (grades.isNotEmpty) {
        try {
          plan = gradePlan(
            grades,
            target: (subject?.data['target'] as num? ?? 70).toDouble(),
            normalize: subject?.flag('normalize') ?? false,
          );
        } catch (e) {
          warning = boardsError(context, e);
        }
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Study planner', 'Kế hoạch học tập')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr(
                context,
                'Optional metadata for this board. Tasks remain ordinary tasks. Grades are personal calculations, not official results.',
                'Metadata tùy chọn của bảng. Task vẫn là task thông thường. Điểm là tính toán cá nhân, không phải kết quả chính thức.',
              ),
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: category,
              items: [
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.str('title'))),
              ],
              onChanged: (v) => setState(() => category = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                (subject?.str('code') ?? '').isEmpty
                    ? tr(context, 'Subject details', 'Chi tiết môn')
                    : subject!.str('code'),
              ),
              subtitle: Text(
                [
                  subject?.str('professor') ?? '',
                  subject?.str('room') ?? '',
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              trailing: IconButton(
                tooltip: tr(context, 'Edit subject', 'Sửa môn'),
                onPressed: () =>
                    scope.run(context, () => _subject(context, subject)),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            Text(
              tr(context, 'Grade planner', 'Kế hoạch điểm'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (warning != null)
              SelectableText(
                warning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (plan != null) ...[
              Text(
                '${tr(context, 'Presentation only', 'Chỉ để hiển thị')}: ${presentGrade((plan['currentPercent'] as num?)?.toDouble(), subject?.str('scale', '100') ?? '100', letters: object(subject?.data['letters'] ?? {}))}',
              ),
              Text(
                '${tr(context, 'Current graded average', 'Trung bình phần đã chấm')}: ${plan['currentPercent'] == null ? '—' : (plan['currentPercent'] as num).toStringAsFixed(2)} / 100',
              ),
              Text(
                '${tr(context, 'Remaining weight', 'Trọng số còn lại')}: ${(plan['remainingWeight'] as num).toStringAsFixed(2)}%',
              ),
              Text(
                '${tr(context, 'Required average on remaining work', 'Trung bình cần đạt phần còn lại')}: ${plan['requiredPercent'] == null ? '—' : (plan['requiredPercent'] as num).toStringAsFixed(2)} / 100',
              ),
              Text(
                tr(
                  context,
                  plan['feasible'] == true
                      ? 'Target achievable under these weights'
                      : 'Target impossible with remaining weight',
                  plan['feasible'] == true
                      ? 'Mục tiêu khả thi theo trọng số này'
                      : 'Không thể đạt mục tiêu với trọng số còn lại',
                ),
              ),
            ],
            for (final g in grades)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(g.str('title')),
                subtitle: Text(
                  '${g.data['weight']}% · ${g.data['earned'] ?? '—'}/${g.data['possible']}',
                ),
                onTap: () => scope.run(context, () => _grade(context, g)),
                trailing: IconButton(
                  tooltip: tr(context, 'Delete assessment', 'Xóa đầu điểm'),
                  icon: const Icon(Icons.close),
                  onPressed: () => scope.run(
                    context,
                    () => scope.controller.change(
                      (s) => s.remove('grades', {g.id}),
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => scope.run(context, () => _grade(context, null)),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Add assessment', 'Thêm đầu điểm')),
            ),
            const Divider(height: 32),
            Text(
              tr(context, 'Assignments & exams', 'Bài tập và kỳ thi'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Builder(
              builder: (context) {
                final tasks = topTasks(
                      s,
                      board: widget.board,
                    ).where((t) => t.str('category') == category).toList(),
                    stats = summary(s, tasks, now: scope.clock());
                return Text(
                  '${stats['done']}/${stats['total']} ${tr(context, 'complete', 'hoàn tất')} · ${stats['overdue']} ${tr(context, 'overdue', 'quá hạn')}',
                );
              },
            ),
            for (final exam in queryTasks(
              s,
              board: widget.board,
              filter: {'category': category},
              sort: 'due',
            ).where((t) => t.str('kind') == 'exam' && t.data['parent'] == null))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.event_note_outlined,
                  color: categoryHue(s.get('categories', category!)),
                ),
                title: Text(exam.str('title')),
                subtitle: Text(
                  '${exam.data['due'] == null ? '—' : deadlineLabel(context, object(exam.data['due']), s.get('boards', widget.board).str('zone'))} · ${object(exam.data['exam'] ?? {})['location'] ?? ''}',
                ),
                onTap: () => showTask(context, scope, exam.id),
                trailing: IconButton(
                  tooltip: tr(context, 'Edit exam', 'Sửa kỳ thi'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => scope.run(
                    context,
                    () => editExam(
                      context,
                      scope,
                      widget.board,
                      category!,
                      task: exam,
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => scope.run(
                context,
                () => editExam(context, scope, widget.board, category!),
              ),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Add exam', 'Thêm kỳ thi')),
            ),
            const Divider(height: 32),
            Text(
              tr(context, 'Weekly class sessions', 'Lịch học hằng tuần'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final c in classes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${weekdayName(context, c.number('weekday'))} · ${c.str('title')}',
                ),
                subtitle: Text(
                  '${_time(c.number('startMinute'))}–${_time(c.number('endMinute'))} / ${c.str('zone')}',
                ),
                onTap: () => scope.run(context, () => _class(context, c)),
                trailing: IconButton(
                  tooltip: tr(context, 'Remove session', 'Xóa buổi'),
                  icon: const Icon(Icons.close),
                  onPressed: () => scope.run(
                    context,
                    () => scope.controller.change(
                      (s) => s.remove('classes', {c.id}),
                    ),
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => scope.run(context, () => _class(context, null)),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Add class session', 'Thêm buổi học')),
            ),
          ],
        ),
      );
    },
  );
  String _time(int n) =>
      '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  Future<void> _subject(BuildContext context, BoardRecord? old) => boardForm(
    context,
    tr(context, 'Subject metadata', 'Metadata môn'),
    [
      const BoardField('code', 'Subject code', 'Mã môn', optional: true),
      const BoardField('credits', 'Credits', 'Tín chỉ', kind: 'number'),
      const BoardField(
        'professor',
        'Professor label',
        'Tên giảng viên',
        optional: true,
      ),
      const BoardField('room', 'Room', 'Phòng', optional: true),
      BoardField(
        'scale',
        'Grade presentation',
        'Cách hiển thị điểm',
        kind: 'select',
        options: {
          '4': '4',
          '10': '10',
          '100': '100',
          'letter': tr(context, 'Your letter mapping', 'Bảng chữ của bạn'),
        },
      ),
      const BoardField(
        'letters',
        'Your letter thresholds, one per line: A = 90',
        'Ngưỡng chữ của bạn, mỗi dòng: A = 90',
        kind: 'note',
        optional: true,
      ),
      const BoardField(
        'target',
        'Target percentage 0–100',
        'Mục tiêu phần trăm 0–100',
        kind: 'number',
      ),
      const BoardField(
        'normalize',
        'Normalize weights to 100 explicitly',
        'Chuẩn hóa trọng số về 100',
        kind: 'bool',
        optional: true,
      ),
    ],
    {
      'code': old?.str('code') ?? '',
      'credits': '${old?.number('credits') ?? 0}',
      'professor': old?.str('professor') ?? '',
      'room': old?.str('room') ?? '',
      'scale': old?.str('scale', '100') ?? '100',
      'letters': object(
        old?.data['letters'] ?? {},
      ).entries.map((e) => '${e.key} = ${e.value}').join('\n'),
      'target': '${old?.data['target'] ?? 70}',
      'normalize': old?.flag('normalize') ?? false,
    },
    (v) async {
      final target = double.parse(v['target']),
          credits = int.parse(v['credits']);
      if (!target.isFinite || target < 0 || target > 100 || credits < 0)
        throw const FormatException('Invalid target/credits');
      final letters = parseGradeThresholds(v['letters']);
      presentGrade(50, v['scale'], letters: letters);
      await widget.scope.controller.change(
        (s) => s.put(
          'subjects',
          BoardRecord({
            'id': old?.id ?? newId(),
            'board': widget.board,
            'category': category,
            'code': v['code'],
            'credits': credits,
            'professor': v['professor'],
            'room': v['room'],
            'scale': v['scale'],
            'letters': letters,
            'target': target,
            'normalize': v['normalize'] == true,
          }),
        ),
      );
    },
  );
  Future<void> _grade(BuildContext context, BoardRecord? old) => boardForm(
    context,
    tr(context, 'Assessment', 'Đầu điểm'),
    [
      const BoardField('title', 'Name', 'Tên'),
      const BoardField(
        'weight',
        'Weight (percent)',
        'Trọng số (%)',
        kind: 'number',
      ),
      const BoardField(
        'possible',
        'Maximum score',
        'Điểm tối đa',
        kind: 'number',
      ),
      const BoardField(
        'earned',
        'Earned (empty = ungraded)',
        'Điểm đạt (trống = chưa chấm)',
        kind: 'number',
        optional: true,
      ),
    ],
    {
      'title': old?.str('title') ?? '',
      'weight': '${old?.data['weight'] ?? 0}',
      'possible': '${old?.data['possible'] ?? 10}',
      'earned': old?.data['earned']?.toString() ?? '',
    },
    (v) async {
      await widget.scope.controller.change(
        (s) => s.put(
          'grades',
          BoardRecord({
            'id': old?.id ?? newId(),
            'board': widget.board,
            'category': category,
            'title': v['title'],
            'weight': double.parse(v['weight']),
            'possible': double.parse(v['possible']),
            'earned': v['earned'] == '' ? null : double.parse(v['earned']),
          }),
        ),
      );
    },
  );
  Future<void> _class(BuildContext context, BoardRecord? old) => boardForm(
    context,
    tr(context, 'Class session', 'Buổi học'),
    [
      const BoardField('title', 'Label', 'Nhãn'),
      BoardField(
        'weekday',
        'Weekday (1 Monday – 7 Sunday)',
        'Thứ (1 Thứ hai – 7 Chủ nhật)',
        kind: 'select',
        options: {for (var i = 1; i <= 7; i++) '$i': '$i'},
      ),
      const BoardField('start', 'Start HH:mm', 'Bắt đầu HH:mm'),
      const BoardField('end', 'End HH:mm', 'Kết thúc HH:mm'),
    ],
    {
      'title': old?.str('title') ?? '',
      'weekday': '${old?.number('weekday', 1) ?? 1}',
      'start': _time(old?.number('startMinute', 480) ?? 480),
      'end': _time(old?.number('endMinute', 540) ?? 540),
    },
    (v) async {
      int minute(String x) {
        if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(x))
          throw const FormatException('HH:mm required');
        final p = x.split(':').map(int.parse).toList();
        return p[0] * 60 + p[1];
      }

      await widget.scope.controller.change(
        (s) => s.put(
          'classes',
          BoardRecord({
            'id': old?.id ?? newId(),
            'board': widget.board,
            'category': category,
            'title': v['title'],
            'weekday': int.parse(v['weekday']),
            'startMinute': minute(v['start']),
            'endMinute': minute(v['end']),
            'zone': s.get('boards', widget.board).str('zone'),
          }),
        ),
      );
    },
  );
}
