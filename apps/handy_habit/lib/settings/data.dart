import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../scope.dart';
import '../ui/words.dart';

/// Writes a backup (JSON, ZIP) or a report of a range (CSV, Markdown,
/// PDF), after saying it holds private data. Returns a message, or null
/// when the person backed out.
Future<String?> exportHabits(
  BuildContext context,
  HabitScope scope,
  String format, {
  String? from,
  String? until,
}) async {
  final ok = await confirmHandy(
    context,
    title: tr(context, 'Export private data?', 'Xuất dữ liệu riêng tư?'),
    message: tr(
      context,
      'The file holds your habits and notes, unencrypted. Keep it where only you can open it.',
      'File chứa thói quen và ghi chú của bạn, không mã hóa. Hãy cất ở nơi chỉ bạn mở được.',
    ),
    confirmLabel: tr(context, 'Export', 'Xuất'),
    cancelLabel: tr(context, 'Cancel', 'Hủy'),
  );
  if (!ok || !context.mounted) return null;
  final s = scope.state, today = scope.today, vi = isVi(context);
  final first =
      from ??
      s.habits
          .map((h) => h.created)
          .fold<String>(today, (a, b) => a.compareTo(b) < 0 ? a : b);
  final last = until ?? today;
  late Uint8List bytes;
  late String mime;
  switch (format) {
    case 'json' || 'zip':
      bytes = backup(s, zip: format == 'zip');
      mime = format == 'zip' ? 'application/zip' : 'application/json';
    case 'csv':
      bytes = Uint8List.fromList(utf8.encode(csvLogs(s, first, last)));
      mime = 'text/csv';
    case 'md':
      bytes = Uint8List.fromList(
        utf8.encode(markdownReport(s, first, last, vietnamese: vi)),
      );
      mime = 'text/markdown';
    default:
      if (s.events.length > 10000)
        throw const FormatException(
          'Use CSV or ZIP for larger reports / Dùng CSV hoặc ZIP cho báo cáo lớn',
        );
      bytes = await _pdf(context, s, first, last);
      mime = 'application/pdf';
  }
  if (bytes.length > backupLimit)
    throw const FormatException('Export exceeds 30MB / File xuất vượt 30MB');
  final result = await scope.files.exportBytes(
    'handy-habit-$today.$format',
    bytes,
    mimeType: mime,
  );
  if (result == null || !context.mounted) return null;
  return kIsWeb
      ? tr(
          context,
          'Download requested; check the saved file.',
          'Đã yêu cầu tải; hãy kiểm tra file đã lưu.',
        )
      : tr(context, 'Exported.', 'Đã xuất file.');
}

