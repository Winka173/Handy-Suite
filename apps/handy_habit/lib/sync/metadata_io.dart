import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'metadata_stub.dart';
export 'metadata_stub.dart' show SyncMetadataStore, MemorySyncMetadata;

class FileSyncMetadata implements SyncMetadataStore {
  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/habit-drive-device.json',
  );
  @override
  Future<Map<String, dynamic>> read() async {
    final file = await _file();
    if (!await file.exists()) return {};
    // Damaged metadata refuses auto-sync. It must not silently select a new
    // account/base or overwrite the evidence needed for recovery.
    return Map<String, dynamic>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final file = await _file(), part = File('${(await _file()).path}.part');
    await file.parent.create(recursive: true);
    await part.writeAsString(jsonEncode(data), flush: true);
    await part.rename(file.path);
  }
}
