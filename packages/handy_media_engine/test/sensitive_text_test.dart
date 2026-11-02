import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media_engine/handy_media_engine.dart';

List<SensitiveKind> kinds(String text) => [
  for (final s in matchSensitive(text)) s.kind,
];

String found(String text) {
  final s = matchSensitive(text).single;
  return text.substring(s.start, s.end);
}

void main() {
  group('patterns', () {
    test('emails', () {
      expect(
        found('Gửi tới lan.nguyen+hr@cong-ty.com.vn nhé'),
        'lan.nguyen+hr@cong-ty.com.vn',
      );
      expect(kinds('no at sign here'), isEmpty);
    });

    test('Vietnamese and international phone numbers', () {
      for (final phone in [
        '0901234567',
        '090 123 4567',
        '090.123.4567',
        '+84 90 123 4567',
        '+84901234567',
        '0084 912 345 678',
        '028 3822 1234',
        '+44 20 7946 0958',
        '+1 (415) 555-0132',
      ]) {
        expect(found('Gọi $phone ngay'), phone, reason: phone);
        expect(kinds('Gọi $phone ngay'), [SensitiveKind.phone], reason: phone);
      }
      // Too short for a phone, no keyword for a code.
      expect(kinds('Tầng 12, phòng 1203'), isEmpty);
    });

    test('card numbers only when Luhn agrees', () {
      expect(luhn('4111111111111111'), isTrue);
      expect(luhn('4111111111111112'), isFalse);
      expect(kinds('Thẻ 4111 1111 1111 1111 hết hạn 09/28'), [
        SensitiveKind.card,
      ]);
      expect(found('Card 5500-0000-0000-0004.'), '5500-0000-0000-0004');
      // 16 digits that fail Luhn are still a long digit run: an account.
      expect(kinds('Ref 4111 1111 1111 1112'), [SensitiveKind.account]);
    });

    test('IBAN with its check digits, and bank-account-like runs', () {
      expect(ibanValid('GB82 WEST 1234 5698 7654 32'), isTrue);
      expect(ibanValid('GB83 WEST 1234 5698 7654 32'), isFalse);
      expect(
        found('IBAN: GB82 WEST 1234 5698 7654 32'),
        'GB82 WEST 1234 5698 7654 32',
      );
      expect(kinds('IBAN: GB82 WEST 1234 5698 7654 32'), [SensitiveKind.iban]);
      expect(kinds('STK 0071 0012 34568 Vietcombank'), [SensitiveKind.account]);
      expect(found('Số tài khoản: 19036612345018'), '19036612345018');
      // Amounts and dates with dots are not accounts.
      expect(kinds('Tổng 1.250.000.000 đ ngày 02.11.2026'), isEmpty);
    });

    test('one-time codes need a keyword or a line of their own', () {
      expect(kinds('Mã OTP của bạn là 482913'), [SensitiveKind.otp]);
      expect(kinds('Your verification code: 1234 5678'), [SensitiveKind.otp]);
      expect(kinds('  735102 '), [SensitiveKind.otp]);
      expect(kinds('Năm 2026 có 365 ngày'), isEmpty);
      expect(kinds('barcode 5512'), isEmpty);
    });

    test('long random tokens and keys, but not words or links', () {
      // Split so secret scanners do not take this fake key for a real one.
      expect(
        kinds(
          'sk_'
          'live_51HxQ2aBc9dEfGh7JkLmN0pQr',
        ),
        [SensitiveKind.token],
      );
      expect(
        kinds('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.dBjftJeZ4CVPmB92K27u'),
        [SensitiveKind.token],
      );
      expect(kinds('internationalisation_configuration_value'), isEmpty);
      expect(kinds('https://example.com/a1b2c3d4e5f6g7h8i9j0k'), isEmpty);
      expect(entropy('aaaaaaaa'), 0);
      expect(entropy('abcd'), 2);
    });

    test('a value written after a password or key label', () {
      expect(found('Mật khẩu: Hoa@2026!'), 'Hoa@2026!');
      expect(kinds('password = hunter22'), [SensitiveKind.secret]);
      expect(found('API key: abc123xyz'), 'abc123xyz');
    });

    test('spans never overlap and come in reading order', () {
      final spans = matchSensitive(
        'lan@x.vn 0901234567 4111111111111111 OTP 9988',
      );
      expect(
        [for (final s in spans) s.kind],
        [
          SensitiveKind.email,
          SensitiveKind.phone,
          SensitiveKind.card,
          SensitiveKind.otp,
        ],
      );
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].start, greaterThanOrEqualTo(spans[i - 1].end));
      }
    });

    test('the hint never repeats the value', () {
      expect(sensitiveHint('lan.nguyen@cong-ty.vn'), 'la…vn');
      expect(sensitiveHint('482913'), '4…3');
      expect(sensitiveHint('1234'), '••••');
      expect(sensitiveHint('0901 234 567'), '0…7');
    });
  });

  group('boxes', () {
    const line = OcrLine(
      'Email: lan@x.vn',
      OcrBox(100, 50, 300, 20),
      words: [
        OcrWord('Email:', OcrBox(100, 50, 100, 20)),
        OcrWord('lan@x.vn', OcrBox(220, 50, 180, 20)),
      ],
    );

    test('a match covers the words it touches, padded, in picture units', () {
      final f = findSensitiveAreas(
        [line],
        imageWidth: 1000,
        imageHeight: 500,
      ).single;
      expect(f.kind, SensitiveKind.email);
      expect(f.line, 0);
      expect(f.hint, 'l…n');
      // 220..400 × 50..70, padded by 3 px (15% of 20).
      expect(f.area.x, closeTo(217 / 1000, 1e-9));
      expect(f.area.y, closeTo(47 / 500, 1e-9));
      expect(f.area.width, closeTo(186 / 1000, 1e-9));
      expect(f.area.height, closeTo(26 / 500, 1e-9));
    });

    test('without word boxes the place is the share of the line', () {
      const bare = OcrLine('OTP 123456', OcrBox(0, 0, 100, 10));
      final f = findSensitiveAreas(
        [bare],
        imageWidth: 100,
        imageHeight: 100,
      ).single;
      // Characters 4..10 of 10: x 40..100, padded by 2 px and clamped.
      expect(f.area.x, closeTo(.38, 1e-9));
      expect(f.area.width, closeTo(.62, 1e-9));
      expect(f.area.y, 0);
    });

    test('a word holding more than the match is cut to the match', () {
      const glued = OcrLine(
        'mail:lan@x.vn',
        OcrBox(0, 0, 130, 10),
        words: [OcrWord('mail:lan@x.vn', OcrBox(0, 0, 130, 10))],
      );
      final f = findSensitiveAreas(
        [glued],
        imageWidth: 200,
        imageHeight: 100,
      ).single;
      expect(f.area.x, closeTo(48 / 200, 1e-9));
      expect(f.area.width, closeTo(84 / 200, 1e-9));
    });

    test('places already hidden are not proposed again', () {
      final hidden = [const LayerGeometry(.2, .05, .25, .1)];
      expect(
        findSensitiveAreas(
          [line],
          imageWidth: 1000,
          imageHeight: 500,
          hidden: hidden,
        ),
        isEmpty,
      );
    });

    test('accepted findings become opaque masks; bounds are kept', () {
      final f = findSensitiveAreas([line], imageWidth: 1000, imageHeight: 500);
      var n = 0;
      final layers = redactionLayers(f, newId: () => 'mask-${n++}');
      expect(layers.single.kind, 'redact');
      expect(layers.single.color, '#000000');
      expect(layers.single.id, 'mask-0');
      expect(layers.single.geometry.width, f.single.area.width);
      expect(
        () => findSensitiveAreas([line], imageWidth: 0, imageHeight: 10),
        throwsFormatException,
      );
      expect(
        () => findSensitiveAreas(
          List.filled(sensitiveMaxLines + 1, line),
          imageWidth: 10,
          imageHeight: 10,
        ),
        throwsFormatException,
      );
    });
  });
}
