import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:handy_core/handy_core.dart';
import 'src/verify_stub.dart' if (dart.library.io) 'src/verify_io.dart';

Future<String> readTextStream(
  Stream<List<int>> stream, {
  int maxBytes = 1000000,
  CancellationToken? cancellation,
}) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    cancellation?.check();
    if (builder.length + chunk.length > maxBytes)
      throw const FormatException('File exceeds import size limit');
    builder.add(chunk);
  }
  cancellation?.check();
  return decodeUtf8(builder.takeBytes(), maxBytes: maxBytes);
}

class ImportedText {
  final String name, text;
  const ImportedText(this.name, this.text);
}

class ImportedBytes {
  final String name;
  final Uint8List bytes;
  const ImportedBytes(this.name, this.bytes);
}

abstract interface class HandyFiles {
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  });
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  });
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  });

  /// null means user canceled. Browser completion means download dispatch, not verified disk persistence.
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  });
}

abstract interface class BatchHandyFiles {
  Future<List<ImportedBytes>> importManyBytes({
    required List<String> extensions,
    int maxFiles = 50,
    int maxEachBytes = 20000000,
    int maxTotalBytes = 60000000,
    CancellationToken? cancellation,
  });
}

class SystemHandyFiles implements HandyFiles, BatchHandyFiles {
  const SystemHandyFiles();
  @override
  Future<List<ImportedBytes>> importManyBytes({
    required List<String> extensions,
    int maxFiles = 50,
    int maxEachBytes = 20000000,
    int maxTotalBytes = 60000000,
    CancellationToken? cancellation,
  }) async {
    if (maxFiles < 1 ||
        maxFiles > 100 ||
        maxEachBytes < 1 ||
        maxEachBytes > 30000000 ||
        maxTotalBytes < 1 ||
        maxTotalBytes > 60000000)
      throw ArgumentError('Invalid batch import limits');
    cancellation?.check();
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    cancellation?.check();
    if (picked.length > maxFiles)
      throw const FormatException(
        'Too many files selected; existing data was preserved',
      );
    final result = <ImportedBytes>[];
    var total = 0;
    for (final file in picked) {
      cancellation?.check();
      final length = await file.length();
      if (length != null &&
          (length > maxEachBytes || total + length > maxTotalBytes))
        throw const FormatException('Selected files exceed batch size limits');
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        cancellation?.check();
        if (bytes.length + chunk.length > maxEachBytes ||
            total + bytes.length + chunk.length > maxTotalBytes)
          throw const FormatException(
            'Selected files exceed batch size limits',
          );
        bytes.add(chunk);
      }
      total += bytes.length;
      result.add(ImportedBytes(file.name, bytes.takeBytes()));
    }
    cancellation?.check();
    return result;
  }

  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    cancellation?.check();
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > maxBytes)
      throw const FormatException('File exceeds import size limit');
    final builder = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      cancellation?.check();
      if (builder.length + chunk.length > maxBytes)
        throw const FormatException('File exceeds import size limit');
      builder.add(chunk);
    }
    cancellation?.check();
    return ImportedBytes(file.name, builder.takeBytes());
  }

  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    if (bytes.length > 30000000)
      throw const FormatException('Export exceeds 30 MB');
    final result = await FilePicker.saveFile(
      dialogTitle: 'Export / Xuất file',
      fileName: safeFilename(name),
      bytes: bytes,
      mimeType: mimeType,
    );
    if (result != null) await verifySavedFile(result, bytes);
    cancellation?.check();
    return result?.toString();
  }

  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'txt',
        'md',
        'json',
        'csv',
        'yaml',
        'yml',
        'xml',
        'toml',
        'srt',
        'vtt',
      ],
    );
    cancellation?.check();
    if (file == null) return null;
    final length = await file.length();
    if (length != null && length > maxBytes)
      throw const FormatException('File exceeds import size limit');
    return ImportedText(
      file.name,
      await readTextStream(
        file.readAsByteStream(),
        maxBytes: maxBytes,
        cancellation: cancellation,
      ),
    );
  }

  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    cancellation?.check();
    final bytes = Uint8List.fromList(utf8.encode(text));
    if (bytes.length > 1000000)
      throw const FormatException('Text export exceeds 1 MB');
    if (decodeUtf8(bytes) != text.replaceFirst(RegExp('^\ufeff'), ''))
      throw const FormatException('Output UTF-8 verification failed');
    return exportBytes(
      name,
      bytes,
      mimeType: name.endsWith('.json') ? 'application/json' : 'text/plain',
      cancellation: cancellation,
    );
  }
}
