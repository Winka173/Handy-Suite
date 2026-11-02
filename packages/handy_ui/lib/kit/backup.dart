import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:handy_core/sealed.dart';
import 'package:handy_files/auto_backup.dart';
import 'dates.dart';
import 'l10n.dart';
import 'settings.dart';
import 'theme.dart';
import 'widgets.dart';

export 'package:handy_files/auto_backup.dart'
    show
        AutoBackupSettings,
        BackupFolders,
        systemBackupFolders,
        loadAutoBackupSettings,
        saveAutoBackupSettings;

Future<Uint8List> _sealTask((Uint8List, SealKey) job) => seal(job.$1, job.$2);
Future<Uint8List> _unsealTask((Uint8List, String) job) =>
    unseal(job.$1, job.$2);
Future<bool> _checkTask((SealKey, String) job) => job.$1.check(job.$2);
Future<SealKey> _createTask(String password) => SealKey.create(password);
Future<SealKey> _rewrapTask((SealKey, String, String) job) =>
    job.$1.rewrap(job.$2, job.$3);

/// Automatic backups for one app. The app gives its full backup bytes and
/// stores the settings (the kit never stores user data); this runs a backup
/// when the app opens or goes to the background, if one is due.
class HandyAutoBackup extends ChangeNotifier with WidgetsBindingObserver {
  final String app, extension;
  final Future<Uint8List> Function() build;
  final Future<void> Function(AutoBackupSettings) store;
  final Future<AutoBackupSettings> Function()? load;

  /// Changes whenever the data changes; an unchanged revision skips the run.
  final String? Function()? revision;
  final BackupFolders folders;
  AutoBackupSettings _settings;
  bool running = false;
  bool _attached = false;

  HandyAutoBackup({
    required this.app,
    required this.extension,
    required this.build,
    required this.store,
    required AutoBackupSettings initial,
    this.load,
    this.revision,
    BackupFolders? folders,
  }) : _settings = initial,
       folders = folders ?? systemBackupFolders();

  AutoBackupSettings get settings => _settings;

  Future<void> update(AutoBackupSettings value) async {
    _settings = value;
    notifyListeners();
    await store(value);
  }

  /// Settings kept on this device for [app], loaded before the first run.
  static HandyAutoBackup local({
    required String app,
    required String extension,
    required Future<Uint8List> Function() build,
    String? Function()? revision,
    BackupFolders? folders,
  }) => HandyAutoBackup(
    app: app,
    extension: extension,
    build: build,
    store: (s) => saveAutoBackupSettings(app, s),
    load: () => loadAutoBackupSettings(app),
    initial: const AutoBackupSettings(),
    revision: revision,
    folders: folders,
  );

