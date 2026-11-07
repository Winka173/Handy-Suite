import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_files/auto_backup.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../data/import_export.dart';
import '../scope.dart';
import 'settings_parts.dart';
import 'storage_summary.dart';

/// Back up: the whole library with its pictures and offline copies as
/// one ZIP, in a file the person places. What it held is kept, so
/// Settings can say when the last backup was and whether it was whole.
Future<void> backUp(BuildContext context, SaveScope scope) =>
    scope.run(context, () async {
      final lib = scope.library;
      final out = await scope.backupWithReport(lib);
      final uri = await scope.files.exportBytes(
        'handy-bookmark.zip',
        out.bytes,
        mimeType: 'application/zip',
      );
      if (uri == null) return;
      final report = BackupReport.of(
        out,
        at: saveTime(),
        automatic: false,
        links: lib.bookmarks.length,
      );
      await scope.c.recordBackup(report);
      if (!context.mounted) return;
      final n = lib.bookmarks.length;
      final pics = out.picturesIncluded, copies = out.readingIncluded;
      showHandyMessage(
        context,
        [
          tr(
            context,
            'Backed up ${n == 1 ? '1 item' : '$n items'}, '
                '${pics == 1 ? '1 picture' : '$pics pictures'} and '
                '${copies == 1 ? '1 offline copy' : '$copies offline copies'}.',
            'Đã sao lưu $n mục, $pics ảnh và $copies bản đọc offline.',
          ),
          if (!report.complete)
            tr(
              context,
              'Some things were left out; Settings says which.',
              'Một số thứ bị bỏ ra; xem chi tiết trong Cài đặt.',
            ),
        ].join(' '),
      );
    });

/// Settings › Storage: what the library takes, with the one thing to do
/// about each part.
Future<void> openStorage(BuildContext context, SaveScope scope) {
  final c = scope.c;
  Future<void> clearPreviews(BuildContext context) =>
      scope.run(context, () async {
        await c.store!.clearThumbnails();
        c.clearThumbnailMemory();
        if (context.mounted)
          showHandyMessage(
            context,
            tr(
              context,
              'Page pictures cleared. Your links and pictures are untouched.',
              'Đã xóa ảnh xem trước. Link và ảnh của bạn vẫn còn nguyên.',
            ),
          );
      });
  Future<void> clearCopies(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Remove every offline copy?',
        'Xóa mọi bản đọc offline?',
      ),
      message: tr(
        context,
        'The links stay. Copies can be saved again while the pages are online.',
        'Link vẫn giữ. Có thể lưu lại khi trang còn trên mạng.',
      ),
      confirmLabel: tr(context, 'Remove', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await scope.run(context, () async {
      await c.store!.clearReadingCopies();
      await c.refreshReading();
    });
  }

  return pushSettingsView(
    context,
    tr(context, 'Storage', 'Dung lượng'),
    listenable: c,
    (context) => [
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.s),
        child: Text(
          tr(
            context,
            'Clearing previews or offline copies never removes a link or a picture you added.',
            'Xóa ảnh xem trước hay bản đọc không bao giờ xóa link hay ảnh bạn đã thêm.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: HandyColors.of(context).muted,
          ),
        ),
      ),
      const SizedBox(height: HandySpace.l),
      StorageSummary(
        key: const Key('save-storage'),
        controller: c,
        onClearPreviews: () => clearPreviews(context),
        onClearCopies: () => clearCopies(context),
      ),
    ],
  );
}

