abstract interface class SyncMetadataStore {
  Future<Map<String, dynamic>> read();
  Future<void> write(Map<String, dynamic> data);
}

class MemorySyncMetadata implements SyncMetadataStore {
  Map<String, dynamic> data = {};
  @override
  Future<Map<String, dynamic>> read() async => {...data};
  @override
  Future<void> write(Map<String, dynamic> value) async {
    data = {...value};
  }
}

class FileSyncMetadata extends MemorySyncMetadata {}