  /// Starts watching the app's lifecycle and checks once now. Call it once
  /// the app's data is loaded.
  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(() async {
      if (load != null) {
        _settings = await load!();
        notifyListeners();
      }
      await maybeRun();
    }());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.resumed)
      unawaited(maybeRun());
  }

  Future<void> maybeRun() async {
    if (!folders.supported ||
        !autoBackupDue(_settings, DateTime.now(), revision: revision?.call()))
      return;
    await runNow();
  }

  Future<void> runNow() async {
    if (running || _settings.folder == null) return;
    running = true;
    notifyListeners();
    try {
      final next = await runAutoBackup(
        app: app,
        extension: extension,
        settings: _settings,
        folders: folders,
        build: build,
        revision: revision?.call(),
        sealWith: (plain, key) => compute(_sealTask, (plain, key)),
      );
      await update(next);
    } finally {
      running = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_attached) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// The "Back up automatically" section of an app's settings.
class HandyAutoBackupSection extends StatelessWidget {
  final HandyAutoBackup backup;
  const HandyAutoBackupSection({super.key, required this.backup});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: backup,
    builder: (context, _) => HandySettingsSection(
      title: tr(context, 'Back up automatically', 'Tự sao lưu'),
      description: backup.folders.supported
          ? tr(
              context,
              'A copy of everything, written to a folder you choose: this device, Google Drive, OneDrive. Runs when you open or leave the app, not while it is closed.',
              'Một bản sao của mọi thứ, ghi vào thư mục bạn chọn: máy này, Google Drive, OneDrive. Chạy khi bạn mở hoặc rời app, không chạy khi app đã đóng.',
            )
          : null,
      children: backup.folders.supported
          ? _controls(context)
          : [
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Text(
                  tr(
                    context,
                    'The browser does not let the app write to a folder. Use the manual backup below.',
                    'Trình duyệt không cho app ghi vào thư mục. Hãy dùng sao lưu thủ công bên dưới.',
                  ),
                ),
              ),
            ],
    ),
  );

  List<Widget> _controls(BuildContext context) {
    final s = backup.settings;
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final folder = s.folder;
    String folderName(BackupFolder f) => f.kind == 'documents'
        ? tr(context, 'Files › Handy', 'Tệp › Handy')
        : f.name.isEmpty
        ? tr(context, 'Chosen folder', 'Thư mục đã chọn')
        : f.name;
    String when(DateTime t) {
      final local = t.toLocal();
      final day = local.toIso8601String().substring(0, 10);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final time = TimeOfDay.fromDateTime(local).format(context);
      return day == today
          ? '${tr(context, 'Today', 'Hôm nay')} $time'
          : '${formatDay(context, day)} $time';
    }

    final error = switch (s.lastError) {
      null => null,
      'unreachable' => tr(
        context,
        'The app can no longer write to that folder. Choose it again.',
        'App không còn quyền ghi vào thư mục đó. Hãy chọn lại.',
      ),
      'no-folder' => tr(context, 'Choose a folder.', 'Hãy chọn thư mục.'),
      _ => tr(
        context,
        'The last backup could not be written.',
        'Lần sao lưu gần nhất không ghi được.',
      ),
    };
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.l,
          HandySpace.l,
          HandySpace.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                backup.running
                    ? tr(context, 'Backing up…', 'Đang sao lưu…')
                    : s.last == null
                    ? tr(context, 'No backup yet', 'Chưa có bản sao lưu')
                    : when(s.last!),
                key: const Key('backup-last'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (folder != null)
              Text(
                folderName(folder),
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            if (s.lastName != null && !backup.running)
              Text(
                s.lastName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            if (backup.running) ...[
              const SizedBox(height: HandySpace.s),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null && !backup.running) ...[
              const SizedBox(height: HandySpace.m),
              HandyNotice(
                error,
                tone: HandyTone.error,
                action: TextButton(
                  onPressed: () => s.lastError == 'write'
                      ? backup.runNow()
                      : _choose(context),
                  child: Text(
                    s.lastError == 'write'
                        ? tr(context, 'Try again', 'Thử lại')
                        : tr(context, 'Choose', 'Chọn'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: HandySpace.m),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                if (folder != null && s.lastError != 'unreachable')
                  FilledButton.tonal(
                    key: const Key('backup-now'),
                    onPressed: backup.running ? null : backup.runNow,
                    child: Text(tr(context, 'Back up now', 'Sao lưu ngay')),
                  ),
                if (folder == null)
                  FilledButton.tonal(
                    key: const Key('backup-folder'),
                    onPressed: () => _choose(context),
                    child: Text(tr(context, 'Choose a folder', 'Chọn thư mục')),
                  )
                else if (backup.folders.canChoose && s.lastError == null)
                  OutlinedButton(
                    key: const Key('backup-folder'),
                    onPressed: backup.running ? null : () => _choose(context),
                    child: Text(tr(context, 'Change folder', 'Đổi thư mục')),
                  ),
              ],
            ),
          ],
        ),
      ),
      if (folder != null) ...[
        SwitchListTile.adaptive(
          key: const Key('backup-enabled'),
          title: Text(tr(context, 'Run on its own', 'Chạy tự động')),
          value: s.enabled,
          onChanged: (v) => backup.update(s.copyWith(enabled: v)),
        ),
        HandySettingRow(
          label: tr(context, 'How often', 'Bao lâu một lần'),
          stackBelow: 420,
          control: SegmentedButton<int>(
            key: const Key('backup-every'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 24,
                label: Text(tr(context, 'Daily', 'Mỗi ngày')),
              ),
              ButtonSegment(
                value: 168,
                label: Text(tr(context, 'Weekly', 'Mỗi tuần')),
              ),
            ],
            selected: {s.everyHours},
            onSelectionChanged: (v) =>
                backup.update(s.copyWith(everyHours: v.single)),
          ),
        ),
        HandySettingRow(
          label: tr(context, 'Copies to keep', 'Số bản giữ lại'),
          stackBelow: 240,
          control: DropdownButton<int>(
            key: const Key('backup-keep'),
            value: s.keep,
            items: [
              for (final n in AutoBackupSettings.keepChoices)
                DropdownMenuItem(value: n, child: Text('$n')),
            ],
            onChanged: (v) => backup.update(s.copyWith(keep: v)),
          ),
        ),
        SwitchListTile.adaptive(
          key: const Key('backup-seal'),
          title: Text(
            tr(context, 'Lock with a password', 'Khóa bằng mật khẩu'),
          ),
          subtitle: Text(
            s.seal == null
                ? tr(
                    context,
                    'Anyone who gets the file can read it.',
                    'Ai có tệp cũng đọc được.',
                  )
                : tr(
                    context,
                    'Only the password opens these backups. A forgotten password cannot be recovered.',
                    'Chỉ mật khẩu mở được các bản sao lưu này. Quên mật khẩu thì không lấy lại được.',
                  ),
          ),
          value: s.seal != null,
          onChanged: backup.running
              ? null
              : (v) => v ? _lock(context) : _unlock(context),
        ),
        if (s.seal != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.s,
                0,
                HandySpace.s,
                HandySpace.s,
              ),
              child: TextButton(
                key: const Key('backup-password'),
                onPressed: () => _changePassword(context),
                child: Text(tr(context, 'Change password', 'Đổi mật khẩu')),
              ),
            ),
          ),
      ],
    ];
  }

  Future<void> _choose(BuildContext context) async {
    final picked = await backup.folders.choose();
    if (picked == null) return;
    final old = backup.settings.folder;
    if (old != null && old != picked) await backup.folders.forget(old);
    await backup.update(
      backup.settings.copyWith(folder: picked, enabled: true, clearError: true),
    );
    await backup.runNow();
  }

  Future<void> _lock(BuildContext context) async {
    final password = await _askPassword(context, confirm: true);
    if (password == null) return;
    final key = await compute(_createTask, password);
    await backup.update(backup.settings.copyWith(seal: key));
  }

  Future<void> _unlock(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Stop locking backups?', 'Thôi khóa bản sao lưu?'),
      message: tr(
        context,
        'New backups will be readable by anyone who gets the file. Backups already made stay locked.',
        'Bản sao lưu mới sẽ đọc được bởi bất kỳ ai có tệp. Các bản đã khóa vẫn giữ khóa.',
      ),
      confirmLabel: tr(context, 'Stop locking', 'Thôi khóa'),
    );
    if (ok) await backup.update(backup.settings.copyWith(clearSeal: true));
  }

  Future<void> _changePassword(BuildContext context) async {
    final key = backup.settings.seal!;
    final old = await _askPassword(context, current: key);
    if (old == null || !context.mounted) return;
    final next = await _askPassword(context, confirm: true);
    if (next == null) return;
    await backup.update(
      backup.settings.copyWith(
        seal: await compute(_rewrapTask, (key, old, next)),
      ),
    );
  }
}

