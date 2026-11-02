import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/sealed.dart';

void main() {
  // Fewer rounds than the default so the suite stays fast.
  const rounds = 10000;
  final plain = Uint8List.fromList(utf8.encode('Sao lưu — dữ liệu riêng tư'));

  test('seals without the password and opens with it', () async {
    final key = await SealKey.create('mật khẩu', iterations: rounds);
    final restored = SealKey.fromJson(
      jsonDecode(jsonEncode(key.toJson())) as Map<String, Object?>,
    );
    final sealed = await seal(plain, restored);
    expect(isSealed(sealed), isTrue);
    expect(isSealed(plain), isFalse);
    expect(utf8.decode(sealed, allowMalformed: true), isNot(contains('riêng')));
    expect(await unseal(sealed, 'mật khẩu'), plain);
    // Each backup uses a fresh ephemeral key.
    expect(await seal(plain, restored), isNot(sealed));
  });

  test('wrong password, tampering and plain files are refused', () async {
    final key = await SealKey.create('a', iterations: rounds);
    final sealed = await seal(plain, key);
    expect(
      () => unseal(sealed, 'b'),
      throwsA(
        isA<SealException>().having(
          (e) => e.failure,
          'failure',
          SealFailure.wrongPassword,
        ),
      ),
    );
    for (final at in [9, 40, sealed.length - 20, sealed.length - 1]) {
      final bad = Uint8List.fromList(sealed)..[at] ^= 1;
      expect(
        () => unseal(bad, 'a'),
        throwsA(isA<SealException>()),
        reason: '$at',
      );
    }
    expect(
      () => unseal(plain, 'a'),
      throwsA(
        isA<SealException>().having(
          (e) => e.failure,
          'failure',
          SealFailure.notSealed,
        ),
      ),
    );
    expect(
      () => unseal(sealed.sublist(0, 60), 'a'),
      throwsA(isA<SealException>()),
    );
  });

  test('a new password keeps the key; old backups keep the old one', () async {
    final key = await SealKey.create('old', iterations: rounds);
    final before = await seal(plain, key);
    final changed = await key.rewrap('old', 'new');
    expect(changed.publicKey, key.publicKey);
    expect(await changed.check('new'), isTrue);
    expect(await changed.check('old'), isFalse);
    expect(await unseal(await seal(plain, changed), 'new'), plain);
    expect(await unseal(before, 'old'), plain);
    expect(() => key.rewrap('wrong', 'x'), throwsA(isA<SealException>()));
  });

  test('a damaged stored key is refused', () {
    expect(
      () => SealKey.fromJson({'version': 1, 'iterations': 5}),
      throwsFormatException,
    );
    expect(() => SealKey.create(''), throwsArgumentError);
  });
}
