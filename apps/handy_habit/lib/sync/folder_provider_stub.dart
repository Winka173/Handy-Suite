import 'dart:typed_data';
import 'package:handy_habit_engine/handy_habit_engine.dart';

class FolderSyncProvider implements HabitSyncProvider {
  FolderSyncProvider(String path);
  @override
  Future<Uint8List?> read(String path) async =>
      throw UnsupportedError('Folder sync');
  @override
  Future<void> put(String path, Uint8List bytes) async =>
      throw UnsupportedError('Folder sync');
  @override
  Future<Set<String>> list(String folder) async =>
      throw UnsupportedError('Folder sync');
}
