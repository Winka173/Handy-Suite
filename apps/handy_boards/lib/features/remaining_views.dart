import 'dart:convert';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import '../scope.dart';
import '../ui/labels.dart';
import 'task_detail.dart';

class StudyReports extends StatelessWidget {
  final BoardsScope scope;
  final String board;
  const StudyReports({super.key, required this.scope, required this.board});
  @override
  Widget build(BuildContext context) {
    final report = studyReport(scope.state, board, scope.clock()),
        rows = (report['subjects'] as List).map(object).toList();
    return ListView(
      children: [
        Text(
          tr(context, 'Study report', 'Báo cáo học tập'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          tr(
            context,
            'Personal calculations from your saved tasks and assessments. Unknown grades stay unknown; this is not an official transcript.',
            'Tính từ task và đầu điểm đã lưu. Điểm chưa chấm được giữ là chưa rõ; đây không phải bảng điểm chính thức.',
          ),
        ),
        TextButton.icon(
          onPressed: () => scope.run(context, () async {
            final path = await scope.files.exportBytes(
              'boards-study-report.csv',
              utf8.encode(studyReportCsv(scope.state, board, scope.clock())),
              mimeType: 'text/csv',
            );
            if (path == null && context.mounted)
              throw FormatException(
                tr(context, 'Export cancelled', 'Đã hủy xuất'),
              );
          }),
          icon: const Icon(Icons.download_outlined),
          label: Text(tr(context, 'Export report CSV', 'Xuất báo cáo CSV')),
        ),
        if (rows.isEmpty)
          Text(
            tr(
              context,
              'Enable Study metadata on a category to see its report.',
              'Thêm thông tin học tập cho nhóm để xem báo cáo.',
            ),
          ),
        for (final r in rows)
          ExpansionTile(
            initiallyExpanded: true,
            title: Text(r['title']),
            children: [
              ListTile(
                title: Text(tr(context, 'Task progress', 'Tiến độ task')),
                trailing: Text(
                  '${object(r['progress'])['done']}/${object(r['progress'])['total']}',
                ),
              ),
              ListTile(
                title: Text(tr(context, 'Overdue', 'Quá hạn')),
                trailing: Text('${object(r['progress'])['overdue']}'),
              ),
              ListTile(
                title: Text(
                  tr(context, 'Assessments graded', 'Đầu điểm đã chấm'),
                ),
                trailing: Text('${r['graded']}/${r['assessments']}'),
              ),
              ListTile(
                title: Text(
                  tr(context, 'Exams / missing dates', 'Kỳ thi / thiếu ngày'),
                ),
                trailing: Text('${r['exams']} / ${r['missingExamDates']}'),
              ),
              ListTile(
                title: Text(
                  tr(context, 'Saved focus minutes', 'Phút tập trung đã lưu'),
                ),
                trailing: Text(
                  ((r['savedFocusSeconds'] as int) / 60).toStringAsFixed(1),
                ),
              ),
              if (r['gradeWarning'] != null)
                Text(boardsError(context, FormatException(r['gradeWarning']))),
              if (r['grade'] != null) ...[
                Text(
                  '${tr(context, 'Graded average', 'Trung bình phần đã chấm')}: ${object(r['grade'])['currentPercent'] == null ? '—' : (object(r['grade'])['currentPercent'] as num).toStringAsFixed(2)} / 100',
                ),
                Text(
                  '${tr(context, 'Required remaining average', 'Trung bình cần đạt phần còn lại')}: ${object(r['grade'])['requiredPercent'] == null ? '—' : (object(r['grade'])['requiredPercent'] as num).toStringAsFixed(2)} / 100',
                ),
                Text(
                  tr(
                    context,
                    object(r['grade'])['feasible'] == true
                        ? 'Target feasible under these weights'
                        : 'Target not feasible under these weights',
                    object(r['grade'])['feasible'] == true
                        ? 'Mục tiêu khả thi theo trọng số này'
                        : 'Mục tiêu không khả thi theo trọng số này',
                  ),
                ),
              ],
              if (r['nextExam'] != null)
                TextButton(
                  onPressed: () => showTask(context, scope, r['nextExam']),
                  child: Text(
                    '${tr(context, 'Open next exam', 'Mở kỳ thi kế tiếp')}: ${scope.state.get('tasks', r['nextExam']).str('title')}',
                  ),
                ),
              for (final reason in r['reasons'] as List)
                Text(switch (reason) {
                  'overdue' => tr(
                    context,
                    'Review overdue work',
                    'Kiểm tra công việc quá hạn',
                  ),
                  'invalid weights' => tr(
                    context,
                    'Correct assessment weights',
                    'Kiểm tra trọng số đầu điểm',
                  ),
                  'target infeasible' => tr(
                    context,
                    'Review target or assessment plan',
                    'Xem lại mục tiêu hoặc kế hoạch điểm',
                  ),
                  _ => tr(
                    context,
                    'Set missing exam dates',
                    'Bổ sung ngày thi còn thiếu',
                  ),
                }),
            ],
          ),
      ],
    );
  }
}
