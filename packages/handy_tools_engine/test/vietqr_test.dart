import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  test('CRC-16/CCITT-FALSE check value', () {
    expect(crc16Ccitt('123456789'), '29B1');
  });

  // Known-good payloads published with the vietnam-qr-pay library
  // (npm, README) and the vietqr_generator package (pub.dev docs).
  test('static code, ACB 257678859: byte-exact', () {
    expect(
      vietQr(bin: '970416', account: '257678859'),
      '00020101021138530010A0000007270123000697041601092576788590208QRIBFTTA53037045802VN6304AE9F',
    );
  });
  test('dynamic code with amount and message: byte-exact', () {
    expect(
      vietQr(
        bin: '970416',
        account: '257678859',
        amount: '10000',
        message: 'Chuyen tien',
      ),
      '00020101021238530010A0000007270123000697041601092576788590208QRIBFTTA53037045405100005802VN62150811Chuyen tien630453E6',
    );
    expect(
      vietQr(
        bin: '970416',
        account: '257678859',
        amount: '1000',
        message: 'Chuyen tien',
      ),
      '00020101021238530010A0000007270123000697041601092576788590208QRIBFTTA5303704540410005802VN62150811Chuyen tien6304BBB8',
    );
  });
  test('wallet account with letters', () {
    final v = vietQr(bin: '971025', account: 'PSP123456789000000');
    expect(
      v.startsWith(
        '00020101021138620010A000000727013200069710250118PSP1234567890000000208QRIBFTTA',
      ),
      isTrue,
    );
  });
  test('messages lose their accents; amounts take grouping', () {
    final v = vietQr(
      bin: '970436',
      account: '0123456789',
      amount: '1.250.000',
      message: '  Tiền nhà   tháng 11 ',
    );
    expect(v, contains('54071250000'));
    expect(v, contains('62210817Tien nha thang 11'));
    final back = readVietQr(v)!;
    expect(back.bin, '970436');
    expect(back.account, '0123456789');
    expect(back.amount, '1250000');
    expect(back.message, 'Tien nha thang 11');
  });
  test('the QR preview names a transfer code', () {
    final v = vietQr(bin: '970436', account: '0123456789');
    expect(qrPreview(v)['kind'], 'VietQR');
    expect(qrPreview('hello')['kind'], 'Text');
  });
  test('reading refuses a changed payload', () {
    final v = vietQr(bin: '970436', account: '0123456789');
    expect(readVietQr(v.replaceFirst('0123456789', '0123456788')), isNull);
    expect(readVietQr('hello'), isNull);
  });
  test('invalid fields are refused', () {
    expect(
      () => vietQr(bin: '97043', account: '0123456789'),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '12345'),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123-456'),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123456789', amount: '0'),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123456789', amount: '1.5'),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123456789', amount: '1' * 14),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123456789', message: 'a' * 26),
      throwsFormatException,
    );
    expect(
      () => vietQr(bin: '970436', account: '0123456789', message: 'a;b'),
      throwsFormatException,
    );
  });
  test('bank list: unique 6-digit BINs and the big four present', () {
    expect(vietQrBanks.length, 76);
    expect(vietQrBanks.map((b) => b.bin).toSet().length, vietQrBanks.length);
    for (final b in vietQrBanks) {
      expect(b.bin, matches(RegExp(r'^\d{6}$')));
    }
    expect(vietQrBank('970436')!.shortName, 'Vietcombank');
    expect(vietQrBank('970415')!.shortName, 'VietinBank');
    expect(vietQrBank('970418')!.shortName, 'BIDV');
    expect(vietQrBank('970405')!.shortName, 'Agribank');
    expect(vietQrBank('000000'), isNull);
  });
}
