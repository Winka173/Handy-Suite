import 'dart:math';
import 'dart:typed_data';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:test/test.dart';

Uint8List bytes(int n, [int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

void main() {
  test('a file comes back whole from frames in any order, with repeats', () {
    final file = bytes(5000);
    final frames = qrTransferFrames('Hợp đồng.pdf', file, random: Random(3));
    expect(frames.length, 1 + (5000 / qrTransferChunk).ceil());
    expect(frames.every((f) => f.length < 700), isTrue);
    final shuffled = [...frames.skip(1), ...frames, frames[2]]
      ..shuffle(Random(9));
    final r = QrTransferReceiver();
    for (final f in shuffled) {
      r.accept(f);
    }
    expect(r.complete, isTrue);
    final got = r.result();
    expect(got.name, 'Hợp đồng.pdf');
    expect(got.bytes, file);
  });

  test('frames of another transfer and noise are ignored', () {
    final a = qrTransferFrames('a.txt', bytes(1500, 1), random: Random(1));
    final b = qrTransferFrames('b.txt', bytes(1500, 2), random: Random(2));
    final r = QrTransferReceiver();
    expect(r.accept(a.first), isTrue);
    for (final f in [...b, 'https://example.com', 'HQT1:D:zz:0:!!', ...a]) {
      r.accept(f);
    }
    expect(r.result().name, 'a.txt');
  });

  test('a damaged frame is caught by the checksum', () {
    final frames = qrTransferFrames('x.bin', bytes(1300), random: Random(4));
    final r = QrTransferReceiver()..accept(frames.first);
    final parts = frames[1].split(':');
    final bad = parts.last.replaceRange(0, 4, 'AAAA');
    r.accept([...parts.take(4), bad].join(':'));
    for (final f in frames.skip(2)) {
      r.accept(f);
    }
    expect(r.complete, isTrue);
    expect(r.result, throwsFormatException);
  });

  test('limits: empty and oversized files are refused; names are cleaned', () {
    expect(() => qrTransferFrames('e', Uint8List(0)), throwsFormatException);
    expect(
      () => qrTransferFrames('big', Uint8List(qrTransferLimit + 1)),
      throwsFormatException,
    );
    final r = QrTransferReceiver()
      ..accept(qrTransferFrames('a/b:c.txt', bytes(10)).first);
    expect(r.name, 'a_b_c.txt');
  });

  test('each frame makes a QR code', () {
    final f = qrTransferFrames('n.txt', bytes(qrTransferChunk)).last;
    final m = qrTransferMatrix(f);
    expect(m.length, greaterThan(21));
    expect(m.every((row) => row.length == m.length), isTrue);
  });
}