Future<Uint8List> _pdf(
  BuildContext context,
  HabitState s,
  String first,
  String last,
) async {
  final headers = [
    tr(context, 'Habit', 'Thói quen'),
    tr(context, 'Done / planned', 'Đã làm / có lịch'),
    tr(context, 'Counted in', 'Tính theo'),
  ];
  final weeks = tr(context, 'weeks', 'tuần'),
      days = tr(context, 'planned days', 'ngày có lịch');
  final note = tr(
    context,
    'Skipped is not done. Periods still open are not failures. Paused days not done are left out; weekly quotas shrink with them.',
    'Bỏ qua không phải đã làm. Kỳ còn mở chưa phải thất bại. Ngày nghỉ chưa làm không tính; hạn mức tuần giảm theo ngày nghỉ.',
  );
  final names = {for (final h in s.habits) h.id: h.title};
  final pauses =
      s.pauses
          .where(
            (p) => p.until.compareTo(first) >= 0 && p.from.compareTo(last) <= 0,
          )
          .toList()
        ..sort((a, b) => a.from.compareTo(b.from));
  final pauseTitle = tr(context, 'Pauses', 'Kỳ nghỉ'),
      everyone = tr(context, 'Every habit', 'Mọi thói quen');
  final font = pw.Font.ttf(
    await rootBundle.load(
      'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
    ),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('packages/handy_ui/assets/fonts/NotoSans-Bold.ttf'),
  );
  final index = HabitIndex.of(s), doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: 200,
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      build: (_) => [
        pw.Text('Handy Habit', style: const pw.TextStyle(fontSize: 22)),
        pw.Text('$first — $last · ${s.zone}'),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: [
            for (final h in s.habits)
              () {
                final m = metrics(h, last, s.weekStart, index, from: first);
                return [
                  h.title,
                  '${m.completed} / ${m.eligible}',
                  m.unit == 'weeks' ? weeks : days,
                ];
              }(),
          ],
        ),
        pw.Text(note),
        if (pauses.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(pauseTitle, style: const pw.TextStyle(fontSize: 16)),
          for (final p in pauses)
            pw.Text(
              [
                '${p.from} — ${p.until}',
                p.everything
                    ? everyone
                    : p.habits.map((h) => names[h] ?? '').join(', '),
                if (p.reason.isNotEmpty) p.reason,
              ].join(' · '),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Reads a backup or a CSV log in full, shows what it holds, then merges
/// (new IDs, nothing overwritten) or replaces after a second question.
Future<String?> importHabits(BuildContext context, HabitScope scope) async {
  final file = await scope.files.importBytes(
    extensions: ['json', 'zip', 'csv', 'hseal'],
    maxBytes: backupLimit,
  );
  if (file == null || !context.mounted) return null;
  // A password-locked automatic backup: open it, then read the ZIP inside.
  final opened = await openSealedBackup(context, file.bytes);
  if (opened == null || !context.mounted) return null;
  final name = file.name.toLowerCase().endsWith('.hseal')
      ? file.name.substring(0, file.name.length - 6)
      : file.name;
  final s = scope.state, revision = s.revision;
  if (name.toLowerCase().endsWith('.csv')) {
    final imported = importCsvLogs(s, opened);
    final count = imported.events.length - s.events.length,
        pauses = imported.pauses.length - s.pauses.length;
    final ok = await confirmHandy(
      context,
      title: pauses == 0
          ? tr(context, 'Add $count records?', 'Thêm $count lần ghi?')
          : tr(
              context,
              'Add $count records and $pauses pauses?',
              'Thêm $count lần ghi và $pauses kỳ nghỉ?',
            ),
      message: tr(
        context,
        'Their habits must already exist here. Repeated records are left out; conflicting ones stop the import.',
        'Thói quen tương ứng phải có sẵn. Lần ghi trùng được bỏ qua; lần ghi xung đột sẽ dừng việc nhập.',
      ),
      confirmLabel: tr(context, 'Add', 'Thêm'),
    );
    if (!ok) return null;
    await scope.controller.change((current) {
      if (current.revision != revision)
        throw StateError('Data changed during preview');
      return current.copy({
        'events': imported.events.map((e) => e.toJson()).toList(),
        'pauses': imported.pauses.map((p) => p.toJson()).toList(),
      });
    });
    return context.mounted
        ? (pauses == 0
              ? tr(context, '$count records added.', 'Đã thêm $count lần ghi.')
              : tr(
                  context,
                  '$count records and $pauses pauses added.',
                  'Đã thêm $count lần ghi và $pauses kỳ nghỉ.',
                ))
        : null;
  }
  final preview = inspectBackup(
    opened,
    zip: opened.length >= 2 && opened[0] == 0x50 && opened[1] == 0x4b,
  );
  final imported = preview.state;
  if (!context.mounted) return null;
  final created = preview.createdAt == null
      ? null
      : DateTime.parse(preview.createdAt!).toLocal();
  final backupDate = created == null
      ? tr(context, 'Date not recorded', 'Chưa ghi ngày sao lưu')
      : '${formatDay(context, day(created))} · ${TimeOfDay.fromDateTime(created).format(context)}';
  final choice = await showAdaptiveDialog<String>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(tr(context, 'What the backup holds', 'Bản sao lưu có gì')),
      constraints: const BoxConstraints(maxWidth: 720),
      scrollable: true,
      content: Text(
        tr(
          context,
          '${formatFigure(context, '${file.bytes.length}')} bytes · Schema ${preview.schema}\n$backupDate\n${imported.trash.length} items in Trash\n${imported.habits.length} habits, ${imported.events.length} records, ${imported.routines.length} routines, ${imported.sessions.length} runs, ${imported.pauses.length} pauses.\n\nMerge adds them beside yours with new IDs. Replace puts the backup in place of everything here. Reminders in it stay off until you turn them on.',
          '${formatFigure(context, '${file.bytes.length}')} byte · Schema ${preview.schema}\n$backupDate\n${imported.trash.length} mục trong Thùng rác\n${imported.habits.length} thói quen, ${imported.events.length} lần ghi, ${imported.routines.length} quy trình, ${imported.sessions.length} phiên, ${imported.pauses.length} kỳ nghỉ.\n\nHợp nhất thêm chúng cạnh dữ liệu của bạn với ID mới. Thay thế đặt bản sao lưu vào chỗ toàn bộ dữ liệu ở đây. Nhắc trong đó vẫn tắt cho tới khi bạn bật.',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('import-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('import-merge'),
          onPressed: () => Navigator.pop(context, 'merge'),
          child: Text(tr(context, 'Merge', 'Hợp nhất')),
        ),
        TextButton(
          key: const Key('import-replace'),
          onPressed: () => Navigator.pop(context, 'replace'),
          child: Text(tr(context, 'Replace', 'Thay thế')),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return null;
  if (choice == 'replace' &&
      !await confirmHandy(
        context,
        title: tr(
          context,
          'Replace everything here?',
          'Thay toàn bộ dữ liệu ở đây?',
        ),
        message: tr(
          context,
          'A recovery copy of current data will be saved on this device before replacement. You can recover it in Settings. If saving fails, replacement stops.',
          'Lưu bản khôi phục dữ liệu hiện tại trên máy này trước khi thay thế. Bạn có thể khôi phục từ Cài đặt. Nếu lưu thất bại, dừng thay thế.',
        ),
        confirmLabel: tr(context, 'Replace', 'Thay thế'),
        destructive: true,
      ))
    return null;
  if (choice == 'replace') {
    final next = imported.copy({
      'settings': {
        ...imported.settings,
        'notifications': false,
        'reminders': [
          for (final r in objects(imported.settings['reminders'] ?? []))
            {...r, 'enabled': false},
        ],
      },
    });
    await scope.controller.replaceFromBackup(next, expectedRevision: revision);
  } else {
    await scope.controller.change((current) {
      if (current.revision != revision)
        throw StateError('Data changed while previewing import');
      return merge(current, imported);
    });
  }
  return context.mounted
      ? (choice == 'merge'
            ? tr(context, 'Backup merged.', 'Đã hợp nhất.')
            : tr(context, 'Backup restored.', 'Đã khôi phục.'))
      : null;
}
