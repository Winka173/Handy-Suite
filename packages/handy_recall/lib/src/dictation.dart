part of '../handy_recall.dart';

enum DictationMark { right, wrong, missing, extra }

/// One word of a dictation check: what was typed (empty when missing) and
/// what was expected (empty when extra).
class DictationWord {
  final String typed, expected;
  final DictationMark mark;
  const DictationWord(this.typed, this.expected, this.mark);
  @override
  String toString() => '$mark($typed/$expected)';
}

/// A dictation answer compared word by word with the expected text.
class DictationCheck {
  final List<DictationWord> words;
  const DictationCheck(this.words);
  bool get allRight =>
      words.isNotEmpty && words.every((w) => w.mark == DictationMark.right);
  int get rightCount =>
      words.where((w) => w.mark == DictationMark.right).length;

  /// Words of the expected text.
  int get expectedCount =>
      words.where((w) => w.mark != DictationMark.extra).length;
}

const _vietnameseBase = {
  'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a', //
  'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
  'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
  'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
  'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
  'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
  'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
  'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
  'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
  'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
  'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
  'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y', 'đ': 'd',
  'ç': 'c', 'ñ': 'n', 'ü': 'u', 'ö': 'o', 'ä': 'a', 'ß': 'ss',
  'ï': 'i', 'î': 'i', 'û': 'u',
};

List<String> _dictationWords(String text) => [
  for (final w in text.split(RegExp(r'\s+')))
    // Punctuation around a word never counts; inside it (don't, e-mail) does.
    if (w.replaceAll(
          RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$", unicode: true),
          '',
        )
        case final t when t.isNotEmpty)
      t,
];

/// [typed] checked against [expected] word by word, aligned so one wrong or
/// missing word does not mark the rest wrong. Case is ignored unless
/// [matchCase]; accents count unless [ignoreAccents] (Vietnamese marks
/// change the word).
DictationCheck checkDictation(
  String expected,
  String typed, {
  bool matchCase = false,
  bool ignoreAccents = false,
}) {
  if (expected.length > 5000 || typed.length > 5000) {
    throw const FormatException('Dictation is for a sentence or two');
  }
  final want = _dictationWords(expected), got = _dictationWords(typed);
  String key(String w) {
    var k = matchCase ? w : w.toLowerCase();
    if (ignoreAccents) {
      k = k.toLowerCase().split('').map((c) => _vietnameseBase[c] ?? c).join();
    }
    return k;
  }

  final a = want.map(key).toList(), b = got.map(key).toList();
  // Longest common subsequence of words.
  final lcs = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }
  final out = <DictationWord>[];
  final missing = <String>[], extra = <String>[];
  void flush() {
    // A typed word in place of an expected one is a wrong word.
    final pairs = math.min(missing.length, extra.length);
    for (var k = 0; k < pairs; k++) {
      out.add(DictationWord(extra[k], missing[k], DictationMark.wrong));
    }
    for (final m in missing.skip(pairs)) {
      out.add(DictationWord('', m, DictationMark.missing));
    }
    for (final e in extra.skip(pairs)) {
      out.add(DictationWord(e, '', DictationMark.extra));
    }
    missing.clear();
    extra.clear();
  }

  var i = 0, j = 0;
  while (i < a.length || j < b.length) {
    if (i < a.length && j < b.length && a[i] == b[j]) {
      flush();
      out.add(DictationWord(got[j], want[i], DictationMark.right));
      i++;
      j++;
    } else if (j < b.length &&
        (i == a.length || lcs[i][j + 1] >= lcs[i + 1][j])) {
      extra.add(got[j++]);
    } else {
      missing.add(want[i++]);
    }
  }
  flush();
  return DictationCheck(out);
}
