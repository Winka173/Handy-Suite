part of '../handy_boards_engine.dart';

/// Sync between the person's devices through a folder they own (Google
/// Drive's hidden app folder). It keeps devices agreeing, deletions
/// included; a backup is still a separate file. Layout under
/// [boardsSyncRoot]:
///
/// - `boards.json`: every synced record, in [boardsSyncFormat];
/// - `media/<sha256>`: each attachment's bytes, named by content.
///
/// Device settings (preferences: theme, language, reminders permission,
/// the widget, the guide), the activity log and the undo history stay on
/// each device.
///
/// Most records carry no edit time (columns, categories, subtasks), so the
/// merge is three-way: each device remembers a fingerprint of every record
/// as of its last sync (the *base*). A record changed on one side only
/// takes that side; changed on both, the later `updated` wins, else the
/// folder's copy (so every device picks the same); deleted on one side and
/// edited on the other, the edit lives on. Afterwards references that point
/// at something gone are repaired (a card whose column vanished goes to the
/// board's first column, a lost category becomes none), so the result
/// always validates.
const boardsSyncRoot = 'handy-boards';
const boardsSyncFormat = 'handy-boards-sync';
const boardsSyncVersion = 1;

/// Kinds that stay on each device.
const localOnlyKinds = {'events', 'executions'};
final syncedKinds = [
  for (final k in kinds)
    if (!localOnlyKinds.contains(k)) k,
];

/// The remote changed between reading and writing it.
class SyncConflict implements Exception {
  const SyncConflict();
  @override
  String toString() => 'SyncConflict';
}

/// A remote file and the version tag to write against.
class RemoteFile {
  final Uint8List bytes;
  final String etag;
  const RemoteFile(this.bytes, this.etag);
}

/// The person's cloud folder. The Google Drive adapter and the in-memory
/// test provider implement it. Paths are relative to the app's own folder.
abstract class SyncProvider {
  Future<RemoteFile?> read(String path);

  /// Writes [bytes]; with [ifMatch] only when the file is still at that
  /// tag, with [ifAbsent] only when there is none (else [SyncConflict]).
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  });

  /// Names directly under [folder].
  Future<Set<String>> list(String folder);
}

/// Records as plain data: kind → id → fields.
typedef SyncRecords = Map<String, Map<String, Json>>;

String _fingerprint(Object? json) =>
    sha256.convert(utf8.encode(jsonEncode(json))).toString();

/// The synced records of [s].
SyncRecords syncRecordsOf(BoardsState s) => {
  for (final k in syncedKinds) k: {for (final r in s.rows(k)) r.id: r.toJson()},
};

/// One fingerprint per record ('kind/id' → sha256): what a device keeps
/// as its base after a sync.
Map<String, String> syncBase(SyncRecords records) => {
  for (final k in records.entries)
    for (final r in k.value.entries) '${k.key}/${r.key}': _fingerprint(r.value),
};

Uint8List encodeSyncRecords(SyncRecords records) => Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'format': boardsSyncFormat,
      'version': boardsSyncVersion,
      'records': {
        for (final k in records.entries) k.key: k.value.values.toList(),
      },
    }),
  ),
);

SyncRecords decodeSyncRecords(Uint8List bytes) {
  final json = jsonDecode(utf8.decode(bytes));
  if (json is! Map ||
      json['format'] != boardsSyncFormat ||
      json['version'] != boardsSyncVersion ||
      json['records'] is! Map)
    throw const FormatException('Not a Handy Boards sync file');
  final raw = json['records'] as Map;
  return {
    for (final k in syncedKinds)
      k: {
        for (final r in (raw[k] as List? ?? const []))
          '${(r as Map)['id']}': Map<String, dynamic>.from(r),
      },
  };
}

