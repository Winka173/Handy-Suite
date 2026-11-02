import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_storage/documents.dart';

/// A signature kept on this device to sign again: a PNG with a clear
/// background, never sent anywhere.
class SavedSignature {
  final String id, createdAt;
  final Uint8List _png;
  Uint8List get png => Uint8List.fromList(_png);
  SavedSignature(this.id, Uint8List png, this.createdAt)
    : _png = Uint8List.fromList(png);
}

/// The saved signatures, at most [max], each a PNG up to [maxBytes].
class SignatureBook {
  static const max = 6, maxBytes = 500000;
  final List<SavedSignature> signatures;
  SignatureBook(Iterable<SavedSignature> input)
    : signatures = List.unmodifiable(input) {
    if (signatures.length > max ||
        signatures.map((s) => s.id).toSet().length != signatures.length) {
      throw const FormatException('Keep up to 6 signatures');
    }
    for (final s in signatures) {
      if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(s.id) ||
          DateTime.tryParse(s.createdAt) == null ||
          !s.createdAt.endsWith('Z')) {
        throw const FormatException('Invalid signature');
      }
      checkSignaturePng(s._png);
    }
  }

  String serialize() => jsonEncode({
    'format': 'handy-docs-signatures',
    'version': 1,
    'signatures': [
      for (final s in signatures)
        {'id': s.id, 'createdAt': s.createdAt, 'png': base64Encode(s._png)},
    ],
  });

  factory SignatureBook.parse(String text) {
    if (text.length > 4000000) {
      throw const FormatException('Signature file exceeds 4 MB');
    }
    final raw = jsonDecode(text);
    if (raw is! Map ||
        raw['format'] != 'handy-docs-signatures' ||
        raw['version'] != 1 ||
        raw['signatures'] is! List) {
      throw const FormatException('Unsupported signature file');
    }
    return SignatureBook([
      for (final s in raw['signatures'] as List)
        if (s is Map &&
            s['id'] is String &&
            s['createdAt'] is String &&
            s['png'] is String)
          SavedSignature(s['id'], _decode(s['png']), s['createdAt'])
        else
          throw const FormatException('Invalid signature'),
    ]);
  }

  static Uint8List _decode(String data) {
    final bytes = base64Decode(data);
    if (base64Encode(bytes) != data) {
      throw const FormatException('Invalid signature encoding');
    }
    return bytes;
  }
}

/// A PNG (by its signature bytes) no larger than [SignatureBook.maxBytes].
void checkSignaturePng(Uint8List png) {
  const magic = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (png.length < 8 ||
      png.length > SignatureBook.maxBytes ||
      [for (var i = 0; i < 8; i++) png[i] == magic[i]].contains(false)) {
    throw const FormatException('A signature is a PNG picture up to 500 KB');
  }
}

/// The signatures on this device. Every change is written first and shown
/// after; a failed write keeps the list as it was.
class SignatureStore extends ChangeNotifier {
  final DocumentRepository documents;
  SignatureStore(this.documents);

  SignatureBook book = SignatureBook(const []);
  bool loaded = false;
  Object? error;
  bool _closed = false;

  List<SavedSignature> get signatures => book.signatures;
  bool get full => signatures.length >= SignatureBook.max;

  Future<void> load() async {
    error = null;
    try {
      final raw = await documents.load();
      book = raw == null ? SignatureBook(const []) : SignatureBook.parse(raw);
      loaded = true;
    } catch (e) {
      // A damaged file is reported and never replaced by an empty list.
      error = e;
    }
    notifyListeners();
  }

  Future<void> _commit(SignatureBook next) async {
    if (!loaded) throw StateError('Signatures are not loaded');
    await documents.save(next.serialize());
    book = next;
    notifyListeners();
  }

  /// Keeps [png] as the newest signature and returns it.
  Future<SavedSignature> add(Uint8List png) async {
    if (full) {
      throw const FormatException(
        'Up to 6 signatures are kept; delete one first',
      );
    }
    final s = SavedSignature(
      'sig-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
      png,
      DateTime.now().toUtc().toIso8601String(),
    );
    await _commit(SignatureBook([s, ...signatures]));
    return s;
  }

  Future<void> remove(String id) =>
      _commit(SignatureBook(signatures.where((s) => s.id != id)));

  @override
  void notifyListeners() {
    if (!_closed) super.notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
