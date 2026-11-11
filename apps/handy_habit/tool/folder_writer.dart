import 'dart:typed_data';
import '../lib/sync/folder_provider_io.dart';

Future<void> main(List<String> args) async {
  await FolderSyncProvider(
    args.first,
  ).put('handy-habit/commits/same-123.json', Uint8List.fromList([1, 2, 3]));
}