/// Three-way merge of [local] and [remote] against [base] (fingerprints
/// from the last sync; empty on the first one, which then simply joins
/// both sides). See [boardsSyncRoot] for the rules.
SyncRecords mergeSyncRecords(
  SyncRecords local,
  SyncRecords remote,
  Map<String, String> base,
) {
  final out = <String, Map<String, Json>>{};
  for (final k in syncedKinds) {
    final l = local[k] ?? const {}, r = remote[k] ?? const {};
    final merged = <String, Json>{};
    for (final id in {...l.keys, ...r.keys, ..._baseIds(base, k)}) {
      final was = base['$k/$id'];
      final mine = l[id], theirs = r[id];
      final mineChanged = mine == null
          ? was != null
          : _fingerprint(mine) != was;
      final theirsChanged = theirs == null
          ? was != null
          : _fingerprint(theirs) != was;
      Json? pick;
      if (mine == null && theirs == null) {
        pick = null;
      } else if (mine == null) {
        // Deleted here (or never here): their edit since then lives on;
        // an unchanged copy follows the deletion.
        pick = was == null || theirsChanged ? theirs : null;
      } else if (theirs == null) {
        pick = was == null || mineChanged ? mine : null;
      } else if (!theirsChanged) {
        pick = mine;
      } else if (!mineChanged) {
        pick = theirs;
      } else {
        final a = mine['updated'], b = theirs['updated'];
        pick = a is String && b is String && a.compareTo(b) > 0 ? mine : theirs;
      }
      if (pick != null) merged[id] = pick;
    }
    out[k] = merged;
  }
  return out;
}

Iterable<String> _baseIds(Map<String, String> base, String kind) sync* {
  final prefix = '$kind/';
  for (final key in base.keys)
    if (key.startsWith(prefix)) yield key.substring(prefix.length);
}

/// Makes merged records consistent again: whatever points at a record that
/// no longer exists is moved, cleared or dropped. [hasFile] says whether an
/// attachment's bytes are on this device (an attachment without them is
/// dropped, and a cover pointing at it cleared).
SyncRecords repairSyncRecords(
  SyncRecords input, {
  bool Function(String path)? hasFile,
}) {
  final r = {
    for (final e in input.entries) e.key: {...e.value},
  };
  Map<String, Json> of(String k) => r[k] ??= {};
  bool has(String k, Object? id) => id is String && of(k).containsKey(id);

  // Boards need a workspace.
  if (of('boards').isNotEmpty && of('workspaces').isEmpty) {
    final w = newId();
    of('workspaces')[w] = {'id': w, 'title': 'Personal'};
  }
  final firstWorkspace = of('workspaces').keys.first;
  for (final b in of('boards').values.toList())
    if (!has('workspaces', b['workspace']))
      of('boards')[b['id']] = {...b, 'workspace': firstWorkspace};
  // Things that belong to a board go with it.
  for (final k in const [
    'statuses',
    'categories',
    'tags',
    'fields',
    'views',
    'rules',
    'templates',
    'subjects',
    'classes',
    'grades',
  ])
    of(
      k,
    ).removeWhere((_, v) => v['board'] != null && !has('boards', v['board']));
  for (final k in const ['subjects', 'classes', 'grades'])
    of(k).removeWhere((_, v) => !has('categories', v['category']));
  // Cards: a board, a column of that board, references that exist.
  final firstColumn = <String, String>{};
  for (final c
      in of('statuses').values.toList()..sort(
        (a, b) => (a['order'] as int? ?? 0).compareTo(b['order'] as int? ?? 0),
      ))
    firstColumn.putIfAbsent(c['board'] as String, () => c['id'] as String);
  final tasks = of('tasks');
  tasks.removeWhere(
    (_, t) => !has('boards', t['board']) || firstColumn[t['board']] == null,
  );
  for (final t in tasks.values.toList()) {
    final next = {...t};
    final status = of('statuses')[t['status']];
    if (status == null || status['board'] != t['board'])
      next['status'] = firstColumn[t['board']];
    final suggested = of('statuses')[t['suggestedStatus']];
    if (t['suggestedStatus'] != null &&
        (suggested == null || suggested['board'] != t['board']))
      next['suggestedStatus'] = null;
    final cat = of('categories')[t['category']];
    if (t['category'] != null && (cat == null || cat['board'] != t['board']))
      next['category'] = null;
    if (t['parent'] != null) {
      final parent = tasks[t['parent']];
      if (parent == null || parent['board'] != t['board'])
        next['parent'] = null;
    }
    if (t['tags'] is List)
      next['tags'] = [
        for (final tag in t['tags'] as List)
          if (of('tags')[tag]?['board'] == t['board']) tag,
      ];
    tasks[t['id'] as String] = next;
  }
  // What hangs on a card goes with it.
  for (final k in const [
    'checklist',
    'attachments',
    'reminders',
    'recurrence',
    'sessions',
  ])
    of(k).removeWhere((_, v) => !has('tasks', v['task']));
  of('attachments').removeWhere(
    (_, a) => a['path'] != null && hasFile != null && !hasFile(a['path']),
  );
  for (final t in tasks.values.toList()) {
    final photo = t['coverPhoto'];
    if (photo != null && of('attachments')[photo]?['task'] != t['id'])
      tasks[t['id'] as String] = {...t, 'coverPhoto': null};
  }
  for (final rule in of('recurrence').values.toList())
    if (rule['status'] != null && !has('statuses', rule['status']))
      of('recurrence')[rule['id']] = {...rule, 'status': null};
  of('occurrences').removeWhere(
    (_, o) => !has('recurrence', o['rule']) || !has('tasks', o['task']),
  );
  of('dependencies').removeWhere(
    (_, d) => !has('tasks', d['before']) || !has('tasks', d['after']),
  );
  // Saved views: drop a condition that points at something gone.
  for (final v in of('views').values.toList()) {
    final conditions = [
      for (final raw in (v['conditions'] as List? ?? const []))
        if (!(raw is Map &&
            [
              ('category', 'categories'),
              ('status', 'statuses'),
              ('tag', 'tags'),
            ].any((p) => raw[p.$1] != null && !has(p.$2, raw[p.$1]))))
          raw,
    ];
    of('views')[v['id']] = {...v, 'conditions': conditions};
  }
  return r;
}

