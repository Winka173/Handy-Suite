import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';
import '../inventory/keep_store.dart' show newId;

const attachmentBytes = 4000000;

/// The local file name and type of an attachment, judged by its first bytes,
/// never by its name. Null when it is not a PNG, a JPEG or (for receipts) a
/// complete PDF.
({String uri, String mime})? sniffAttachment(
  Uint8List b, {
  bool receipt = false,
}) {
  const pngHead = [137, 80, 78, 71, 13, 10, 26, 10];
  final png =
      b.length >= 8 &&
      pngHead.asMap().entries.every((e) => b[e.key] == e.value);
  final jpg = b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255;
  final pdf =
      receipt &&
      b.length > 8 &&
      utf8.decode(b.take(5).toList(), allowMalformed: true) == '%PDF-' &&
      utf8
          .decode(
            b.skip((b.length - 1024).clamp(0, b.length)).toList(),
            allowMalformed: true,
          )
          .contains('%%EOF');
  if (!png && !jpg && !pdf) return null;
  final ext = png ? 'png' : (jpg ? 'jpg' : 'pdf');
  return (
    uri: 'file:///handy-assets/${newId()}.$ext',
    mime: png ? 'image/png' : (jpg ? 'image/jpeg' : 'application/pdf'),
  );
}

/// Checks an incoming file and returns its local URI, or throws in words.
String acceptAttachment(Uint8List bytes, {bool receipt = false}) {
  if (bytes.length > attachmentBytes) {
    throw const FormatException('Files up to 4 MB / Tệp tối đa 4 MB');
  }
  final kind = sniffAttachment(bytes, receipt: receipt);
  if (kind == null) {
    throw FormatException(
      receipt
          ? 'Use a PNG, JPEG or PDF / Dùng ảnh PNG, JPEG hoặc PDF'
          : 'Use a PNG or JPEG photo / Dùng ảnh PNG hoặc JPEG',
    );
  }
  return kind.uri;
}

InventoryReceipt receiptFor(String name, String uri) => InventoryReceipt(
  id: uri.split('/').last.split('.').first,
  name: name,
  mime: switch (uri.split('.').last) {
    'png' => 'image/png',
    'jpg' => 'image/jpeg',
    _ => 'application/pdf',
  },
  uri: uri,
);
