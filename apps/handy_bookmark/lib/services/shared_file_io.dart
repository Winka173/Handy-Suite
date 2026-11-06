import 'dart:io';
import 'dart:typed_data';

/// Reads a picture the native share queue copied into app-private storage.
Future<Uint8List> readSharedFile(String path) => File(path).readAsBytes();
