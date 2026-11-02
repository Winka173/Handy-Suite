import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';

PreparedAsset _prepare((String, Uint8List) input) =>
    prepareAsset(input.$1, input.$2);
Future<PreparedAsset> prepareImported(ImportedBytes file) =>
    compute(_prepare, (file.name, file.bytes));

class TripCamera {
  final ImagePicker _picker = ImagePicker();
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<ImportedBytes> read(XFile f) async {
    if (await f.length() > 12000000)
      throw const FormatException(
        'Photo exceeds 12 MB; source remains untouched',
      );
    final buffer = BytesBuilder(copy: false);
    await for (final b in f.openRead()) {
      if (buffer.length + b.length > 12000000)
        throw const FormatException('Photo exceeds 12 MB');
      buffer.add(b);
    }
    return ImportedBytes(f.name, buffer.takeBytes());
  }

  Future<ImportedBytes?> capture() async {
    if (!supported) throw UnsupportedError('Import a photo on this platform');
    // No imageQuality/maxWidth: preserve the selected camera original.
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: false,
    );
    return file == null ? null : read(file);
  }

  Future<List<ImportedBytes>> gallery() async {
    final files = await _picker.pickMultiImage(requestFullMetadata: false);
    final result = <ImportedBytes>[];
    var size = 0;
    for (final f in files) {
      final file = await read(f);
      size += file.bytes.length;
      if (size > 30000000)
        throw const FormatException(
          'Select at most 30 MB per import; gallery originals preserved',
        );
      result.add(file);
    }
    return result;
  }

  Future<ImportedBytes?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final result = await _picker.retrieveLostData();
    if (result.exception != null)
      throw const FormatException(
        'Camera recovery failed; gallery originals preserved',
      );
    return result.files == null || result.files!.isEmpty
        ? null
        : read(result.files!.first);
  }
}
