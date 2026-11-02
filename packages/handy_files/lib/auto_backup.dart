import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:handy_core/sealed.dart';
import 'backup_folder.dart';

export 'backup_folder.dart';

/// What the user chose for automatic backups. The app stores it (the kit
/// never stores user data); [seal] holds no secret, see [SealKey].
class AutoBackupSettings {
  final bool enabled;
  final BackupFolder? folder;
  final int keep, everyHours;
  final SealKey? seal;
  final DateTime? last;
  final String? lastName, lastError, lastRevision;
  const AutoBackupSettings({
    this.enabled = false,
    this.folder,
    this.keep = 7,
    this.everyHours = 24,
    this.seal,
    this.last,
    this.lastName,
    this.lastError,
    this.lastRevision,
  });

  static const keepChoices = [3, 7, 14, 30], everyChoices = [24, 168];

  AutoBackupSettings copyWith({
    bool? enabled,
    BackupFolder? folder,
    int? keep,
    int? everyHours,
    SealKey? seal,
    bool clearSeal = false,
    DateTime? last,
    String? lastName,
    String? lastError,
    bool clearError = false,
    String? lastRevision,
  }) => AutoBackupSettings(
    enabled: enabled ?? this.enabled,
    folder: folder ?? this.folder,
    keep: keep ?? this.keep,
    everyHours: everyHours ?? this.everyHours,
    seal: clearSeal ? null : seal ?? this.seal,
    last: last ?? this.last,
    lastName: lastName ?? this.lastName,
    lastError: clearError ? null : lastError ?? this.lastError,
    lastRevision: lastRevision ?? this.lastRevision,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    if (folder != null) 'folder': folder!.toJson(),
    'keep': keep,
    'everyHours': everyHours,
    if (seal != null) 'seal': seal!.toJson(),
    if (last != null) 'last': last!.toUtc().toIso8601String(),
    if (lastName != null) 'lastName': lastName,
    if (lastError != null) 'lastError': lastError,
    if (lastRevision != null) 'lastRevision': lastRevision,
  };

  /// Never throws: a damaged value comes back switched off.
  static AutoBackupSettings fromJson(Object? json) {
    if (json is! Map) return const AutoBackupSettings();
    SealKey? seal;
    try {
      if (json['seal'] is Map)
        seal = SealKey.fromJson((json['seal'] as Map).cast<String, Object?>());
    } catch (_) {
      return const AutoBackupSettings();
    }
    final keep = json['keep'], every = json['everyHours'];
    final last = json['last'] is String
        ? DateTime.tryParse(json['last'] as String)
        : null;
    return AutoBackupSettings(
      enabled: json['enabled'] == true,
      folder: BackupFolder.fromJson(json['folder']),
      keep: keepChoices.contains(keep) ? keep as int : 7,
      everyHours: everyChoices.contains(every) ? every as int : 24,
      seal: seal,
      last: last,
      lastName: json['lastName'] as String?,
      lastError: json['lastError'] as String?,
      lastRevision: json['lastRevision'] as String?,
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `handy-keep-2026-11-02-0930.zip`, plus `.hseal` when sealed.
String autoBackupName(
  String app,
  DateTime now,
  String extension, {
  bool sealed = false,
}) =>
    'handy-$app-${now.year}-${_two(now.month)}-${_two(now.day)}-'
    '${_two(now.hour)}${_two(now.minute)}.$extension'
    '${sealed ? '.$sealExtension' : ''}';

/// Whether [name] is one of this app's automatic backups: the only files
/// pruning may ever delete.
bool isAutoBackup(String app, String name) => RegExp(
  '^handy-${RegExp.escape(app)}-\\d{4}-\\d{2}-\\d{2}-\\d{4}'
  r'( \(\d+\))?\.[a-z]+(\.'
  '$sealExtension'
  r')?$',
).hasMatch(name);

bool autoBackupDue(AutoBackupSettings s, DateTime now, {String? revision}) {
  if (!s.enabled || s.folder == null) return false;
  if (revision != null && revision == s.lastRevision && s.lastError == null)
    return false;
  return s.last == null ||
      now.difference(s.last!) >= Duration(hours: s.everyHours);
}

/// Writes one backup and prunes the oldest automatic ones beyond `keep`.
/// Returns the settings to store; failures are recorded, not thrown.
Future<AutoBackupSettings> runAutoBackup({
  required String app,
  required String extension,
  required AutoBackupSettings settings,
  required BackupFolders folders,
  required Future<Uint8List> Function() build,
  String? revision,
  DateTime? now,

  /// Seals off the UI isolate where the platform allows it.
  Future<Uint8List> Function(Uint8List plain, SealKey key) sealWith = seal,
}) async {
  final at = now ?? DateTime.now();
  final folder = settings.folder;
  if (folder == null) return settings.copyWith(lastError: 'no-folder');
  try {
    if (!await folders.reachable(folder))
      return settings.copyWith(lastError: 'unreachable');
    final plain = await build();
    final bytes = settings.seal == null
        ? plain
        : await sealWith(plain, settings.seal!);
    final written = await folders.write(
      folder,
      autoBackupName(app, at, extension, sealed: settings.seal != null),
      bytes,
    );
    final updated = settings.copyWith(
      last: at,
      lastName: written.name,
      lastRevision: revision,
      clearError: true,
    );
    try {
      final own =
          (await folders.list(
              folder,
            )).where((e) => isAutoBackup(app, e.name)).toList()
            ..sort((a, b) => b.name.compareTo(a.name));
      for (final old in own.skip(settings.keep)) {
        if (old.name == written.name) continue;
        await folders.delete(folder, old);
      }
    } catch (_) {
      // The backup itself is safe; pruning tries again next time.
    }
    return updated;
  } catch (e) {
    return settings.copyWith(lastError: 'write');
  }
}

/// Where an app keeps its automatic-backup settings: on this device only,
/// never inside its data, since a folder grant does not travel.
String _prefKey(String app) => 'handy.$app.autoBackup';

Future<AutoBackupSettings> loadAutoBackupSettings(String app) async {
  try {
    final raw = (await SharedPreferences.getInstance()).getString(
      _prefKey(app),
    );
    return AutoBackupSettings.fromJson(raw == null ? null : jsonDecode(raw));
  } catch (_) {
    return const AutoBackupSettings();
  }
}

Future<void> saveAutoBackupSettings(String app, AutoBackupSettings s) async =>
    (await SharedPreferences.getInstance()).setString(
      _prefKey(app),
      jsonEncode(s.toJson()),
    );
