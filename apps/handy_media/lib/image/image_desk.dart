import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import '../text_watermark.dart';

const imageTools = ['crop', 'resize', 'convert', 'watermark', 'metadata'];

/// The pictures open for a quick fix, the fix being set up and what it
/// made. The pictures are copies; nothing here touches the originals.
class ImageDesk extends ChangeNotifier {
  static const maxFiles = 50, maxBytes = 60000000;

  final sources = <ImportedBytes>[], outputs = <ImportedBytes>[];
  int selected = 0;
  String tool;
  ImageDesk({this.tool = 'crop'});

  // The chosen picture.
  Uint8List? preview;
  ImageMetadata? metadata;
  double ratio = 1;
  int width = 1, height = 1;

  // Settings.
  ImageRegion region = const ImageRegion(x: .1, y: .1, width: .8, height: .8);
  final size = TextEditingController(text: '1200');
  final words = TextEditingController(text: 'Handy');
  String format = 'jpeg', position = 'bottom-right';
  int rotation = 0;
  bool flipX = false, flipY = false, useLogo = false;
  double quality = 85, opacity = .6, scale = .3;
  Uint8List? logo;

  /// One line per picture of the last batch: ready, or why not.
  final status = <String>[];
  int failed = 0;

  int get bytes => sources.fold<int>(0, (n, f) => n + f.bytes.length);
  bool get batch => tool == 'convert' || tool == 'watermark';
  ImportedBytes? get chosen => sources.isEmpty ? null : sources[selected];

  void set(VoidCallback change) {
    change();
    outputs.clear();
    status.clear();
    notifyListeners();
  }

  void pick(String next) => set(() => tool = next);

  /// Adds pictures after checking every one; one bad picture adds none.
  void accept(List<ImportedBytes> files, {CancellationToken? token}) {
    if (files.isEmpty) return;
    if (sources.length + files.length > maxFiles ||
        bytes + files.fold<int>(0, (n, f) => n + f.bytes.length) > maxBytes) {
      throw const FormatException('Batch limit: 50 files / 60 MB');
    }
    for (final f in files) {
      token?.check();
      decodeBoundedImage(f.bytes, allowWebP: true);
    }
    sources.addAll(
      files.map((f) => ImportedBytes(f.name, Uint8List.fromList(f.bytes))),
    );
    choose(sources.length - 1);
  }

  void choose(int i) {
    final b = sources[i].bytes, d = decodeBoundedImage(b, allowWebP: true);
    selected = i;
    preview = mediaPng(mediaBitmap(b));
    ratio = d.width / d.height;
    width = d.width;
    height = d.height;
    metadata = b.length >= 12 && String.fromCharCodes(b.take(4)) == 'RIFF'
        ? null
        : inspectImageMetadata(b);
    region = const ImageRegion(x: .1, y: .1, width: .8, height: .8);
    outputs.clear();
    status.clear();
    notifyListeners();
  }

  void remove(int i) {
    sources.removeAt(i);
    outputs.clear();
    status.clear();
    if (sources.isEmpty) {
      preview = metadata = null;
      selected = 0;
      notifyListeners();
    } else {
      choose(i.clamp(0, sources.length - 1));
    }
  }

  /// Runs the fix: on the chosen picture, or on all of them for a batch.
  Future<void> apply(CancellationToken token) async {
    outputs.clear();
    status.clear();
    failed = 0;
    notifyListeners();
    final made = switch (tool) {
      'convert' => await _convert(token),
      'watermark' => await _stamp(token),
      _ => [await _one(token)],
    };
    token.check();
    outputs.addAll(made);
    notifyListeners();
  }

  Future<ImportedBytes> _one(CancellationToken token) async {
    final source = chosen!.bytes;
    final out = switch (tool) {
      'crop' => await cropImage(source, region, cancellation: token),
      'resize' => await resizeImage(
        source,
        width: int.tryParse(size.text) ?? 0,
        cancellation: token,
      ),
      'metadata' => stripImageMetadata(source),
      _ => throw const FormatException('Unknown image action'),
    };
    final jpeg = tool == 'metadata' && metadata?.format == 'JPEG';
    return ImportedBytes(jpeg ? 'clean-image.jpg' : '$tool-image.png', out);
  }

  Future<List<ImportedBytes>> _convert(CancellationToken token) async {
    final made = <ImportedBytes>[];
    var total = 0;
    for (final (i, f) in sources.indexed) {
      token.check();
      try {
        final out = await convertImage(
          f.bytes,
          format: format,
          width: size.text.trim().isEmpty ? null : int.tryParse(size.text) ?? 0,
          rotation: rotation,
          flipHorizontal: flipX,
          flipVertical: flipY,
          quality: quality.round(),
          cancellation: token,
        );
        total += out.length;
        if (total > maxBytes) {
          throw const FormatException(
            'Batch output exceeds 60 MB; split the batch',
          );
        }
        made.add(
          ImportedBytes(
            'converted-${i + 1}.${format == 'jpeg' ? 'jpg' : format}',
            out,
          ),
        );
        status.add('${f.name}: ok');
      } on Cancelled {
        rethrow;
      } on FormatException catch (e) {
        failed++;
        status.add('${f.name}: ${e.message}');
      }
      notifyListeners();
    }
    return made;
  }

  Future<List<ImportedBytes>> _stamp(CancellationToken token) async {
    final text = words.text;
    final spec = useLogo
        ? WatermarkSpec.logo(
            logo ?? (throw const FormatException('Import a logo first')),
            opacity: opacity,
            position: position,
            relativeWidth: scale,
          )
        : text.runes.every((r) => r >= 32 && r <= 126)
        ? WatermarkSpec.text(
            text,
            opacity: opacity,
            position: position,
            relativeWidth: scale,
          )
        // Vietnamese and other letters are drawn with the app's fonts.
        : WatermarkSpec.logo(
            await renderTextWatermark(text, cancellation: token),
            opacity: opacity,
            position: position,
            relativeWidth: scale,
          );
    final result = await watermarkBatch(
      [for (final f in sources) f.bytes],
      spec,
      cancellation: token,
    );
    final made = <ImportedBytes>[];
    for (final r in result) {
      final name = sources[r.index].name;
      if (r.bytes != null) {
        made.add(ImportedBytes('watermark-${r.index + 1}.png', r.bytes!));
        status.add('$name: ok');
      } else {
        failed++;
        status.add('$name: ${r.error}');
      }
    }
    return made;
  }

  String get fileName => outputs.length == 1
      ? outputs.single.name
      : tool == 'watermark'
      ? 'handy-media-watermarks.zip'
      : 'handy-media-converted.zip';

  String get fileMime => outputs.length != 1
      ? 'application/zip'
      : fileName.endsWith('.jpg')
      ? 'image/jpeg'
      : fileName.endsWith('.webp')
      ? 'image/webp'
      : 'image/png';

  /// One file, or every output in a ZIP (stored, not compressed).
  ({String name, Uint8List bytes, String mime}) file() {
    if (outputs.length == 1) {
      return (name: fileName, bytes: outputs.single.bytes, mime: fileMime);
    }
    final archive = Archive();
    for (final o in outputs) {
      archive.addFile(ArchiveFile(o.name, o.bytes.length, o.bytes));
    }
    return (
      name: fileName,
      bytes: Uint8List.fromList(ZipEncoder().encodeBytes(archive, level: 0)),
      mime: fileMime,
    );
  }

  @override
  void dispose() {
    size.dispose();
    words.dispose();
    super.dispose();
  }
}
