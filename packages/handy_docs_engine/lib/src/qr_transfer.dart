import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:qr/qr.dart' as qr;

/// Largest file sent as moving QR codes. At 480 bytes a frame and six
/// frames a second, 100 KB is some 35 seconds a loop: right for a note, a
/// page or two of PDF or a contact card, not for photos.
const qrTransferLimit = 100000;

/// Bytes of the file in one data frame: about 660 characters once encoded,
/// a version 18 code that a phone camera still reads off another phone.
const qrTransferChunk = 480;

/// Frames shown a second; the scanner reads every camera frame, so this
/// leaves each code on screen for a few of them.
const qrTransferFps = 6;

const _magic = 'HQT1';

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
Uint8List _unb64(String s) =>
    base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// A file as the frames to show in a loop: one header (name, size, SHA-256,
/// frame count), then the data. Every frame carries the transfer's id, so a
/// receiver never mixes two files.
List<String> qrTransferFrames(
  String name,
  Uint8List bytes, {
  math.Random? random,
}) {
  if (bytes.isEmpty) throw const FormatException('The file is empty');
  if (bytes.length > qrTransferLimit) {
    throw const FormatException(
      'Up to 100 KB by QR / Gửi bằng QR tối đa 100 KB',
    );
  }
  final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  final r = random ?? math.Random.secure();
  final id = List.generate(
    4,
    (_) => r.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  final count = (bytes.length + qrTransferChunk - 1) ~/ qrTransferChunk;
  final hash = crypto.sha256.convert(bytes).toString();
  return [
    '$_magic:H:$id:$count:${bytes.length}:$hash:${_b64(utf8.encode(clean.isEmpty ? 'file' : clean))}',
    for (var i = 0; i < count; i++)
      '$_magic:D:$id:$i:${_b64(bytes.sublist(i * qrTransferChunk, math.min(bytes.length, (i + 1) * qrTransferChunk)))}',
  ];
}

/// The QR modules of one frame (true is dark), low error correction for
/// the most data per code; screens are clean.
List<List<bool>> qrTransferMatrix(String frame) {
  final code = qr.QrCode.fromData(
    data: frame,
    errorCorrectLevel: qr.QrErrorCorrectLevel.L,
  );
  final image = qr.QrImage(code);
  return [
    for (var y = 0; y < image.moduleCount; y++)
      [for (var x = 0; x < image.moduleCount; x++) image.isDark(y, x)],
  ];
}

/// Collects frames read off the sender's screen, in any order and with
/// repeats, and hands back the file once every frame is in and its
/// SHA-256 matches. Frames of another transfer are ignored.
class QrTransferReceiver {
  String? _id, _name, _hash;
  int? _count, _size;
  final _chunks = <int, Uint8List>{};
  final _early = <String, Map<int, Uint8List>>{};

  /// Name, size and frame count once the header has been read.
  String? get name => _name;
  int? get size => _size;
  int? get count => _count;
  int get received => _chunks.length;
  bool get started => _id != null;

  /// Frames read before the header, waiting for it.
  int get waiting => _early.values.fold(0, (a, m) => a + m.length);
  bool get complete => _count != null && _chunks.length == _count;

  /// Reads one scanned text. True when it added something new.
  bool accept(String text) {
    final parts = text.split(':');
    if (parts.length < 5 || parts[0] != _magic) return false;
    final kind = parts[1], id = parts[2];
    try {
      if (kind == 'H' && parts.length == 7) {
        if (_id != null) return false;
        final count = int.parse(parts[3]), size = int.parse(parts[4]);
        if (count < 1 ||
            size < 1 ||
            size > qrTransferLimit ||
            count != (size + qrTransferChunk - 1) ~/ qrTransferChunk ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(parts[5])) {
          return false;
        }
        _id = id;
        _count = count;
        _size = size;
        _hash = parts[5];
        _name = utf8.decode(_unb64(parts[6]));
        for (final e in (_early.remove(id) ?? const {}).entries) {
          if (e.key < count) _chunks[e.key] = e.value;
        }
        _early.clear();
        return true;
      }
      if (kind == 'D' && parts.length == 5) {
        final index = int.parse(parts[3]);
        final data = _unb64(parts[4]);
        if (index < 0 || data.isEmpty || data.length > qrTransferChunk) {
          return false;
        }
        if (_id == null) {
          // Frames seen before the header wait for it (a few transfers at most).
          if (_early.length > 4 && !_early.containsKey(id)) return false;
          final m = _early.putIfAbsent(id, () => {});
          return m.putIfAbsent(index, () => data) == data &&
              m.length <= qrTransferLimit ~/ qrTransferChunk + 1;
        }
        if (id != _id || index >= _count! || _chunks.containsKey(index)) {
          return false;
        }
        _chunks[index] = data;
        return true;
      }
    } on FormatException {
      return false;
    }
    return false;
  }

  /// The file, checked against its size and SHA-256.
  ({String name, Uint8List bytes}) result() {
    if (!complete) throw const FormatException('Not every frame is in yet');
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < _count!; i++) {
      out.add(_chunks[i]!);
    }
    final bytes = out.takeBytes();
    if (bytes.length != _size ||
        crypto.sha256.convert(bytes).toString() != _hash) {
      throw const FormatException(
        'The file did not arrive intact; scan again / Tệp nhận bị lỗi, hãy quét lại',
      );
    }
    return (name: _name!, bytes: bytes);
  }
}
