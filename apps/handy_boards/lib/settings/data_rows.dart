import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_files/auto_backup.dart' show isAutoBackup;
import 'package:handy_files/handy_files.dart' show ImportedBytes;
import 'package:handy_ui/kit.dart';
import '../board/board_page.dart' show showUndo;
import '../features/portability.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'settings_parts.dart';

/// How often and how many: once a day when the boards changed, the last
/// seven kept (a week to go back to).
const autoBackupEveryHours = 24, autoBackupKeep = 7;

/// Settings › Data › Back up automatically, as one switch: copies go to the
/// app's own storage on this device, nothing to choose. Once there is one,
/// Restore and Save a copy sit under it.
class AutoBackupRow extends StatelessWidget {
  final BoardsScope scope;
  const AutoBackupRow({super.key, required this.scope});

  HandyAutoBackup get backup => scope.autoBackup!;

  Future<void> _set(bool on) async {
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
          )).where((e) => isAutoBackup('boards', e.name)).toList()
          ..sort((a, b) => b.name.compareTo(a.name));
    if (own.isEmpty) return null;
    return (own.first.name, await File(own.first.ref).readAsBytes());
  }

  Future<void> _restore(BuildContext context) async {
    final found = await _latest();
    if (!context.mounted) return;
    if (found == null) return _missing(context);
    await scope.run(
      context,
      () => importBoards(
        context,
        scope,
        null,
        given: ImportedBytes(found.$1, found.$2),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final found = await _latest();
    if (!context.mounted) return;
    if (found == null) return _missing(context);
    await scope.run(context, () async {
      await scope.files.exportBytes(
        found.$1,
        found.$2,
        mimeType: 'application/zip',
      );
    });
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
            key: const Key('settings-auto-backup'),
            icon: Icons.update,
            title: tr(context, 'Back up automatically', 'Tự sao lưu'),
            subtitle:
                '${tr(context, 'Once a day when something changed; the last $autoBackupKeep copies stay on this device', 'Mỗi ngày khi có thay đổi; giữ $autoBackupKeep bản gần nhất trên máy này')}\n$when',
            value: s.enabled,
            onChanged: _set,
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
                  TextButton.icon(
                    key: const Key('auto-backup-save'),
                    onPressed: () => _save(context),
                    icon: const Icon(Icons.save_alt, size: 20),
                    label: Text(tr(context, 'Save a copy', 'Lưu một bản')),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Cards put away by hand or by the 14-day automation. Cards that older
/// data folded into another card's subtasks are not offered: bringing them
/// back would count the work twice.
List<BoardRecord> archivedCards(BoardsState s) => [
  for (final t in s.rows('tasks'))
    if (t.flag('archived') &&
        !t.flag('trashed') &&
        t.data['parent'] == null &&
        t.data['mergedInto'] == null &&
        s.maybe('boards', t.str('board')) != null)
      t,
];

/// A sheet of archived boards or cards, each with Restore.
Future<void> showArchived(
  BuildContext context,
  BoardsScope scope, {
  required bool boards,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (sheet) => ListenableBuilder(
    listenable: scope.controller,
    builder: (sheet, _) {
      final s = scope.state;
      final rows = boards
          ? s.rows('boards').where((b) => b.flag('archived')).toList()
          : archivedCards(s);
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: HandySpace.l),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                boards
                    ? tr(context, 'Archived boards', 'Bảng đã lưu trữ')
                    : tr(context, 'Archived cards', 'Thẻ đã lưu trữ'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  tr(context, 'Nothing here.', 'Không còn gì ở đây.'),
                ),
              ),
            for (final r in rows)
              ListTile(
                key: Key('archived-${r.id}'),
                leading: boards
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: boardCover(r),
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined),
                title: Text(r.str('title')),
                subtitle: boards
                    ? null
                    : Text(s.get('boards', r.str('board')).str('title')),
                trailing: TextButton(
                  key: Key('restore-${r.id}'),
                  onPressed: () async {
                    await scope.run(
                      context,
                      () => scope.controller.change(
                        (s) => s.put(
                          boards ? 'boards' : 'tasks',
                          s.get(boards ? 'boards' : 'tasks', r.id).copy({
                            'archived': false,
                          }),
                        ),
                      ),
                    );
                    if (context.mounted)
                      showUndo(
                        context,
                        scope,
                        boards
                            ? tr(
                                context,
                                'Board is back on Your boards',
                                'Bảng đã trở lại Bảng của bạn',
                              )
                            : tr(
                                context,
                                'Card is back on its board',
                                'Thẻ đã trở lại bảng của nó',
                              ),
                      );
                  },
                  child: Text(tr(context, 'Restore', 'Khôi phục')),
                ),
              ),
          ],
        ),
      );
    },
  ),
);

/// Settings › Data › Delete all data: every board, card, photo and
/// reminder on this device and the automatic copies; language and theme
/// stay. The welcome shows again, as on a new install.
Future<void> deleteEverything(BuildContext context, BoardsScope scope) async {
  final ok = await confirmHandy(
    context,
    title: tr(context, 'Delete all data?', 'Xoá toàn bộ dữ liệu?'),
    message: tr(
      context,
      'Every board, card, category, cover, photo and reminder on this device, the archive, the Trash and the automatic copies. Backup files you saved elsewhere are not touched. Back up first if you may want it back.',
      'Mọi bảng, thẻ, nhóm, ảnh bìa, ảnh và lời nhắc trên máy này, cả mục lưu trữ, Thùng rác và các bản tự sao lưu. Tệp sao lưu bạn đã cất nơi khác không bị đụng tới. Hãy sao lưu trước nếu còn cần.',
    ),
    confirmLabel: tr(context, 'Delete all data', 'Xoá toàn bộ'),
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final navigator = Navigator.of(context);
  await scope.run(context, () async {
    final kept = scope.state.preferences;
    await scope.controller.change(
      (_) => BoardsState(
        preferences: {
          for (final key in const ['locale', 'theme'])
            if (kept[key] != null) key: kept[key],
        },
      ),
      history: false,
    );
    scope.controller.forgetHistory();
    // The automatic copies in the app's own storage go too; files the
    // person saved elsewhere are theirs and stay.
    if (scope.autoBackup case final backup?) {
      final folder = backup.settings.folder;
      if (folder != null) {
        try {
          for (final e in await backup.folders.list(folder)) {
            if (isAutoBackup('boards', e.name))
              await backup.folders.delete(folder, e);
          }
        } catch (_) {
          /* The boards themselves are already cleared. */
        }
        await backup.update(AutoBackupSettings(enabled: false, folder: folder));
      }
    }
  });
  navigator.popUntil((r) => r.isFirst);
}
