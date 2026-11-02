import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';

/// The PDFs open on the PDF screen. Nothing here is saved: the files are
/// copies in memory, the originals are never written, and a new PDF exists
/// only until the person saves it.
class PdfDesk extends ChangeNotifier {
  static const maxFiles = 20, maxBytes = 30000000;

  final inputs = <ImportedBytes>[];
  LocalPdf? document;
  int selected = 0, page = 0;
  Uint8List? preview;

  /// The PDF just made, and what it was made from, until it is saved.
  Uint8List? output;
  String outputNote = '';

  /// With a both-sides job, [output] holds the fronts and this the backs.
  Uint8List? backs;
  DuplexPlan? plan;

  /// For a smaller copy: the original's size in bytes.
  int before = 0;

  bool _closed = false;
  Future<void>? _pending;

  int get pages => document?.pages.length ?? 0;

  /// Runs one PDFium job at a time; closing waits for it.
  Future<T> _job<T>(Future<T> Function() task) async {
    final previous = _pending;
    final done = Completer<void>();
    _pending = done.future;
    try {
      await previous;
      return await task();
    } finally {
      done.complete();
    }
  }

  Future<void> add(ImportedBytes file, CancellationToken token) =>
      _job(() async {
        if (inputs.length >= maxFiles ||
            inputs.fold<int>(0, (n, f) => n + f.bytes.length) +
                    file.bytes.length >
                maxBytes) {
          throw const FormatException('PDF limit: 20 files / 30 MB total');
        }
        inputs.add(ImportedBytes(file.name, Uint8List.fromList(file.bytes)));
        try {
          await _open(inputs.length - 1, token);
        } catch (_) {
          inputs.removeLast();
          rethrow;
        }
      });

  Future<void> select(int index, CancellationToken token) =>
      _job(() => _open(index, token));

  Future<void> _open(int index, CancellationToken token) async {
    final next = await LocalPdf.open(inputs[index].bytes, cancellation: token);
    try {
      final png = await next.renderPng(0, cancellation: token);
      token.check();
      if (_closed) {
        await next.close();
        return;
      }
      final old = document;
      document = next;
      selected = index;
      page = 0;
      preview = png;
      output = backs = null;
      notifyListeners();
      await old?.close();
    } catch (_) {
      await next.close();
      rethrow;
    }
  }

  /// Takes a file off the desk; its original was never touched.
  Future<void> remove(int index, CancellationToken token) => _job(() async {
    inputs.removeAt(index);
    output = backs = null;
    if (inputs.isEmpty) {
      final old = document;
      document = null;
      preview = null;
      notifyListeners();
      await old?.close();
      return;
    }
    if (index == selected || selected >= inputs.length) {
      await _open(index.clamp(0, inputs.length - 1), token);
    } else {
      if (index < selected) selected--;
      notifyListeners();
    }
  });

  Future<void> turn(int to, CancellationToken token) => _job(() async {
    final png = await document!.renderPng(to, cancellation: token);
    page = to;
    preview = png;
    notifyListeners();
  });

  /// A new PDF from the open file's pages in [range] (all when blank),
  /// turned and stamped. Checked by PDFium before it is offered.
  Future<void> make(
    String range,
    int rotation,
    String watermark,
    CancellationToken token,
  ) => _job(() async {
    output = backs = null;
    notifyListeners();
    final indices = range.trim().isEmpty
        ? [for (var i = 0; i < pages; i++) i]
        : pageRange(range, pages);
    backs = null;
    output = await document!.transform(
      indices,
      rotation: rotation,
      watermark: watermark,
      cancellation: token,
    );
    outputNote = '${indices.length}';
    notifyListeners();
  });

  /// Two PDFs for printing both sides by hand: the fronts, then the backs
  /// in the order that lands each on its front once the stack is turned.
  Future<void> duplex(CancellationToken token) => _job(() async {
    output = backs = null;
    notifyListeners();
    final p = duplexPlan(pages);
    final fronts = await document!.transform(p.fronts, cancellation: token);
    backs = await document!.transform(p.backs, cancellation: token);
    output = fronts;
    plan = p;
    outputNote = 'duplex';
    notifyListeners();
  });

  /// A copy with page numbers at the foot of each page.
  Future<void> number({
    required int start,
    required bool skipFirst,
    required bool right,
    required CancellationToken token,
  }) => _job(() async {
    output = backs = null;
    notifyListeners();
    final box = right
        ? const PdfBox(.82, .945, .12, .026)
        : const PdfBox(.44, .945, .12, .026);
    output = await document!.flatten([
      for (var i = 0; i < pages; i++)
        if (pageNumberFor(i, start: start, skipFirst: skipFirst) case final n?)
          PdfTextStamp(i, box, '$n', color: 0xFF333333),
    ], cancellation: token);
    outputNote = 'numbered';
    notifyListeners();
  });

  /// Every open file, in the order added, as one PDF.
  Future<void> merge(CancellationToken token) => _job(() async {
    output = backs = null;
    notifyListeners();
    output = await LocalPdf.merge([
      for (final f in inputs) f.bytes,
    ], cancellation: token);
    outputNote = 'merge';
    notifyListeners();
  });

  /// A smaller copy of the open file. [strong] turns every page into a
  /// picture (text is no longer selectable); otherwise only pictures are
  /// re-encoded. A copy that is not smaller is refused.
  Future<void> compress(bool strong, CancellationToken token) => _job(() async {
    output = backs = null;
    notifyListeners();
    final source = inputs[selected];
    final smaller = strong
        ? await document!.rasterize(cancellation: token)
        : await document!.compress(cancellation: token);
    if (smaller.bytes.length >= source.bytes.length) {
      throw FormatException(
        strong
            ? 'This PDF is already as small as a picture copy would be'
            : 'This PDF could not be made smaller this way; try strong compression',
      );
    }
    output = smaller.bytes;
    outputNote = strong ? 'strong' : 'smaller';
    before = source.bytes.length;
    notifyListeners();
  });

  /// The file name to offer when the new PDF is saved.
  String get outputName {
    if (inputs.isEmpty) return 'handy-document.pdf';
    final name = inputs[selected].name;
    final base = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    return switch (outputNote) {
      'smaller' || 'strong' => '$base-smaller.pdf',
      'merge' => 'handy-merged.pdf',
      'numbered' => '$base-numbered.pdf',
      _ => 'handy-document.pdf',
    };
  }

  /// The file names of a both-sides job, in the reader's language: side 1
  /// is the fronts, side 2 the backs.
  String duplexName(int side, {required bool vi}) {
    final name = inputs.isEmpty ? 'handy-document' : inputs[selected].name;
    final base = name.toLowerCase().endsWith('.pdf')
        ? name.substring(0, name.length - 4)
        : name;
    final part = side == 1
        ? (vi ? 'mặt trước' : 'fronts')
        : (vi ? 'mặt sau' : 'backs');
    return '$base - $side $part.pdf';
  }

  void dropOutput() {
    if (output == null) return;
    output = backs = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(
      (_pending ?? Future.value()).whenComplete(() => document?.close()),
    );
    super.dispose();
  }
}
