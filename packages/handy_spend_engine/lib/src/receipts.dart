part of '../handy_spend_engine.dart';

/// Receipt files kept with a transaction. The bytes live in the app's own
/// storage (a SQLite table natively, an IndexedDB store on the web); the
/// ledger holds only this description, so the ledger JSON stays small.
const receiptMimes = {
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
};

/// One file at most 10 MB, all receipts together at most 50 MB, at most
/// ten per transaction and 1000 in all. The ZIP backup carries every one,
/// so its budget is the 30 MB ledger plus these 50 MB.
const receiptFileLimit = 10000000;
const receiptTotalLimit = 50000000;
const receiptsPerEntry = 10;
const receiptCountLimit = 1000;

/// The file type from its first bytes. The name and the picker's type are
/// never trusted: a renamed file is refused here.
String receiptMime(Uint8List b) {
  bool at(int offset, List<int> sig) =>
      b.length >= offset + sig.length &&
      [
        for (var i = 0; i < sig.length; i++) b[offset + i] == sig[i],
      ].every((v) => v);
  if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    return 'image/png';
  if (at(0, ascii.encode('RIFF')) && at(8, ascii.encode('WEBP')))
    return 'image/webp';
  if (at(0, ascii.encode('%PDF-'))) return 'application/pdf';
  throw const FormatException(
    'Only JPEG, PNG, WebP or PDF receipts / Chỉ nhận ảnh JPEG, PNG, WebP hoặc PDF',
  );
}

class Receipt {
  final String id, entry, name, mime, sha, added;
  final int size;
  Receipt({
    required this.id,
    required this.entry,
    required this.name,
    required this.mime,
    required this.size,
    required this.sha,
    required String added,
  }) : added = timestamp(added) {
    if (id.isEmpty ||
        id.length > 64 ||
        entry.isEmpty ||
        name.trim().isEmpty ||
        name.length > 256 ||
        !receiptMimes.contains(mime) ||
        size < 1 ||
        size > receiptFileLimit ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha))
      throw const FormatException('Invalid receipt');
  }

  /// A checked receipt for [bytes]: its real type, size and checksum.
  factory Receipt.of(String entry, String name, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > receiptFileLimit)
      throw const FormatException(
        'A receipt file is at most 10 MB / Mỗi file hóa đơn tối đa 10 MB',
      );
    final mime = receiptMime(bytes);
    var clean = name.split(RegExp(r'[/\\]')).last.trim();
    if (clean.isEmpty) clean = 'receipt';
    if (clean.length > 120) clean = clean.substring(clean.length - 120);
    return Receipt(
      id: newId(),
      entry: entry,
      name: clean,
      mime: mime,
      size: bytes.length,
      sha: sha256.convert(bytes).toString(),
      added: DateTime.now().toUtc().toIso8601String(),
    );
  }

  bool get image => mime.startsWith('image/');

  /// Bytes that match this receipt exactly.
  bool matches(Uint8List bytes) =>
      bytes.length == size &&
      sha256.convert(bytes).toString() == sha &&
      receiptMime(bytes) == mime;

  Map<String, dynamic> toJson() => {
    'id': id,
    'entry': entry,
    'name': name,
    'mime': mime,
    'size': size,
    'sha': sha,
    'added': added,
  };
  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
    id: _text(j['id']),
    entry: _text(j['entry']),
    name: _text(j['name']),
    mime: _text(j['mime']),
    size: j['size'] as int,
    sha: _text(j['sha']),
    added: _text(j['added']),
  );
}

/// [s] with [add] attached, after checking the per-transaction, count and
/// total budgets against what is already kept.
SpendState attachReceipts(SpendState s, List<Receipt> add) {
  final next = s.copy({
    'receipts': [
      ...s.receipts.map((r) => r.toJson()),
      ...add.map((r) => r.toJson()),
    ],
  });
  return next;
}
