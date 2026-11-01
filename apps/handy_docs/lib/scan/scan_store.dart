import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import '../session.dart';

/// The scanner's pages on this device. Every change is written first and
/// only then shown; a failed write leaves the pages as they were.
class ScanStore extends ChangeNotifier {
  final DocumentRepository documents;
  final ScanCamera camera;
  ScanStore(this.documents, this.camera);

  ScanSession? session;
  Object? error;

  /// A photo the camera took while Android had closed the app.
  ImportedBytes? recovered;
  List<ScanPage> get pages => session?.pages ?? const [];
  bool get full => pages.length >= 20;

  Future<void> load() async {
    error = null;
    try {
      final raw = await documents.load();
      session = raw == null ? ScanSession([]) : ScanSession.parse(raw);
    } catch (e) {
      error = e;
    }
    notifyListeners();
    // Android can recreate the activity while the system camera is open.
    try {
      recovered = await camera.recover();
    } catch (_) {
      recovered = null;
    }
    notifyListeners();
  }

  Future<void> commit(List<ScanPage> next) async {
    final s = ScanSession(next);
    await documents.save(s.serialize());
    session = s;
    notifyListeners();
  }

  /// Puts a corrected page in place of [replace], or at the end.
  Future<void> put(Uint8List png, String name, {ScanPage? replace}) {
    final page = ScanPage(
      replace?.id ??
          '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
      replace?.name ?? name.substring(0, min(name.length, 200)),
      png,
    );
    return commit(
      replace == null
          ? [...pages, page]
          : [for (final p in pages) p.id == replace.id ? page : p],
    );
  }

  Future<void> move(int from, int to) {
    final list = [...pages];
    list.insert(to.clamp(0, list.length - 1), list.removeAt(from));
    return commit(list);
  }

  Future<void> remove(String id) => commit([
    for (final p in pages)
      if (p.id != id) p,
  ]);

  void dismissRecovered() {
    recovered = null;
    notifyListeners();
  }

  /// All pages as one PDF, saved where the person chooses. Null if canceled.
  Future<String?> exportPdf(
    HandyFiles files,
    CancellationToken token,
    ValueChanged<double> progress,
  ) async {
    final bytes = await scannerPdf(
      [for (final p in pages) p.png],
      cancellation: token,
      onProgress: progress,
    );
    return files.exportBytes(
      'handy-docs-scan.pdf',
      bytes,
      mimeType: 'application/pdf',
      cancellation: token,
    );
  }

  Future<String?> backup(HandyFiles files) => files.exportBytes(
    'handy-docs-session.json',
    Uint8List.fromList(utf8.encode(session!.serialize())),
    mimeType: 'application/json',
  );

  /// Reads and checks a session file; nothing changes until [commit].
  static ScanSession parseBackup(Uint8List bytes) =>
      ScanSession.parse(utf8.decode(bytes));
}
