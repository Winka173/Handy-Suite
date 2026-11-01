import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

/// Reads one dropped statement, refusing other kinds and anything over
/// 12 MB while it streams.
Future<ImportedBytes> readDroppedStatement(DropItem file) async {
  if (file is! DropItemFile ||
      ![
        'csv',
        'txt',
        'xlsx',
        'json',
      ].any((e) => file.name.toLowerCase().endsWith('.$e')))
    throw const FormatException(
      'Choose a statement file / Hãy chọn file sao kê',
    );
  if (await file.length() > 12000000)
    throw const FormatException('File exceeds 12MB / File vượt 12MB');
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in file.openRead()) {
    if (bytes.length + chunk.length > 12000000)
      throw const FormatException('File exceeds 12MB / File vượt 12MB');
    bytes.add(chunk);
  }
  return ImportedBytes(file.name, bytes.takeBytes());
}

/// Isolate entry: the file's cells.
List<List<String>> parseStatement(Map<String, dynamic> input) {
  final bytes = input['bytes'] as Uint8List,
      extension = input['extension'] as String;
  if (extension == 'xlsx') return xlsxParse(bytes);
  return csvParse(
    decodeStatement(bytes, encoding: input['encoding'] as String),
    delimiter: input['delimiter'] as String,
  );
}

/// Isolate entry: the rows checked against the ledger.
StatementPreview validateStatement(Map<String, dynamic> input) =>
    previewStatement(
      SpendState.fromJson(Map<String, dynamic>.from(input['state'] as Map)),
      List<List<String>>.from(
        (input['rows'] as List).map((e) => List<String>.from(e as List)),
      ),
      StatementMapping.fromJson(
        Map<String, dynamic>.from(input['mapping'] as Map),
      ),
      input['bytes'] as Uint8List,
    );