/// Settings › Advanced export and import: every file format, and other
/// apps' exports.
Future<void> openAdvancedData(
  BuildContext context,
  SaveScope scope,
) => pushSettingsView(
  context,
  tr(context, 'Advanced export and import', 'Xuất và nhập nâng cao'),
  listenable: scope.c,
  (context) => [
    SettingsPanel(
      gap: false,
      title: tr(context, 'Export', 'Xuất'),
      note: tr(
        context,
        'An exported file is a copy that leaves this device with whatever it holds, private addresses included.',
        'File xuất là một bản sao rời khỏi máy cùng mọi thứ bên trong, kể cả địa chỉ riêng tư.',
      ),
      rows: [
        SettingsRow(
          key: const Key('save-export'),
          icon: Icons.file_upload_outlined,
          title: tr(context, 'Export as…', 'Xuất dạng…'),
          subtitle: 'ZIP · JSON · HTML · CSV · Markdown · TXT',
          navigates: true,
          onTap: () => scope.exportLinks(context),
        ),
      ],
    ),
    SettingsPanel(
      title: tr(context, 'From other apps', 'Từ app khác'),
      note: tr(
        context,
        'Only adds what is new, after showing what the file holds. Undo takes it back.',
        'Chỉ thêm mục mới, sau khi cho xem file có gì. Hoàn tác để bỏ lại.',
      ),
      rows: [
        SettingsRow(
          key: const Key('save-import-pocket'),
          icon: Icons.move_to_inbox_outlined,
          title: tr(context, 'Import from Pocket', 'Nhập từ Pocket'),
          subtitle: tr(
            context,
            'Pocket\'s CSV or ril_export.html: read state, tags and saved dates kept',
            'File CSV hoặc ril_export.html của Pocket: giữ trạng thái đọc, thẻ và ngày lưu',
          ),
          onTap: () => scope.importPocket(context),
        ),
        SettingsRow(
          key: const Key('save-import-raindrop'),
          icon: Icons.move_to_inbox_outlined,
          title: tr(context, 'Import from Raindrop', 'Nhập từ Raindrop'),
          subtitle: tr(
            context,
            'Raindrop.io CSV or HTML: folders, tags, notes and favourites kept',
            'File CSV hoặc HTML của Raindrop.io: giữ thư mục, thẻ, ghi chú và yêu thích',
          ),
          onTap: () => scope.importRaindrop(context),
        ),
      ],
    ),
  ],
);

/// What the last backup holds. "Complete" only when nothing was left out;
/// otherwise a warning that names what was left out and why (it is still
/// on this device).
class BackupReportNote extends StatelessWidget {
  final BackupReport report;
  const BackupReportNote(this.report, {super.key});

  @override
  Widget build(BuildContext context) {
    final at = DateTime.tryParse(report.at)?.toLocal();
    final when = at == null
        ? ''
        : '${MaterialLocalizations.of(context).formatShortDate(at)} '
              '${TimeOfDay.fromDateTime(at).format(context)}';
    final kind = report.automatic
        ? tr(context, 'Last automatic backup', 'Lần tự sao lưu gần nhất')
        : tr(context, 'Last backup', 'Lần sao lưu gần nhất');
    String why(OmissionReason r) => switch (r) {
      OmissionReason.tooLarge => tr(context, 'too large', 'quá lớn'),
      OmissionReason.missing => tr(
        context,
        'not on this device',
        'không có trên máy',
      ),
      OmissionReason.unreadable => tr(
        context,
        'could not be read',
        'không đọc được',
      ),
      OmissionReason.format => tr(
        context,
        'the format cannot hold them',
        'định dạng không chứa được',
      ),
    };
    String what(BackupOmission o) => o.what == 'pictures'
        ? tr(
            context,
            o.count == 1 ? '1 picture' : '${o.count} pictures',
            '${o.count} ảnh',
          )
        : tr(
            context,
            o.count == 1 ? '1 offline copy' : '${o.count} offline copies',
            '${o.count} bản đọc offline',
          );
    if (report.complete) {
      return HandyNotice(
        key: const Key('backup-report'),
        tr(
          context,
          '$kind $when: complete. ${report.links} links, ${report.picturesIncluded} pictures, ${report.readingIncluded} offline copies.',
          '$kind $when: đầy đủ. ${report.links} link, ${report.picturesIncluded} ảnh, ${report.readingIncluded} bản đọc offline.',
        ),
        tone: HandyTone.success,
      );
    }
    final left = [
      for (final o in report.omissions) '${what(o)} (${why(o.reason)})',
    ].join(', ');
    // Only what was too large, unreadable or unfit is still kept here.
    final kept = report.omissions.every(
      (o) => o.reason != OmissionReason.missing,
    );
    final still = kept ? ' They are still on this device.' : '';
    final stillVi = kept ? ' Chúng vẫn còn trên máy này.' : '';
    return HandyNotice(
      key: const Key('backup-report'),
      tr(
        context,
        '$kind $when left out $left.$still',
        '$kind $when thiếu $left.$stillVi',
      ),
      tone: HandyTone.warning,
    );
  }
}

