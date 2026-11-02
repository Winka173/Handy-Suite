import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:pdf/widgets.dart' as pw;
import '../scope.dart';
import '../ui/form.dart';
import 'advanced.dart';
import '../platform/export_job.dart';
import '../platform/import_job.dart';
import '../ui/job_dialog.dart';

Future<Uint8List> boardPdf(
  BoardsState s,
  String board, {
  BoardsJob? job,
  bool vi = false,
}) async {
  job?.check();
  final tasks = queryTasks(s, board: board);
  if (tasks.length > 1000)
    throw const FormatException('PDF limited to 1000 selected tasks');
  final font = pw.Font.ttf(
        await rootBundle.load(
          'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
        ),
      ),
      doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font),
      maxPages: 200,
      build: (_) => [
        pw.Header(text: s.get('boards', board).str('title')),
        pw.Text('Handy Boards — ${tasks.length} ${vi ? 'công việc' : 'tasks'}'),
        for (final t in tasks)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t.str('title')),
                pw.Text(
                  '${s.maybe('categories', t.data['category'])?.str('title') ?? '—'} / ${s.get('statuses', t.str('status')).str('title')}',
                ),
                if (t.data['due'] != null)
                  pw.Text(deadlineSort(object(t.data['due']))),
              ],
            ),
          ),
      ],
    ),
  );
  job?.check();
  final output = await doc.save(enableEventLoopBalancing: true);
  job?.check();
  job?.progress(1);
  return output;
}

Future<Uint8List> studyPlannerPdf(
  BoardsState s,
  String board, {
  BoardsJob? job,
  bool vi = false,
}) async {
  job?.check();
  final selectedTasks = queryTasks(s, board: board);
  if (selectedTasks.length > 1000 ||
      s.rows('categories').where((r) => r.str('board') == board).length > 100)
    throw const FormatException(
      'Study PDF limited to 1000 tasks and 100 categories; narrow the board before exporting',
    );
  final font = pw.Font.ttf(
        await rootBundle.load(
          'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
        ),
      ),
      doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: font),
      maxPages: 100,
      build: (_) => [
        pw.Header(text: s.get('boards', board).str('title')),
        pw.Text(
          vi
              ? 'Kế hoạch học tập cá nhân / không phải hồ sơ điểm chính thức'
              : 'Personal study planner / not official academic records',
        ),
        for (final c
            in s.rows('categories').where((r) => r.str('board') == board)) ...[
          pw.Header(level: 1, text: c.str('title')),
          for (final session
              in s.rows('classes').where((r) => r.str('category') == c.id))
            pw.Text(
              '${session.str('title')} / weekday ${session.number('weekday')} / ${session.number('startMinute')}–${session.number('endMinute')} minutes after midnight / ${session.str('zone')}',
            ),
          for (final t in selectedTasks.where((r) => r.str('category') == c.id))
            pw.Text(
              '${t.str('title')} / ${t.data['due'] == null ? '—' : deadlineSort(object(t.data['due']))}',
            ),
        ],
      ],
    ),
  );
  job?.check();
  final output = await doc.save(enableEventLoopBalancing: true);
  job?.check();
  job?.progress(1);
  return output;
}

