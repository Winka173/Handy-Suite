import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';

void main() {
  String vi(String n, [VietnameseWordStyle s = VietnameseWordStyle.north]) =>
      vietnameseNumberWords(n, style: s);

  group('Vietnamese words', () {
    for (final v in <String, String>{
      '0': 'không',
      '1': 'một',
      '5': 'năm',
      '10': 'mười',
      '11': 'mười một',
      '14': 'mười bốn',
      '15': 'mười lăm',
      '20': 'hai mươi',
      '21': 'hai mươi mốt',
      '24': 'hai mươi tư',
      '25': 'hai mươi lăm',
      '31': 'ba mươi mốt',
      '55': 'năm mươi lăm',
      '99': 'chín mươi chín',
      '100': 'một trăm',
      '101': 'một trăm linh một',
      '105': 'một trăm linh năm',
      '110': 'một trăm mười',
      '115': 'một trăm mười lăm',
      '121': 'một trăm hai mươi mốt',
      '1000': 'một nghìn',
      '1001': 'một nghìn không trăm linh một',
      '1010': 'một nghìn không trăm mười',
      '1024': 'một nghìn không trăm hai mươi tư',
      '1100': 'một nghìn một trăm',
      '10000': 'mười nghìn',
      '15000': 'mười lăm nghìn',
      '21000': 'hai mươi mốt nghìn',
      '100000': 'một trăm nghìn',
      '1000000': 'một triệu',
      '1000005': 'một triệu không trăm linh năm',
      '1050000': 'một triệu không trăm năm mươi nghìn',
      '1200000': 'một triệu hai trăm nghìn',
      '1250000': 'một triệu hai trăm năm mươi nghìn',
      '25000000': 'hai mươi lăm triệu',
      '1000000000': 'một tỷ',
      '1000000050': 'một tỷ không trăm năm mươi',
      '2500000000': 'hai tỷ năm trăm triệu',
      '1000000000000': 'một nghìn tỷ',
      '1234567891011':
          'một nghìn hai trăm ba mươi tư tỷ năm trăm sáu mươi bảy triệu tám trăm chín mươi mốt nghìn không trăm mười một',
      '1000000000000000': 'một triệu tỷ',
      '1000000000000000000': 'một tỷ tỷ',
      '0005': 'năm',
    }.entries) {
      test(v.key, () => expect(vi(v.key), v.value));
    }
    test('southern style: lẻ and ngàn', () {
      expect(vi('1105', VietnameseWordStyle.south), 'một ngàn một trăm lẻ năm');
      expect(
        vi('1005', VietnameseWordStyle.south),
        'một ngàn không trăm lẻ năm',
      );
    });
    test('nhăm and bốn styles apply only after mươi', () {
      const style = VietnameseWordStyle(five: 'nhăm', four: 'bốn');
      expect(vi('25', style), 'hai mươi nhăm');
      expect(vi('15', style), 'mười lăm');
      expect(vi('34', style), 'ba mươi bốn');
      expect(vi('14', style), 'mười bốn');
      expect(vi('105', style), 'một trăm linh năm');
    });
    test('negatives and decimals', () {
      expect(vi('-15'), 'âm mười lăm');
      expect(vi('1.5'), 'một phẩy năm');
      expect(vi('3.14'), 'ba phẩy một bốn');
      expect(vi('0.05'), 'không phẩy không năm');
      expect(vi('-0.5'), 'âm không phẩy năm');
      expect(vi('2.50'), 'hai phẩy năm');
      expect(vi('-0'), 'không');
      expect(vi('7.000'), 'bảy');
    });
    test('the invoice line', () {
      expect(
        vietnameseAmountWords('1200000'),
        'Một triệu hai trăm nghìn đồng chẵn',
      );
      expect(vietnameseAmountWords('0'), 'Không đồng chẵn');
      expect(vietnameseAmountWords('-50000'), 'Âm năm mươi nghìn đồng chẵn');
      expect(() => vietnameseAmountWords('1.5'), throwsFormatException);
    });
    test('input is validated', () {
      for (final bad in [
        '',
        'abc',
        '1,000',
        '1e5',
        '--1',
        '1.2.3',
        '1' * 28,
        '1.${'1' * 13}',
        '1' * 101,
      ]) {
        expect(() => vi(bad), throwsFormatException, reason: bad);
      }
      expect(vi('1' * 27), isNotEmpty);
    });
  });

  group('English words', () {
    for (final v in <String, String>{
      '0': 'zero',
      '7': 'seven',
      '13': 'thirteen',
      '21': 'twenty-one',
      '40': 'forty',
      '105': 'one hundred five',
      '1000': 'one thousand',
      '1001': 'one thousand one',
      '1200000': 'one million two hundred thousand',
      '1000000000': 'one billion',
      '1234567891011':
          'one trillion two hundred thirty-four billion five hundred sixty-seven million eight hundred ninety-one thousand eleven',
      '-15.25': 'minus fifteen point two five',
      '999999999999999999999999999':
          'nine hundred ninety-nine septillion nine hundred ninety-nine sextillion nine hundred ninety-nine quintillion nine hundred ninety-nine quadrillion nine hundred ninety-nine trillion nine hundred ninety-nine billion nine hundred ninety-nine million nine hundred ninety-nine thousand nine hundred ninety-nine',
    }.entries) {
      test(v.key, () => expect(englishNumberWords(v.key), v.value));
    }
  });

  group('registry runner', () {
    Map<String, Object?> run(String input, [String options = '']) =>
        (jsonDecode(
                  tools
                      .singleWhere((t) => t.id == 'number-words')
                      .run(input, options),
                )
                as Map)
            .cast<String, Object?>();
    test('đồng by default', () {
      expect(run('1200000'), {
        'number': '1200000',
        'vi': 'Một triệu hai trăm nghìn đồng chẵn',
        'en': 'One million two hundred thousand dong',
      });
    });
    test('plain numbers, southern style', () {
      final j = run('1105.5', 'unit=none;style=south');
      expect(j['vi'], 'một ngàn một trăm lẻ năm phẩy năm');
      expect(j['en'], 'One thousand one hundred five point five');
    });
    test('bad options are refused', () {
      expect(() => run('1', 'unit=usd'), throwsFormatException);
      expect(() => run('1', 'style'), throwsFormatException);
      expect(() => run('1.5', 'unit=dong'), throwsFormatException);
    });
  });
}
