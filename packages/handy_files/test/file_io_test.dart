import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_files/src/verify_io.dart';

void main() {
  test('UTF8 stream handles split multibyte characters losslessly', () async {
    final bytes = utf8.encode('Xin chào 😀');
    expect(
      await readTextStream(Stream.fromIterable(bytes.map((b) => [b]))),
      'Xin chào 😀',
    );
  });
  test(
    'large stream rejected at boundary without consuming the rest',
    () async {
      var consumed = 0;
      Stream<List<int>> input() async* {
        for (var i = 0; i < 10; i++) {
          consumed++;
          yield [65, 65];
        }
      }

      await expectLater(
        readTextStream(input(), maxBytes: 5),
        throwsFormatException,
      );
      expect(consumed, 3);
    },
  );
  test(
    'cancellation mid-read reports cancellation not truncated success',
    () async {
      final c = CancellationToken();
      Stream<List<int>> input() async* {
        yield [65];
        c.cancel();
        yield [66];
      }

      await expectLater(
        readTextStream(input(), cancellation: c),
        throwsA(isA<Cancelled>()),
      );
    },
  );
  test('binary and invalid encoding rejected', () async {
    await expectLater(
      readTextStream(Stream.value([0xc3, 0x28])),
      throwsFormatException,
    );
    await expectLater(
      readTextStream(Stream.value([1, 0, 2])),
      throwsFormatException,
    );
  });
  test(
    'real filesystem write/readback verifies bytes and never repairs bad output silently',
    () async {
      final folder = await Directory.systemTemp.createTemp('handy-verified-');
      addTearDown(() => folder.delete(recursive: true));
      final original = File('${folder.path}/nguồn.txt');
      await original.writeAsString('preserve', flush: true);
      final target = File('${folder.path}/output.txt');
      final bytes = Uint8List.fromList(utf8.encode('Tiếng Việt 😀'));
      await target.writeAsBytes(bytes, flush: true);
      expect(await verifySavedFile(target.uri, bytes), true);
      await target.writeAsString('corrupt', flush: true);
      await expectLater(
        verifySavedFile(target.uri, bytes),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsString(), 'preserve');
      expect(await target.readAsString(), 'corrupt');
    },
  );
  test('provider URI explicitly reports no local path readback', () async {
    expect(
      await verifySavedFile(
        Uri.parse('content://provider/export'),
        Uint8List(0),
      ),
      false,
    );
  });
}
