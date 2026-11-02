import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_ocr/handy_ocr.dart';

/// A page to read: a scan or a PDF page drawn as a picture.
class OcrSource {
  final String label;
  final Uint8List image;
  const OcrSource(this.label, this.image);
}

enum OcrState { checking, unavailable, chooseLanguage, reading, done, failed }

/// Reading one page on this device. The words land in [text], which the
/// person may edit before copying or saving; the picture is never kept.
class OcrJob extends ChangeNotifier {
  final OcrSource source;

  /// 'vi' or 'en': the app's language, tried first.
  final String preferred;
  OcrJob(this.source, {required this.preferred});

  OcrState state = OcrState.checking;
  OcrSupport support = OcrSupport.none;
  OcrResult? result;
  String? language;
  Object? error;
  final text = TextEditingController();
  CancellationToken? _token;
  bool _closed = false;

  /// Width ÷ height of the page picture, from its PNG header.
  double get aspect {
    final r = result;
    if (r != null && r.height > 0) return r.width / r.height;
    final b = source.image;
    if (b.length > 24 && b[0] == 0x89 && b[1] == 0x50) {
      final d = ByteData.sublistView(b);
      final w = d.getUint32(16), h = d.getUint32(20);
      if (w > 0 && h > 0) return w / h;
    }
    return 1 / 1.414;
  }

  /// Checks the engine; reads straight away when the language is there.
  Future<void> start() async {
    support = await ocrSupport();
    if (!support.available) {
      _set(OcrState.unavailable);
      return;
    }
    if (!support.listsLanguages) return read(null);
    final tag = support.match(preferred);
    if (tag != null) return read(tag);
    _set(OcrState.chooseLanguage);
  }

  /// Reads with [tag] (an installed language, or null for the engine's own).
  Future<void> read(String? tag) async {
    _token?.cancel();
    final token = _token = CancellationToken();
    language = tag;
    error = null;
    _set(OcrState.reading);
    try {
      final r = await recognizeText(
        source.image,
        language: tag,
        cancellation: token,
      );
      if (_closed || token != _token) return;
      result = r;
      text.text = r.text;
      _set(OcrState.done);
    } on Cancelled {
      if (!_closed && token == _token) {
        _set(result == null ? OcrState.chooseLanguage : OcrState.done);
      }
    } catch (e) {
      if (_closed || token != _token) return;
      error = e;
      _set(
        e is OcrUnavailable && e.problem == OcrProblem.languageMissing
            ? OcrState.chooseLanguage
            : OcrState.failed,
      );
    }
  }

  void cancel() => _token?.cancel();

  String get base {
    final name = source.label.replaceAll(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '');
    return safeFilename(name.isEmpty ? 'text' : name);
  }

  /// The edited words as a file: `.txt`, or `.md` with nothing escaped.
  (String, Uint8List, String) file(String kind) => (
    '$base.$kind',
    kind == 'docx'
        ? docxFromText(text.text, title: base)
        : Uint8List.fromList(utf8.encode(text.text)),
    switch (kind) {
      'md' => 'text/markdown',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'text/plain',
    },
  );

  void _set(OcrState next) {
    if (_closed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _token?.cancel();
    text.dispose();
    super.dispose();
  }
}
