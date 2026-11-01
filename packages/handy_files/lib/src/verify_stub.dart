import 'dart:typed_data';

/// Browsers/provider URIs cannot be reopened as arbitrary paths. Never claim disk verification.
Future<bool> verifySavedFile(Uri uri, Uint8List expected) async => false;