/// What leaves the device, and when: shown from Settings › Help.
Future<void> showPrivacy(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: c.muted),
          const SizedBox(width: HandySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Privacy', 'Quyền riêng tư'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: HandySpace.l),
          point(
            Icons.phone_android_outlined,
            tr(context, 'Kept on this device', 'Lưu trên máy này'),
            tr(
              context,
              'Your links, pictures, notes and collections are stored on this device or in this browser. No account and no server of ours. The local database is not encrypted.',
              'Link, ảnh, ghi chú và bộ sưu tập được lưu trên máy hoặc trình duyệt này. Không tài khoản, không máy chủ riêng. Cơ sở dữ liệu trên máy không mã hóa.',
            ),
          ),
          point(
            Icons.public,
            tr(context, 'When something leaves', 'Khi nào dữ liệu rời máy'),
            tr(
              context,
              'Only when you start it: saving a link reads that public page for its title and picture (switch it off in Settings › Data › Library tools); folder sync writes to the folder you chose; exports and shared pages carry what you put in them.',
              'Chỉ khi bạn bắt đầu: lưu một link sẽ đọc trang công khai đó để lấy tiêu đề và ảnh (tắt trong Cài đặt › Dữ liệu › Công cụ thư viện); đồng bộ qua thư mục ghi vào thư mục bạn chọn; file xuất và trang chia sẻ mang theo những gì bạn đưa vào.',
            ),
          ),
          point(
            Icons.content_paste_outlined,
            tr(context, 'The clipboard', 'Clipboard'),
            tr(
              context,
              'Read only when you press Paste.',
              'Chỉ được đọc khi bạn bấm Dán.',
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Close', 'Đóng')),
          ),
        ],
      ),
    );
  },
);

/// Deletes all of the app's data on this device (items, pictures, offline
/// copies, previews, collections, tags, highlights, reminders and the
/// library's settings) after a confirmation that names what goes. Backup
/// files and a sync folder belong to the person and are not touched.
Future<void> deleteEverything(BuildContext context, SaveScope scope) async {
  final c = scope.c;
  final ok = await confirmHandy(
    context,
    title: tr(context, 'Delete all data?', 'Xóa toàn bộ dữ liệu?'),
    message: tr(
      context,
      "Every item, picture, offline copy, collection, tag, highlight and reminder on this device, the library's settings and its automatic copies. Backup files you saved elsewhere and your sync folder are not touched. Back up first if you may want it back.",
      'Mọi mục, ảnh, bản đọc offline, bộ sưu tập, thẻ, đoạn đánh dấu và hẹn nhắc trên máy này, cùng cài đặt của thư viện và các bản tự sao lưu. File sao lưu bạn đã cất nơi khác và thư mục đồng bộ không bị đụng tới. Hãy sao lưu trước nếu còn cần.',
    ),
    confirmLabel: tr(context, 'Delete all data', 'Xóa toàn bộ'),
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await scope.run(context, () async {
    await scope.view.change((_) => SaveLibrary(), prefs: {});
    await c.store!.clearThumbnails();
    await c.store!.clearReadingCopies();
    // No item or Trash item uses a picture any more: they all go now.
    await c.store!.collectMedia(const {}, grace: Duration.zero);
    // The automatic copies kept in the app's own storage go too; files the
    // person saved elsewhere are theirs and stay.
    if (scope.autoBackup case final backup?) {
      final folder = backup.settings.folder;
      if (folder != null) {
        try {
          for (final e in await backup.folders.list(folder)) {
            if (isAutoBackup('bookmark', e.name))
              await backup.folders.delete(folder, e);
          }
        } catch (_) {
          /* The library itself is already cleared. */
        }
        await backup.update(AutoBackupSettings(enabled: false, folder: folder));
      }
    }
    await c.refreshReading();
    await scope.reminders.cancelAll();
    c.clearThumbnailMemory();
  });
}
