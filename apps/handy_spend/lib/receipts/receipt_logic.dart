import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

/// A receipt chosen in the entry sheet but not saved yet: its checked
/// description and its bytes, held in memory until Save.
class PendingReceipt {
  final Receipt receipt;
  final Uint8List bytes;
  const PendingReceipt(this.receipt, this.bytes);
}

/// Checks picked files for [entry] against the type, the 10 MB file limit,
/// ten per transaction and 50 MB in all, counting what is already kept
/// (less what is about to be removed) and what is waiting to be saved. All
/// or nothing: one bad file refuses the whole pick.
List<PendingReceipt> checkReceipts(
  SpendState s,
  String entry,
  List<ImportedBytes> files, {
  List<PendingReceipt> waiting = const [],
  Set<String> removing = const {},
}) {
  final kept = s.receipts.where((r) => !removing.contains(r.id)).toList();
  final count =
      kept.where((r) => r.entry == entry).length +
      waiting.length +
      files.length;
  if (count > receiptsPerEntry)
    throw const FormatException(
      'At most 10 receipts per transaction / Tối đa 10 hóa đơn mỗi giao dịch',
    );
  final out = [
    for (final f in files)
      PendingReceipt(Receipt.of(entry, f.name, f.bytes), f.bytes),
  ];
  final total = [
    ...kept.map((r) => r.size),
    ...waiting.map((p) => p.receipt.size),
    ...out.map((p) => p.receipt.size),
  ].fold(0, (int n, v) => n + v);
  if (total > receiptTotalLimit)
    throw const FormatException(
      'Receipts are limited to 50 MB in all; remove some first / Hóa đơn tối đa 50 MB tổng cộng; hãy bỏ bớt',
    );
  if (s.receipts.length - removing.length + waiting.length + out.length >
      receiptCountLimit)
    throw const FormatException('At most 1000 receipts / Tối đa 1000 hóa đơn');
  return out;
}

/// A size people read: 412 KB, 1,2 MB.
String fileSize(int bytes, {required bool vi}) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000000) return '${(bytes / 1000).round()} KB';
  final mb = (bytes / 1000000).toStringAsFixed(1);
  return '${vi ? mb.replaceAll('.', ',') : mb} MB';
}

/// Room left for receipts, in bytes.
int receiptRoom(SpendState s) =>
    receiptTotalLimit - s.receipts.fold(0, (int n, r) => n + r.size);
