import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/documents.dart';
import '../capture_draft.dart';
import '../capture_library.dart';

/// The guides on this device. Every change is written first and shown
/// after; a failed write leaves the library as it was.
class MediaStore extends ChangeNotifier {
  final DocumentRepository documents;

  /// Where each guide's draft copy lives; one store per guide.
  final DocumentRepository Function(String id) drafts;
  MediaStore(this.documents, {this.drafts = captureDraftDocuments});

  CaptureLibrary? library;
  Object? error;
  bool get loaded => library != null;

  /// Newest first: the library keeps them in the order last saved.
  List<PortableCapture> get guides => [...?library?.projects.reversed];

  Future<void> load() async {
    error = null;
    try {
      final text = await documents.load();
      library = text == null ? CaptureLibrary([]) : CaptureLibrary.parse(text);
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Future<void> commit(CaptureLibrary next) async {
    await documents.save(next.serialize());
    library = next;
    notifyListeners();
  }

  Future<void> save(PortableCapture guide, {bool importing = false}) =>
      commit(library!.save(guide, importing: importing));

  /// Removes a guide and its draft copy.
  Future<void> remove(String id) async {
    await commit(library!.remove(id));
    try {
      await CaptureDraft(drafts(id), id).clear();
    } catch (_) {
      // The guide is gone; a draft that will not clear holds nothing more.
    }
  }

  bool holds(String id) =>
      library?.projects.any((p) => p.project.id == id) ?? false;

  /// A portable ZIP or a version 1 JSON, read and checked whole.
  static PortableCapture read(Uint8List bytes) =>
      bytes.length >= 4 && bytes[0] == 80 && bytes[1] == 75
      ? parsePortableProject(bytes)
      : PortableCapture(CaptureProject.fromText(utf8.decode(bytes)), {});
}