/// Writes [records] into [local] as one edit (records only; preferences,
/// the activity log for cards that still exist and the revision stay), and
/// adds [files] received from the folder. Throws if the result would not
/// validate, leaving the device as it was.
BoardsState applySyncRecords(
  BoardsState local,
  SyncRecords records, {
  Map<String, Uint8List> files = const {},
}) {
  final e = BoardsEdit(local);
  for (final entry in files.entries) e.files[entry.key] = entry.value;
  for (final k in syncedKinds) {
    final want = records[k] ?? const {};
    for (final r in local.rows(k))
      if (!want.containsKey(r.id)) e.remove(k, r.id);
    for (final entry in want.entries) {
      final old = local.maybe(k, entry.key);
      if (old == null ||
          _fingerprint(old.toJson()) != _fingerprint(entry.value))
        e.put(k, BoardRecord(entry.value));
    }
  }
  final tasks = records['tasks'] ?? const {};
  for (final k in localOnlyKinds)
    for (final r in local.rows(k))
      if (r.data['task'] != null && !tasks.containsKey(r.str('task')))
        e.remove(k, r.id);
  final next = e.finish();
  next.validate();
  return next;
}

/// The device's attachment bytes, as sync needs them.
abstract class SyncFiles {
  /// Bytes at [path] on this device, or null.
  Future<Uint8List?> read(String path);
}

/// What one sync did. [records] is what the folder now holds: apply it
/// with [mergeSyncRecords] against the snapshot that was synced (local
/// edits made meanwhile survive), then keep [base] as the new base.
class BoardsSyncResult {
  final SyncRecords records;
  final Map<String, String> base;

  /// Attachment bytes received, by path.
  final Map<String, Uint8List> files;
  final int sent, attempts;
  final bool wrote;
  const BoardsSyncResult({
    required this.records,
    required this.base,
    required this.files,
    required this.sent,
    required this.attempts,
    required this.wrote,
  });
}