/// Asks for a password. With [confirm], a new one typed twice; with
/// [current], the existing one, checked before the dialog closes.
Future<String?> _askPassword(
  BuildContext context, {
  bool confirm = false,
  SealKey? current,
  Future<String?> Function(String)? check,
}) => showAdaptiveDialog<String>(
  context: context,
  builder: (context) =>
      _PasswordDialog(confirm: confirm, current: current, check: check),
);

class _PasswordDialog extends StatefulWidget {
  final bool confirm;
  final SealKey? current;

  /// Returns an error message, or null when the password is right.
  final Future<String?> Function(String)? check;
  const _PasswordDialog({required this.confirm, this.current, this.check});
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final first = TextEditingController(), second = TextEditingController();
  bool hidden = true, busy = false;
  String? error;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = first.text;
    String? problem;
    if (widget.confirm && value.length < 8)
      problem = tr(
        context,
        'Use at least 8 characters.',
        'Dùng ít nhất 8 ký tự.',
      );
    else if (widget.confirm && value != second.text)
      problem = tr(
        context,
        'The two passwords differ.',
        'Hai mật khẩu không khớp.',
      );
    else if (value.isEmpty)
      problem = tr(context, 'Type the password.', 'Hãy nhập mật khẩu.');
    if (problem == null && (widget.current != null || widget.check != null)) {
      setState(() {
        busy = true;
        error = null;
      });
      if (widget.current != null) {
        final ok = await compute(_checkTask, (widget.current!, value));
        if (!mounted) return;
        if (!ok) problem = tr(context, 'Wrong password.', 'Sai mật khẩu.');
      } else {
        problem = await widget.check!(value);
        if (!mounted) return;
      }
      setState(() => busy = false);
    }
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    Widget field(TextEditingController controller, String label, Key key) =>
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.m),
          child: TextField(
            key: key,
            controller: controller,
            obscureText: hidden,
            autofocus: controller == first,
            enableSuggestions: false,
            autocorrect: false,
            enabled: !busy,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: controller == first
                  ? IconButton(
                      tooltip: hidden
                          ? tr(context, 'Show', 'Hiện')
                          : tr(context, 'Hide', 'Ẩn'),
                      icon: Icon(
                        hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => hidden = !hidden),
                    )
                  : null,
            ),
          ),
        );
    return AlertDialog(
      title: Text(
        widget.confirm
            ? tr(context, 'New password', 'Mật khẩu mới')
            : tr(context, 'Password', 'Mật khẩu'),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.confirm)
              Text(
                tr(
                  context,
                  'At least 8 characters. Nobody can open the backups without it, not even you.',
                  'Ít nhất 8 ký tự. Không ai mở được bản sao lưu nếu thiếu nó, kể cả bạn.',
                ),
              ),
            field(
              first,
              tr(context, 'Password', 'Mật khẩu'),
              const Key('password-first'),
            ),
            if (widget.confirm)
              field(
                second,
                tr(context, 'Type it again', 'Nhập lại'),
                const Key('password-second'),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: HandySpace.s),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    key: const Key('password-error'),
                    style: TextStyle(color: c.negative),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('password-cancel'),
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('password-ok'),
          onPressed: busy ? null : submit,
          child: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr(context, 'OK', 'Đồng ý')),
        ),
      ],
    );
  }
}

/// Opens [bytes] if it is a password-locked backup, asking for the password;
/// returns plain bytes unchanged. Null when the user backs out.
Future<Uint8List?> openSealedBackup(
  BuildContext context,
  Uint8List bytes,
) async {
  if (!isSealed(bytes)) return bytes;
  Uint8List? opened;
  final password = await _askPassword(
    context,
    check: (password) async {
      try {
        opened = await compute(_unsealTask, (bytes, password));
        return null;
      } on SealException catch (e) {
        if (!context.mounted) return null;
        return switch (e.failure) {
          SealFailure.wrongPassword => tr(
            context,
            'Wrong password.',
            'Sai mật khẩu.',
          ),
          SealFailure.unsupported => tr(
            context,
            'This backup was made by a newer version of the app.',
            'Bản sao lưu này do bản app mới hơn tạo.',
          ),
          _ => tr(context, 'The file is damaged.', 'Tệp đã bị hỏng.'),
        };
      }
    },
  );
  return password == null ? null : opened;
}
