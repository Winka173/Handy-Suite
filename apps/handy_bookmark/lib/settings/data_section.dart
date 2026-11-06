import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../data/import_export.dart';
import '../scope.dart';
import 'storage_summary.dart';

/// What the library takes on this device, with the one thing to do about
/// each part.
class SaveStorageSection extends StatelessWidget {
  final SaveScope scope;
  const SaveStorageSection({super.key, required this.scope});

  Future<void> _clearPreviews(BuildContext context) async {
    final c = scope.c;
    await scope.run(context, () async {
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
  }

  Future<void> _clearCopies(BuildContext context) async {
    final c = scope.c;
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

  @override
  Widget build(BuildContext context) => HandySettingsSection(
    title: tr(context, 'Space on this device', 'Dung lượng trên máy'),
    description: tr(
      context,
      'Clearing previews or offline copies never removes a link or a picture you added.',
      'Xóa ảnh xem trước hay bản đọc không bao giờ xóa link hay ảnh bạn đã thêm.',
    ),
    children: [
      StorageSummary(
        key: const Key('save-storage'),
        controller: scope.c,
        onClearPreviews: () => _clearPreviews(context),
        onClearCopies: () => _clearCopies(context),
        onTrash: () => Navigator.of(context).pushNamed('/trash'),
      ),
    ],
  );
}

/// Taking the library out and bringing it back.
class SaveBackupSection extends StatelessWidget {
  final SaveScope scope;
  const SaveBackupSection({super.key, required this.scope});
  @override
  Widget build(BuildContext context) => HandySettingsSection(
    title: tr(context, 'Export and restore', 'Xuất và khôi phục'),
    description: tr(
      context,
      'An exported file is a copy that leaves this device with whatever it holds, private addresses included.',
      'File xuất là một bản sao rời khỏi máy cùng mọi thứ bên trong, kể cả địa chỉ riêng tư.',
    ),
    children: [
      if (scope.c.lastBackup case final report?)
        Padding(
          padding: const EdgeInsets.all(HandySpace.m),
          child: BackupReportNote(report),
        ),
      HandyTile(
        key: const Key('save-export'),
        icon: Icons.archive_outlined,
        title: tr(context, 'Export or back up', 'Xuất hoặc sao lưu'),
        subtitle: 'JSON · ZIP · HTML · CSV · Markdown · TXT',
        navigates: true,
        onTap: () => scope.exportLinks(context),
      ),
      HandyTile(
        key: const Key('save-import'),
        icon: Icons.unarchive_outlined,
        title: tr(context, 'Import or restore', 'Nhập hoặc khôi phục'),
        subtitle: tr(
          context,
          'You see what a file holds before anything changes',
          'Xem trước nội dung file rồi mới thay đổi',
        ),
        navigates: true,
        onTap: () => scope.importLinks(context),
      ),
    ],
  );
}

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

/// The less frequent tools: other apps' exports, links saved twice, the
/// database check and undo.
class SaveLibraryTools extends StatelessWidget {
  final SaveScope scope;
  const SaveLibraryTools({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final c = scope.c;
    return HandySettingsSection(
      title: tr(context, 'Library tools', 'Công cụ thư viện'),
      children: [
        // Shown only while some link is saved more than once.
        if (duplicateGroups(c.library!) case final groups
            when groups.isNotEmpty)
          HandyTile(
            key: const Key('save-duplicates'),
            icon: Icons.merge_type,
            title: tr(
              context,
              groups.length == 1
                  ? '1 link saved twice'
                  : '${groups.length} links saved twice',
              '${groups.length} link lưu trùng',
            ),
            subtitle: tr(
              context,
              'Review and merge each into one.',
              'Xem lại và gộp mỗi link thành một.',
            ),
            navigates: true,
            onTap: () => Navigator.of(context).pushNamed('/duplicates'),
          ),
        HandyTile(
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
        HandyTile(
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
        if (scope.view.canUndo)
          HandyTile(
            key: const Key('save-undo'),
            icon: Icons.undo,
            title: tr(
              context,
              'Undo the last change',
              'Hoàn tác thay đổi gần nhất',
            ),
            onTap: () => scope.run(context, scope.view.undo),
          ),
        HandyTile(
          key: const Key('save-integrity'),
          icon: Icons.fact_check_outlined,
          title: tr(context, 'Check the library', 'Kiểm tra thư viện'),
          subtitle: tr(
            context,
            'Looks for damage in the file that holds it',
            'Tìm lỗi trong tệp lưu thư viện',
          ),
          onTap: () => scope.run(context, () async {
            final status = await c.store!.integrity();
            if (context.mounted) {
              showHandyMessage(
                context,
                status == 'ok'
                    ? tr(context, 'The library is healthy.', 'Thư viện vẫn ổn.')
                    : '${tr(context, 'Problem found', 'Phát hiện lỗi')}: $status',
              );
            }
          }),
        ),
      ],
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
              'Only when you start it: reading page details contacts that public website; folder sync writes to the folder you chose; exports and shared pages carry what you put in them.',
              'Chỉ khi bạn bắt đầu: đọc thông tin trang sẽ liên hệ website công khai đó; đồng bộ qua thư mục ghi vào thư mục bạn chọn; file xuất và trang chia sẻ mang theo những gì bạn đưa vào.',
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

/// Deletes every link, collection, tag and reminder on this device, after
/// a confirmation that names what goes.
Future<void> deleteEverything(BuildContext context, SaveScope scope) async {
  final c = scope.c;
  final ok = await confirmHandy(
    context,
    title: tr(context, 'Delete everything?', 'Xóa toàn bộ?'),
    message: tr(
      context,
      'Every link, collection, tag and reminder on this device. Export a backup first if you may want it back.',
      'Mọi link, bộ sưu tập, thẻ và hẹn nhắc trên máy này. Hãy xuất bản sao lưu trước nếu còn cần.',
    ),
    confirmLabel: tr(context, 'Delete everything', 'Xóa hết'),
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await scope.run(context, () async {
    await scope.view.change((_) => SaveLibrary(), prefs: {});
    await c.store!.clearThumbnails();
    await c.store!.clearReadingCopies();
    await c.refreshReading();
    await scope.reminders.cancelAll();
    c.clearThumbnailMemory();
  });
}