Future<void> exportBoards(
  BuildContext context,
  BoardsScope scope,
  String? board,
) async {
  final options = {
    'zip': 'ZIP ${tr(context, 'full backup', 'sao lưu đầy đủ')}',
    'json': 'JSON ${tr(context, 'full backup', 'sao lưu đầy đủ')}',
    if (board != null) ...{
      'csv': 'CSV',
      'md': 'Markdown',
      'pdf': 'PDF',
      'ics': 'ICS',
      if (boardsPro(context)) 'xlsx': 'XLSX',
      if (boardsPro(context))
        if (boardsPro(context))
          'study-pdf': tr(
            context,
            'Printable study planner PDF',
            'PDF kế hoạch học tập để in',
          ),
      if (boardsPro(context))
        'template': tr(context, 'Board template JSON', 'JSON mẫu bảng'),
      if (boardsPro(context))
        'template-zip': tr(
          context,
          'Board template ZIP package',
          'Gói mẫu bảng ZIP',
        ),
    },
  };
  await boardForm(
    context,
    tr(context, 'Export a copy', 'Xuất bản sao'),
    [
      BoardField(
        'format',
        'Format',
        'Định dạng',
        kind: 'select',
        options: options,
      ),
      const BoardField(
        'review',
        'I reviewed private task notes and attachment contents',
        'Tôi đã kiểm tra ghi chú riêng và nội dung tệp',
        kind: 'bool',
        optional: true,
      ),
      if (board != null && boardsPro(context))
        BoardField(
          'recurrence',
          'Template only: include recurring definitions and dates',
          'Chỉ với mẫu: kèm định nghĩa lặp và ngày',
          kind: 'bool',
          optional: true,
          visibleWhen: (values) =>
              ['template', 'template-zip'].contains(values['format']),
        ),
    ],
    {'format': 'zip', 'review': false, 'recurrence': false},
    (v) async {
      if (v['review'] != true)
        throw FormatException(
          tr(
            context,
            'Review private data before export',
            'Cần kiểm tra dữ liệu riêng trước khi xuất',
          ),
        );
      final String f = v['format'];
      final vi = Localizations.localeOf(context).languageCode == 'vi';
      final s = scope.state;
      if (['zip', 'pdf'].contains(f)) {
        final font = f == 'pdf'
            ? (await rootBundle.load(
                'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
              )).buffer.asUint8List()
            : null;
        final request = BoardsExportRequest(
          s,
          scope.controller.store!,
          f,
          board: board,
          font: font,
          vi: vi,
        );
        if (supportsStreamingExport(request)) {
          if (!context.mounted) return;
          final saved = await runBoardsJob(
            context,
            (job) => saveStreamingExport(request, job),
          );
          if (saved == null) throw const BoardsJobCancelled();
          return;
        }
      }
      if (!context.mounted) return;
      final Uint8List bytes;
      if (['zip', 'json', 'pdf', 'study-pdf'].contains(f)) {
        bytes = await runBoardsJob(context, (job) async {
          final result = switch (f) {
            'zip' || 'json' => await exportBackupAsync(
              s,
              zip: f == 'zip',
              check: job.check,
              progress: job.progress,
            ),
            'pdf' => await boardPdf(s, board!, job: job, vi: vi),
            _ => await studyPlannerPdf(s, board!, job: job, vi: vi),
          };
          job.check();
          return result;
        });
      } else {
        bytes = switch (f) {
          'csv' => Uint8List.fromList(utf8.encode(exportTaskCsv(s, board!))),
          'md' => Uint8List.fromList(utf8.encode(exportMarkdown(s, board!))),
          'ics' => Uint8List.fromList(utf8.encode(exportIcs(s, board!))),
          'xlsx' => exportXlsx(s, board!),
          'template-zip' => exportTemplatePackage(
            s,
            board!,
            includeRecurrence: v['recurrence'] == true,
          ),
          'template' => Uint8List.fromList(
            utf8.encode(
              jsonEncode(
                exportBoardTemplate(
                  s,
                  board!,
                  includeRecurrence: v['recurrence'] == true,
                ),
              ),
            ),
          ),
          _ => throw const FormatException('Unknown format'),
        };
      }
      final path = await scope.files.exportBytes(
        'handy-boards.${f == 'template-zip'
            ? 'template.zip'
            : f == 'template'
            ? 'template.json'
            : f.endsWith('-pdf')
            ? '$f.pdf'
            : f}',
        bytes,
        mimeType: switch (f) {
          'zip' => 'application/zip',
          'json' => 'application/json',
          'pdf' => 'application/pdf',
          'csv' => 'text/csv',
          'ics' => 'text/calendar',
          'xlsx' =>
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'template' => 'application/json',
          'study-pdf' => 'application/pdf',
          _ => 'text/markdown',
        },
      );
      if (!context.mounted) return;
      if (path == null)
        throw FormatException(
          tr(
            context,
            'Export cancelled; your data is unchanged',
            'Đã hủy xuất; dữ liệu không đổi',
          ),
        );
    },
    footer: [
      Text(
        tr(
          context,
          'Backups include private notes and original attachments. They are not encrypted. CSV/Markdown/PDF/ICS are task summaries, not full backups.',
          'Sao lưu chứa ghi chú riêng và tệp gốc, chưa mã hóa. CSV/Markdown/PDF/ICS là tóm tắt task, không phải sao lưu đầy đủ.',
        ),
      ),
    ],
    saveLabel: tr(context, 'Export', 'Xuất'),
  );
}

