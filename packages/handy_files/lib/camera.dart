import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:image_picker/image_picker.dart';

abstract interface class ScanCamera {
  bool get supported;
  Future<ImportedBytes?> capture();
  Future<ImportedBytes?> recover();
}

class SystemScanCamera implements ScanCamera {
  final ImagePicker _picker = ImagePicker();
  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Future<ImportedBytes> _read(XFile file) async {
    if (await file.length() > 12000000)
      throw const FormatException('Camera image exceeds 12 MB');
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (buffer.length + chunk.length > 12000000)
        throw const FormatException('Camera image exceeds 12 MB');
      buffer.add(chunk);
    }
    return ImportedBytes(file.name, buffer.takeBytes());
  }

  @override
  Future<ImportedBytes?> capture() async {
    if (!supported) throw UnsupportedError('Use image import on this platform');
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return file == null ? null : _read(file);
  }

  @override
  Future<ImportedBytes?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null)
      throw const FormatException(
        'Camera capture could not be recovered. Existing pages were preserved.',
      );
    final files = response.files;
    return files == null || files.isEmpty ? null : _read(files.first);
  }
}
