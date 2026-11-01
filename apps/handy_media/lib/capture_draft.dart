import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'capture_library.dart';

DocumentRepository captureDraftDocuments(String projectId) {
  final hash = sha256
      .convert(utf8.encode(projectId))
      .toString()
      .substring(0, 24);
  final suffix = hash
      .split('')
      .map((c) => String.fromCharCode(97 + int.parse(c, radix: 16)))
      .join();
  return localDocuments('handy-media-draft-$suffix', maxBytes: 30000000);
}

/// A separate, serialized store: failed backup writes never modify the library.
class CaptureDraft {
  final DocumentRepository documents;
  final String projectId;
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool _closed = false;
  CaptureDraft(this.documents, this.projectId);

  Future<PortableCapture?> load() async {
    final text = await documents.load();
    if (text == null) return null;
    final entries = CaptureLibrary.parse(text).projects;
    if (entries.isEmpty) return null;
    if (entries.length != 1 || entries.single.project.id != projectId)
      throw const FormatException(
        'Draft project identity mismatch; backup preserved',
      );
    return entries.single;
  }

  void schedule(
    PortableCapture Function() snapshot,
    void Function(Object) onError,
  ) {
    if (_closed) return;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), () {
      try {
        final text = CaptureLibrary([snapshot()]).serialize();
        _writes = _writes.then((_) => documents.save(text)).catchError((
          Object e,
        ) {
          onError(e);
        });
      } catch (e) {
        onError(e);
      }
    });
  }

  Future<void> clear() async {
    _timer?.cancel();
    await _writes;
    await documents.save(CaptureLibrary([]).serialize());
  }

  void dispose() {
    _closed = true;
    _timer?.cancel();
  }
}