Future<void> importBoards(
  BuildContext context,
  BoardsScope scope,
  String? board,
) async {
  final prepared = supportsStagedImport(scope.controller.store, scope.files)
      ? await runBoardsJob(context, prepareBoardsImport)
      : null;
  if (supportsStagedImport(scope.controller.store, scope.files) &&
      prepared == null)
    return;
  try {
    final file =
        prepared?.file ??
        (prepared?.snapshot == null
            ? await scope.files.importBytes(
                extensions: ['zip', 'json', 'csv', 'md', 'txt'],
              )
            : null);
    if ((file == null && prepared?.snapshot == null) || !context.mounted)
      return;
    final ext = file?.name.split('.').last.toLowerCase() ?? 'zip';
    if (ext == 'json' || ext == 'zip') {
      {
        final parsed = prepared?.snapshot != null
            ? null
            : ext == 'json'
            ? object(jsonDecode(utf8.decode(file!.bytes)))
            : readTemplatePackage(file!.bytes);
        if (parsed != null &&
            parsed.containsKey('cards') &&
            parsed.containsKey('lists')) {
          final plan = previewTrello(parsed), revision = scope.state.revision;
          await boardForm(
            context,
            tr(context, 'Review Trello import', 'Kiểm tra nhập Trello'),
            [
              const BoardField('title', 'New board name', 'Tên bảng mới'),
              BoardField(
                'done',
                'Lists that mean completed',
                'Danh sách được tính hoàn tất',
                kind: 'multi',
                optional: true,
                options: {
                  for (final raw in parsed['lists'] as List)
                    object(raw)['id']: object(raw)['name'],
                },
              ),
              const BoardField(
                'links',
                'Import attachment links (no downloads)',
                'Nhập liên kết đính kèm (không tải tệp)',
                kind: 'bool',
                optional: true,
              ),
              const BoardField(
                'confirm',
                'I reviewed this mapping',
                'Tôi đã kiểm tra cách chuyển đổi',
                kind: 'bool',
                optional: true,
              ),
            ],
            {
              'title': parsed['name'],
              'done': <String>[],
              'links': false,
              'confirm': false,
            },
            (v) async {
              await scope.controller.change((s) {
                if (s.revision != revision)
                  throw const FormatException('Data changed during preview');
                return importTrello(
                  s,
                  plan,
                  title: v['title'],
                  completedLists: Set<String>.from(v['done'] as List),
                  includeLinks: v['links'] == true,
                  confirmed: v['confirm'] == true,
                );
              });
            },
            footer: [
              Text(
                '${plan.cards} ${tr(context, 'cards', 'thẻ')} · ${plan.lists} ${tr(context, 'lists', 'danh sách')}',
              ),
              Text(
                tr(
                  context,
                  'Lists become statuses. Categories remain independent. dueComplete does not determine task completion. Labels become tags; remote files, members, comments and automations are excluded.',
                  'Danh sách thành trạng thái; nhóm vẫn độc lập. dueComplete không tự quyết định hoàn tất task. Nhãn thành tag; không nhập tệp từ xa, thành viên, bình luận hay quy tắc.',
                ),
              ),
            ],
          );
          return;
        }
        if (parsed != null && parsed['app'] == 'handy-boards-template') {
          await boardForm(
            context,
            tr(context, 'Review board template', 'Kiểm tra mẫu bảng'),
            [
              const BoardField('title', 'New board name', 'Tên bảng mới'),
              if ((parsed['recurrence'] as List? ?? []).isNotEmpty)
                const BoardField(
                  'recurrence',
                  'Import recurring definitions · disabled until reviewed',
                  'Nhập định nghĩa lặp · tắt đến khi kiểm tra',
                  kind: 'bool',
                  optional: true,
                ),
              const BoardField(
                'confirm',
                'I reviewed this template',
                'Tôi đã kiểm tra mẫu này',
                kind: 'bool',
                optional: true,
              ),
            ],
            {'title': parsed['title'], 'confirm': false, 'recurrence': false},
            (v) async {
              await scope.controller.change(
                (s) => applyBoardTemplate(
                  s,
                  parsed,
                  title: v['title'],
                  confirmed: v['confirm'] == true,
                  includeRecurrence: v['recurrence'] == true,
                ),
              );
            },
            footer: [
              Text(
                (parsed['categories'] as List)
                    .map((c) => object(c)['title'])
                    .join(' · '),
              ),
              Text(
                '${(parsed['categories'] as List).length} ${tr(context, 'categories', 'nhóm')} · ${(parsed['tasks'] as List).length} ${tr(context, 'tasks', 'task')}',
              ),
            ],
          );
          return;
        }
      }
      final incoming = prepared?.snapshot ?? readBackup(file!.bytes),
          revision = scope.state.revision;
      await boardForm(
        context,
        tr(context, 'Review restore', 'Kiểm tra khôi phục'),
        [
          BoardField(
            'mode',
            'Restore mode',
            'Cách khôi phục',
            kind: 'select',
            options: {
              'merge': tr(context, 'Merge with new IDs', 'Gộp với ID mới'),
              'replace': tr(
                context,
                'Replace current library',
                'Thay thư viện hiện tại',
              ),
            },
          ),
          const BoardField(
            'confirm',
            'I confirm this restore',
            'Tôi xác nhận khôi phục',
            kind: 'bool',
            optional: true,
          ),
        ],
        {'mode': 'merge', 'confirm': false},
        (v) async {
          if (v['confirm'] != true)
            throw const FormatException('Explicit confirmation required');
          if (v['mode'] == 'replace' &&
              !await confirmBoards(
                context,
                tr(
                  context,
                  'Replace all current Boards data?',
                  'Thay toàn bộ dữ liệu Boards hiện tại?',
                ),
                tr(
                  context,
                  'Undo is available in this session. Export a backup first.',
                  'Có thể Hoàn tác trong phiên này. Nên xuất sao lưu trước.',
                ),
              ))
            return;
          await scope.controller.change((s) {
            if (s.revision != revision)
              throw StateError('Data changed during review; import again');
            return restoreBackup(
              s,
              incoming,
              replace: v['mode'] == 'replace',
              confirmed: true,
            );
          });
        },
        footer: [
          Text(
            '${incoming.rows('boards').length} ${tr(context, 'boards', 'bảng')} · ${incoming.rows('tasks').length} ${tr(context, 'tasks', 'task')} · ${incoming.rows('attachments').length} ${tr(context, 'attachments', 'tệp')}',
          ),
          Text(
            tr(
              context,
              'Merge remaps IDs. Imported system reminders are disabled until reviewed.',
              'Gộp tạo ID mới. Nhắc hệ thống nhập vào được tắt đến khi kiểm tra.',
            ),
          ),
        ],
      );
      return;
    }
    if (board == null)
      throw const FormatException('Select a destination board first');
    final source = utf8.decode(file!.bytes);
    if (ext == 'csv') {
      final rows = parseCsv(source);
      if (rows.isNotEmpty && rows.first.lastOrNull == 'record_b64') {
        if (await confirmBoards(
          context,
          tr(
            context,
            'Restore canonical task CSV?',
            'Khôi phục CSV task chuẩn?',
          ),
          tr(
            context,
            'Requires original board/category/status/tag/field dictionaries. Existing task IDs cannot be overwritten. Use full ZIP when transferring devices.',
            'Cần dữ liệu bảng/nhóm/status/tag/trường gốc. Không ghi đè ID task hiện có. Dùng ZIP đầy đủ khi chuyển thiết bị.',
          ),
        ))
          await scope.controller.change(
            (s) => importOwnTaskCsv(s, board, rows),
          );
        return;
      }
      if (rows.isEmpty) throw const FormatException('Empty CSV');
      await boardForm(
        context,
        tr(context, 'Map CSV columns', 'Chọn cột CSV'),
        [
          for (final (id, en, vi) in [
            ('title', 'Task title', 'Tên task'),
            ('notes', 'Notes', 'Ghi chú'),
            ('due', 'Due YYYY-MM-DD', 'Hạn YYYY-MM-DD'),
            ('status', 'Status name', 'Tên trạng thái'),
          ])
            BoardField(
              id,
              en,
              vi,
              kind: 'select',
              options: {
                if (id != 'title')
                  '': tr(context, 'Not imported', 'Không nhập'),
                for (var i = 0; i < rows.first.length; i++) '$i': rows.first[i],
              },
            ),
          const BoardField(
            'confirm',
            'I reviewed the destination and columns',
            'Tôi đã kiểm tra bảng đích và các cột',
            kind: 'bool',
            optional: true,
          ),
        ],
        {'title': '0', 'notes': '', 'due': '', 'status': '', 'confirm': false},
        (v) async {
          if (v['confirm'] != true)
            throw const FormatException('Review required');
          final columns = {
            for (final key in ['title', 'notes', 'due', 'status'])
              if (v[key] != '') key: int.parse(v[key]),
          };
          await scope.controller.change(
            (s) => importMappedCsv(s, board, rows, columns),
          );
        },
        footer: [
          Text(
            '${rows.length - 1} ${tr(context, 'data rows', 'dòng dữ liệu')}',
          ),
        ],
      );
    } else {
      final proposed = importLines(
        scope.state,
        board,
        source,
        markdown: ext == 'md',
      );
      if (await confirmBoards(
        context,
        tr(context, 'Import task list?', 'Nhập danh sách task?'),
        '${proposed.rows('tasks').length - scope.state.rows('tasks').length} ${tr(context, 'new tasks', 'task mới')}',
      )) {
        await scope.controller.change(
          (s) => importLines(s, board, source, markdown: ext == 'md'),
        );
      }
    }
  } finally {
    await prepared?.cleanup();
  }
}