/// One sync: read the folder, merge with [local] against [base], send
/// attachment bytes the folder lacks, fetch those this device lacks (each
/// checked against its hash), then write the merged records only if they
/// differ, against the version read. A concurrent write from another
/// device is retried from the start, up to [attempts] times. Bytes go up
/// before the records that need them.
Future<BoardsSyncResult> syncBoardsOnce({
  required SyncRecords local,
  required Map<String, String> base,
  required SyncProvider remote,
  required SyncFiles files,
  int attempts = 3,
}) async {
  for (var attempt = 1; attempt <= attempts; attempt++) {
    final file = await remote.read('$boardsSyncRoot/boards.json');
    final theirs = file == null ? null : decodeSyncRecords(file.bytes);
    final merged = theirs == null
        ? local
        : mergeSyncRecords(local, theirs, base);
    final there = await remote.list('$boardsSyncRoot/media');
    var sent = 0;
    final received = <String, Uint8List>{};
    for (final a in (merged['attachments'] ?? const {}).values) {
      final path = a['path'], hash = a['sha256'];
      if (path is! String || hash is! String) continue;
      final mine = await files.read(path);
      if (mine != null) {
        if (!there.contains(hash)) {
          await remote.write('$boardsSyncRoot/media/$hash', mine);
          sent++;
        }
        continue;
      }
      final blob = await remote.read('$boardsSyncRoot/media/$hash');
      if (blob == null) continue;
      if (sha256.convert(blob.bytes).toString() != hash)
        throw const FormatException('A synced attachment does not match');
      received[path] = blob.bytes;
    }
    final fixed = repairSyncRecords(
      merged,
      hasFile: (path) => received.containsKey(path) || _known(local, path),
    );
    final same =
        theirs != null &&
        _fingerprint(syncBase(theirs)) == _fingerprint(syncBase(fixed));
    if (same)
      return BoardsSyncResult(
        records: fixed,
        base: syncBase(fixed),
        files: received,
        sent: sent,
        attempts: attempt,
        wrote: false,
      );
    try {
      await remote.write(
        '$boardsSyncRoot/boards.json',
        encodeSyncRecords(fixed),
        ifMatch: file?.etag,
        ifAbsent: file == null,
      );
      return BoardsSyncResult(
        records: fixed,
        base: syncBase(fixed),
        files: received,
        sent: sent,
        attempts: attempt,
        wrote: true,
      );
    } on SyncConflict {
      if (attempt == attempts) rethrow;
    }
  }
  throw const SyncConflict();
}

/// Whether [local] already had an attachment at [path] (so its bytes are
/// on the device).
bool _known(SyncRecords local, String path) =>
    (local['attachments'] ?? const {}).values.any((a) => a['path'] == path);

/// A folder kept in memory, for tests. [failWrites] makes the next writes
/// throw (a dropped connection); [beforeWrite] runs just before a records
/// write lands (to inject a concurrent change).
class MemorySyncProvider implements SyncProvider {
  final files = <String, (Uint8List, String)>{};
  int _tag = 0, failWrites = 0, writes = 0;
  Future<void> Function()? beforeWrite;

  @override
  Future<RemoteFile?> read(String path) async {
    final f = files[path];
    return f == null ? null : RemoteFile(f.$1, f.$2);
  }

  @override
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) async {
    if (failWrites > 0) {
      failWrites--;
      throw StateError('Connection lost');
    }
    if (path.endsWith('boards.json') && beforeWrite != null) {
      final hook = beforeWrite!;
      beforeWrite = null;
      await hook();
    }
    final old = files[path];
    if (ifAbsent && old != null) throw const SyncConflict();
    if (ifMatch != null && old?.$2 != ifMatch) throw const SyncConflict();
    final tag = 'v${++_tag}';
    files[path] = (Uint8List.fromList(bytes), tag);
    writes++;
    return tag;
  }

  @override
  Future<Set<String>> list(String folder) async => {
    for (final p in files.keys)
      if (p.startsWith('$folder/')) p.substring(folder.length + 1),
  };
}

/// Applies a sync to the device as it is now. [synced] is the snapshot the
/// sync started from: edits made on the device while it ran are merged in
/// on top of the folder's records, so nothing typed meanwhile is lost.
BoardsState applySyncResult(
  BoardsState current,
  SyncRecords synced,
  BoardsSyncResult result,
) {
  final mine = syncRecordsOf(current);
  final merged = mergeSyncRecords(mine, result.records, syncBase(synced));
  final fixed = repairSyncRecords(
    merged,
    hasFile: (path) => result.files.containsKey(path) || current.hasFile(path),
  );
  return applySyncRecords(current, fixed, files: result.files);
}

/// Attachment bytes read straight from a state (tests, small libraries).
class StateSyncFiles implements SyncFiles {
  final BoardsState state;
  const StateSyncFiles(this.state);
  @override
  Future<Uint8List?> read(String path) async =>
      state.hasFile(path) ? state.file(path) : null;
}
