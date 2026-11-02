import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/anki.dart';
import 'package:handy_recall/handy_recall.dart';
import 'recall_store.dart';
import 'schedule.dart' show forecast, stamp;

enum ImportStage { choose, reading, ready, saving, failed }

AnkiImport _read((Uint8List, String) job) =>
    readAnkiPackage(job.$1, now: job.$2);

/// Bringing an Anki package in: pick, read and check all of it (in the
/// background where the platform has isolates), preview, then one write.
/// Nothing reaches the library before [commit], and a failed write leaves
/// the preview as it was.
class AnkiImportController extends ChangeNotifier {
  final RecallStore store;
  final HandyFiles files;
  AnkiImportController({required this.store, required this.files});

  ImportStage stage = ImportStage.choose;
  AnkiImport? preview;
  String fileName = '';
  Object? error;

  /// Why this package cannot join the library as it is (too many cards for
  /// the limit, too large a backup), found before Import is offered.
  Object? blocked;

  /// Keep Anki's intervals and due days for cards reviewed there.
  bool keepSchedule = true;

  void setKeepSchedule(bool v) {
    keepSchedule = v;
    notifyListeners();
  }

  static const _trialPrefix = 'check';
  final _trials = <bool, RecallState>{};

  /// The library as it would be after Import, with the current schedule
  /// choice; null while blocked.
  RecallState? get trial {
    final p = preview;
    if (p == null || blocked != null) return null;
    return _trials[keepSchedule] ??= p.addTo(
      store.state!,
      keepSchedule: keepSchedule,
      idPrefix: _trialPrefix,
      now: stamp(store.clock()),
    );
  }

  /// The id an imported deck will have in [trial], for its colour.
  String trialDeck(int index) => '${_trialPrefix}_d$index';

  /// The imported cards due on each of the next 14 days, today first.
  List<int> get ahead {
    final t = trial;
    if (t == null) return const [];
    return forecast(
      RecallState(
        cards: t.cards.where((c) => c.id.startsWith('${_trialPrefix}_')),
      ),
      store.clock(),
    );
  }

  /// Opens the file picker; false when the person cancelled.
  Future<bool> pick() async {
    final ImportedBytes? file;
    try {
      file = await files.importBytes(
        extensions: const ['apkg', 'colpkg'],
        maxBytes: ankiPackageMaxBytes,
      );
    } catch (e) {
      _fail(e);
      return true;
    }
    if (file == null) return false;
    fileName = file.name;
    await read(file.bytes);
    return true;
  }

  /// Reads [bytes] as a package and checks it against the library.
  Future<void> read(Uint8List bytes) async {
    stage = ImportStage.reading;
    error = blocked = preview = null;
    _trials.clear();
    notifyListeners();
    try {
      final now = stamp(store.clock());
      // A small deck reads faster than an isolate starts; a large one reads
      // off the UI thread (on the web compute runs inline either way).
      final p = bytes.length < 2000000
          ? _read((bytes, now))
          : await compute(_read, (bytes, now));
      preview = p;
      keepSchedule = p.withHistory > 0;
      try {
        // Both choices, so a toggle can never fail later.
        trial;
        keepSchedule = !keepSchedule;
        trial;
        keepSchedule = !keepSchedule;
      } catch (e) {
        blocked = e;
        _trials.clear();
      }
      stage = ImportStage.ready;
    } catch (e) {
      _fail(e);
      return;
    }
    notifyListeners();
  }

  void _fail(Object e) {
    error = e;
    stage = ImportStage.failed;
    notifyListeners();
  }

  /// Writes every deck and card in one save; returns how many cards came in.
  Future<int> commit() async {
    final p = preview;
    if (p == null || blocked != null || stage == ImportStage.saving) return 0;
    stage = ImportStage.saving;
    notifyListeners();
    try {
      final next = p.addTo(
        store.state!,
        keepSchedule: keepSchedule,
        idPrefix: newId(),
        now: stamp(store.clock()),
      );
      await store.commit(next);
      return p.cards.length;
    } finally {
      stage = ImportStage.ready;
      notifyListeners();
    }
  }
}
