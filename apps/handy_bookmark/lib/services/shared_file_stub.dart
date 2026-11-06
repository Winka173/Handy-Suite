import 'dart:typed_data';

/// The web never receives picture files from the share queue.
Future<Uint8List> readSharedFile(String path) =>
    throw UnsupportedError('No shared files on this platform');
