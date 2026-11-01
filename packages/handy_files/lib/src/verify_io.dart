import 'dart:io';
import 'dart:typed_data';

Future<bool> verifySavedFile(Uri uri, Uint8List expected) async {
  if (uri.scheme != 'file') return false;
  final file = File.fromUri(uri);
  if (await file.length() != expected.length)
    throw const FileSystemException('Export size verification failed');
  var at = 0;
  await for (final bytes in file.openRead()) {
    for (final value in bytes) {
      if (at >= expected.length || value != expected[at++])
        throw const FileSystemException('Export content verification failed');
    }
  }
  if (at != expected.length)
    throw const FileSystemException('Export readback interrupted');
  return true;
}
