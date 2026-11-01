import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

void main() {
  if (!regexSupported) return;
  test(
    'overlapping capture groups cannot expand output beyond bounded memory',
    () {
      expect(
        () => regex('a' * 100000, '${'(' * 25}a+${')' * 25}'),
        throwsFormatException,
      );
    },
  );
  test(
    'native RE2 returns legacy match envelope and optional capture groups',
    () {
      final result = regex('a1 b2 c', r'(\w)(\d)?');
      expect(result['engine'], 'RE2 (no backreferences or lookaround)');
      expect((result['matches'] as List).first, {
        'start': 0,
        'end': 2,
        'groups': ['a1', 'a', '1'],
      });
      expect((result['matches'] as List).last, {
        'start': 6,
        'end': 7,
        'groups': ['c', 'c', null],
      });
      expect(result['truncated'], isFalse);
      expect(regex('no digits', r'\d+')['matches'], isEmpty);
    },
  );
  test(
    'Unicode offsets use Dart/legacy UTF-16 indices; flags are native syntax',
    () {
      final result = regex('😀 é ViỆt', r'\p{L}+');
      expect(result['matches'], [
        {
          'start': 3,
          'end': 4,
          'groups': ['é'],
        },
        {
          'start': 5,
          'end': 9,
          'groups': ['ViỆt'],
        },
      ]);
      expect((regex('A\na', '(?im)^a')['matches'] as List).length, 2);
    },
  );
  test(
    'lookaround/backreferences and malformed patterns fail at compile time',
    () {
      for (final pattern in [r'(a)\1', r'a(?=b)', r'(?<=a)b', '[', '(']) {
        expect(() => regex('aaa', pattern), throwsFormatException);
      }
    },
  );
  test(
    'pathological pattern finishes on 100 KB input without backtracking fallback',
    () {
      expect(regex('${'a' * 99999}!', r'(a+)+$')['matches'], isEmpty);
      expect(() => regex('a' * 100001, 'a'), throwsFormatException);
    },
  );
  test(
    'zero width and repeated matches stop at the original 1000-result cap',
    () {
      expect((regex('ab', '')['matches'] as List).length, 3);
      final result = regex('a' * 2000, 'a');
      expect((result['matches'] as List).length, 1000);
      expect(result['truncated'], isTrue);
      expect(() => regex('x', 'a' * 1001), throwsFormatException);
      expect(() => regex('x', '€' * 334), throwsFormatException);
    },
  );
}
