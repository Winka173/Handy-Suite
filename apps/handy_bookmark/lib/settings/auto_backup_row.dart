import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:handy_files/auto_backup.dart' show isAutoBackup;
import 'package:handy_ui/kit.dart';
import '../bookmark/share_item.dart' show shareFileNow;
import '../data/import_export.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// How often and how many: once a day when the library changed, the last
/// seven kept (a week to go back to).
const autoBackupEveryHours = 24, autoBackupKeep = 7;

/// Settings › Data › Back up automatically, as one switch: copies go to the
/// app's own storage on this device, nothing to choose. Once there is one,
/// Restore and Share sit under it.
class AutoBackupRow extends StatelessWidget {
  final SaveScope scope;
  const AutoBackupRow({super.key, required this.scope});

  HandyAutoBackup get backup => scope.autoBackup!;

  Future<void> _set(BuildContext context, bool on) async {
    final s = backup.settings;
    if (!on) return backup.update(s.copyWith(enabled: false));
    final folder = s.folder ?? await backup.folders.choose();
    if (folder == null) return;
    await backup.update(
      s.copyWith(
        enabled: true,
        folder: folder,
        keep: autoBackupKeep,
        everyHours: autoBackupEveryHours,
      ),
    );
    // Switched on: the first copy is made now.
    await backup.runNow();
  }

  /// The newest automatic copy kept here, read whole.
  Future<(String, Uint8List)?> _latest() async {
    final folder = backup.settings.folder;
    if (folder == null || kIsWeb) return null;
    final own =
        (await backup.folders.list(
            folder,
          )).where((e) => isAutoBackup('bookmark', e.name)).toList()
          ..sort((a, b) => b.name.compareTo(a.name));
    if (own.isEmpty) return null;
    return (own.first.name, await File(own.first.ref).readAsBytes());
  }

  Future<void> _restore(BuildContext context) async {
    final found = await _latest();
    if (!context.mounted) return;
    if (found == null) return _missing(context);
    await scope.restoreFrom(context, found.$1, found.$2);
  }

  Future<void> _share(BuildContext context) async {
    final found = await _latest();
    if (!context.mounted) return;
    if (found == null) return _missing(context);
    final box = context.findRenderObject() as RenderBox?;
    final at = box == null || !box.hasSize
        ? Rect.zero
        : box.localToGlobal(Offset.zero) & box.size;
    try {
      await shareFileNow(found.$1, found.$2, 'application/zip', at);
    } catch (_) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not share it.', 'Chưa chia sẻ được.'),
        );
    }
  }

  void _missing(BuildContext context) => showHandyMessage(
    context,
    tr(
      context,
      'No automatic copy is on this device yet.',
      'Chưa có bản tự sao lưu nào trên máy này.',
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: backup,
    builder: (context, _) {
      final s = backup.settings;
      final at = s.last?.toLocal();
      final when = backup.running
          ? tr(context, 'Backing up now…', 'Đang sao lưu…')
          : s.enabled && s.lastError != null
          ? tr(
              context,
              'The last copy could not be written.',
              'Lần gần nhất chưa ghi được.',
            )
          : at == null
          ? tr(context, 'No copy yet', 'Chưa có bản nào')
          : tr(
              context,
              'Last: ${MaterialLocalizations.of(context).formatMediumDate(at)} ${TimeOfDay.fromDateTime(at).format(context)}',
              'Gần nhất: ${MaterialLocalizations.of(context).formatMediumDate(at)} ${TimeOfDay.fromDateTime(at).format(context)}',
            );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSwitch(
            key: const Key('set-auto-backup'),
            icon: Icons.update,
            title: tr(context, 'Back up automatically', 'Tự sao lưu'),
            subtitle:
                '${tr(context, 'Once a day when something changed; the last $autoBackupKeep copies stay on this device', 'Mỗi ngày khi có thay đổi; giữ $autoBackupKeep bản gần nhất trên máy này')}\n$when',
            value: s.enabled,
            onChanged: (v) => _set(context, v),
          ),
          if (s.last != null)
            Padding(
              // In line with the switch's words, past its icon.
              padding: const EdgeInsets.only(left: 48, bottom: HandySpace.s),
              child: Wrap(
                spacing: HandySpace.xs,
                children: [
                  TextButton.icon(
                    key: const Key('auto-backup-restore'),
                    onPressed: () => _restore(context),
                    icon: const Icon(Icons.settings_backup_restore, size: 20),
                    label: Text(tr(context, 'Restore', 'Khôi phục')),
                  ),
                  Builder(
                    builder: (context) => TextButton.icon(
                      key: const Key('auto-backup-share'),
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.ios_share_rounded, size: 20),
                      label: Text(tr(context, 'Share', 'Chia sẻ')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
