import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:handy_files/handy_files.dart' show ImportedBytes;
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
      [
        ...s.habits.map((h) => h.created),
        ...s.moods.map((m) => m.day),
      ].fold<String>(today, (a, b) => a.compareTo(b) < 0 ? a : b);
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
        utf8.encode(
          markdownReport(s, first, last, vietnamese: vi, today: today),
        ),
      );
      mime = 'text/markdown';
    default:
      if (s.events.length > 10000)
        throw const FormatException(
          'Use CSV or ZIP for larger reports / Dùng CSV hoặc ZIP cho báo cáo lớn',
        );
      bytes = await _pdf(context, s, first, last, today);
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
  String today,
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
    'Pauses, unknown days and unfinished periods are left out. Weekly limits count recorded incidents; blank days mean none once the week closes. Positive weekly quotas shrink with pauses.',
    'Bỏ qua ngày nghỉ, ngày chưa rõ và khoảng chưa hết. Giới hạn tuần tính số lần đã ghi; hết tuần, ngày trống hiểu là không có. Chỉ mục tiêu xây dựng theo tuần giảm theo ngày nghỉ.',
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
                final m = progressCount(h, first, last, today, index);
                return [
                  h.title,
                  '${m.kept} / ${m.eligible}',
                  m.unit == 'goals'
                      ? tr(
                          context,
                          'daily / weekly goals',
                          'mục tiêu ngày / tuần',
                        )
                      : m.unit == 'weeks'
                      ? weeks
                      : days,
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
Future<String?> importHabits(
  BuildContext context,
  HabitScope scope, {
  ImportedBytes? given,
}) async {
  final file =
      given ??
      await scope.files.importBytes(
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
        pauses = imported.pauses.length - s.pauses.length,
        moods = imported.moods.length - s.moods.length;
    final ok = await confirmHandy(
      context,
      title: pauses == 0
          ? tr(
              context,
              'Add $count ${count == 1 ? 'record' : 'records'}?',
              'Thêm $count lần ghi?',
            )
          : tr(
              context,
              'Add $count ${count == 1 ? 'record' : 'records'} and $pauses ${pauses == 1 ? 'pause' : 'pauses'}?',
              'Thêm $count lần ghi và $pauses kỳ nghỉ?',
            ),
      message: tr(
        context,
        '$moods ${moods == 1 ? 'mood entry' : 'mood entries'} included. Their habits must already exist here. Repeated records are left out; conflicting ones stop the import.',
        'Gồm $moods bản ghi tâm trạng. Thói quen tương ứng phải có sẵn. Lần ghi trùng được bỏ qua; lần ghi xung đột sẽ dừng việc nhập.',
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
        'moods': imported.moods.map((m) => m.toJson()).toList(),
      });
    });
    return context.mounted
        ? (pauses == 0
              ? tr(
                  context,
                  '$count ${count == 1 ? 'record' : 'records'} added.',
                  'Đã thêm $count lần ghi.',
                )
              : tr(
                  context,
                  '$count ${count == 1 ? 'record' : 'records'} and $pauses ${pauses == 1 ? 'pause' : 'pauses'} added.',
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
    animationStyle: AnimationStyle(
      duration: HandyMotion.of(context),
      reverseDuration: HandyMotion.of(context),
    ),
    builder: (context) => AlertDialog.adaptive(
      title: Text(tr(context, 'What the backup holds', 'Bản sao lưu có gì')),
      constraints: const BoxConstraints(maxWidth: 720),
      scrollable: true,
      content: Text(
        tr(
          context,
          '${formatFigure(context, '${file.bytes.length}')} bytes · Schema ${preview.schema}\n$backupDate\n${imported.trash.length} ${imported.trash.length == 1 ? 'item' : 'items'} in Trash\n${imported.habits.length} ${imported.habits.length == 1 ? 'habit' : 'habits'}, ${imported.events.length} ${imported.events.length == 1 ? 'record' : 'records'}, ${imported.routines.length} ${imported.routines.length == 1 ? 'routine' : 'routines'}, ${imported.sessions.length} ${imported.sessions.length == 1 ? 'run' : 'runs'}, ${imported.pauses.length} ${imported.pauses.length == 1 ? 'pause' : 'pauses'}, ${imported.moods.length} ${imported.moods.length == 1 ? 'mood entry' : 'mood entries'} (including deleted).\n\nMerge adds them beside yours with new IDs. Mood dates stay fixed: identical entries are left out; different entries for the same date stop the merge. Replace puts the backup in place of everything here. Reminders in it stay off until you turn them on.',
          '${formatFigure(context, '${file.bytes.length}')} byte · Schema ${preview.schema}\n$backupDate\n${imported.trash.length} mục trong Thùng rác\n${imported.habits.length} thói quen, ${imported.events.length} lần ghi, ${imported.routines.length} quy trình, ${imported.sessions.length} phiên, ${imported.pauses.length} kỳ nghỉ, ${imported.moods.length} bản ghi tâm trạng (gồm đã xóa).\n\nHợp nhất thêm chúng cạnh dữ liệu của bạn với ID mới. Ngày tâm trạng giữ nguyên: bỏ bản ghi giống nhau; khác nhau cùng ngày thì dừng gộp. Thay thế đặt bản sao lưu vào chỗ toàn bộ dữ liệu ở đây. Nhắc trong đó vẫn tắt cho tới khi bạn bật.',
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
        'convenienceRules': [
          for (final r in convenienceRules(imported))
            {...r.toJson(), 'enabled': false},
        ],
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
