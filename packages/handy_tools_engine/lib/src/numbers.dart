part of '../handy_tools_engine.dart';

final _zero = Rational.fromInt(0),
    _one = Rational.fromInt(1),
    _hundred = Rational.fromInt(100);
Rational _d(String source) {
  source = _bounded(source.trim(), 2000);
  if (!RegExp(
    r'^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$',
  ).hasMatch(source))
    throw const FormatException('Finite decimal number required');
  final exp = RegExp(r'[eE]([+-]?\d+)$').firstMatch(source);
  if (exp != null && int.parse(exp[1]!).abs() > 1000)
    throw const FormatException('Exponent limit is 1000');
  return Decimal.parse(source).toRational();
}

BigInt _roundedRatio(BigInt n, BigInt d) =>
    (n * BigInt.two + d) ~/ (d * BigInt.two);
String _fixed(Rational value, int places) {
  final scale = BigInt.from(10).pow(places),
      amount = _roundedRatio(value.numerator.abs() * scale, value.denominator);
  final digits = amount.toString().padLeft(places + 1, '0');
  final sign = value < _zero && amount != BigInt.zero ? '-' : '';
  return places == 0
      ? '$sign$digits'
      : '$sign${digits.substring(0, digits.length - places)}.${digits.substring(digits.length - places)}';
}

String _format(Rational value, [int precision = 15]) {
  if (value == _zero) return '0';
  final n = value.numerator.abs(), d = value.denominator, ten = BigInt.from(10);
  var exponent = n.toString().length - d.toString().length;
  if (exponent >= 0 ? n < d * ten.pow(exponent) : n * ten.pow(-exponent) < d)
    exponent--;
  final shift = precision - 1 - exponent;
  var digits =
      (shift >= 0
              ? _roundedRatio(n * ten.pow(shift), d)
              : _roundedRatio(n, d * ten.pow(-shift)))
          .toString();
  if (digits.length > precision) {
    exponent++;
    digits = digits.substring(0, precision);
  }
  digits = digits.replaceFirst(RegExp(r'0+$'), '');
  final sign = value < _zero ? '-' : '';
  if (exponent >= 21 || exponent <= -7)
    return '$sign${digits[0]}${digits.length > 1 ? '.${digits.substring(1)}' : ''}e${exponent >= 0 ? '+' : ''}$exponent';
  final at = exponent + 1;
  if (at <= 0) return '${sign}0.${'0' * -at}$digits';
  if (at >= digits.length) return '$sign$digits${'0' * (at - digits.length)}';
  return '$sign${digits.substring(0, at)}.${digits.substring(at)}';
}

Rational _guard(Rational value) {
  if (value.numerator.abs().toString().length > 60000 ||
      value.denominator.toString().length > 60000 ||
      value.abs() > _d('1e1000'))
    throw const FormatException('Result exceeds calculation budget');
  return value;
}

Rational _power(Rational base, Rational exponent) {
  if (exponent.abs() > Rational.fromInt(1000))
    throw const FormatException('Exponent limit is 1000');
  if (exponent.isInteger) {
    if (base == _zero && exponent < _zero)
      throw const FormatException('Division by zero');
    final power = exponent.toBigInt().toInt();
    final absolute = base.abs();
    if (absolute != _zero && power != 0) {
      final growth = power > 0 ? absolute : absolute.inverse;
      final minimumDigits =
          growth.numerator.toString().length -
          growth.denominator.toString().length -
          1;
      if (minimumDigits > 0 && minimumDigits * power.abs() > 1000) {
        throw const FormatException('Result exceeds calculation budget');
      }
    }
    return _guard(base.pow(power));
  }
  if (exponent == Rational.fromInt(1, 2)) return _sqrt(base);
  final input = base.toDouble(),
      result = math.pow(input, exponent.toDouble()).toDouble();
  if (!input.isFinite ||
      (base != _zero && input == 0) ||
      !result.isFinite ||
      (base != _zero && result == 0))
    throw const FormatException(
      'Fractional power is outside supported finite range',
    );
  return _d(result.toString());
}

// Round bounded intermediates to 34 significant digits. Exact fraction powers
// otherwise grow by thousands of digits per period for extremely small rates.
Rational _precision(Rational value) => _d(_format(value, 34));
Rational _compoundPower(Rational base, Rational exponent) {
  if (!exponent.isInteger) {
    final result = math.pow(base.toDouble(), exponent.toDouble()).toDouble();
    if (!result.isFinite)
      throw const FormatException(
        'Savings result exceeds supported fractional range',
      );
    return _guard(_d(result.toString()));
  }
  var count = exponent.toBigInt().toInt(), result = _one, factor = base;
  if (count < 0 || count > 36500)
    throw const FormatException('Invalid savings period count');
  while (count > 0) {
    if (count.isOdd) result = _precision(_guard(result * factor));
    count ~/= 2;
    if (count > 0) factor = _precision(_guard(factor * factor));
  }
  return result;
}

Rational _sqrt(Rational value) {
  if (value < _zero)
    throw const FormatException('Square root requires a nonnegative number');
  if (value == _zero) return _zero;
  final n = value.numerator, d = value.denominator, ten = BigInt.from(10);
  var exponent = n.toString().length - d.toString().length;
  if (exponent >= 0 ? n < d * ten.pow(exponent) : n * ten.pow(-exponent) < d)
    exponent--;
  final shift = 20 - (exponent / 2).floor();
  final scaled = shift >= 0
      ? n * ten.pow(2 * shift) ~/ d
      : n ~/ (d * ten.pow(-2 * shift));
  var root = BigInt.one << ((scaled.bitLength + 1) ~/ 2);
  while (true) {
    final next = (root + scaled ~/ root) ~/ BigInt.two;
    if (next >= root) break;
    root = next;
  }
  return shift >= 0
      ? Rational(root, ten.pow(shift))
      : Rational(root * ten.pow(-shift));
}

String calculate(String source) {
  _bounded(source, 2000);
  final matches = RegExp(
    r'(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?|[()+\-*/%^]|sqrt|abs|sin|cos|tan|log|pi|e',
    caseSensitive: false,
  ).allMatches(source);
  final tokens = matches.map((m) => m[0]!.toLowerCase()).toList();
  if (tokens.isEmpty ||
      tokens.join() != source.replaceAll(RegExp(r'\s+'), '').toLowerCase())
    throw const FormatException('Unsupported expression');
  var cursor = 0, depth = 0;
  late Rational Function(int) expression;
  Rational primary() {
    if (++depth > 50)
      throw const FormatException('Expression too deeply nested');
    try {
      if (cursor >= tokens.length)
        throw const FormatException('Expected a number');
      final token = tokens[cursor++];
      if (token == '+' || token == '-') {
        final result = expression(3);
        return token == '-' ? -result : result;
      }
      if (token == '(') {
        final result = expression(0);
        if (cursor >= tokens.length || tokens[cursor++] != ')')
          throw const FormatException('Missing closing parenthesis');
        return result;
      }
      if (token == 'pi') return _d(math.pi.toString());
      if (token == 'e') return _d(math.e.toString());
      if (['sqrt', 'abs', 'sin', 'cos', 'tan', 'log'].contains(token)) {
        if (cursor >= tokens.length || tokens[cursor++] != '(')
          throw const FormatException('Function requires parentheses');
        final value = expression(0);
        if (cursor >= tokens.length || tokens[cursor++] != ')')
          throw const FormatException('Missing closing parenthesis');
        if (token == 'abs') return value.abs();
        if (token == 'sqrt') return _sqrt(value);
        final number = value.toDouble();
        final result = switch (token) {
          'sqrt' => math.sqrt(number),
          'sin' => math.sin(number),
          'cos' => math.cos(number),
          'tan' => math.tan(number),
          _ => math.log(number) / math.ln10,
        };
        if (!result.isFinite)
          throw const FormatException('Function result is not finite');
        return _d(result.toString());
      }
      return _d(token);
    } finally {
      depth--;
    }
  }

  const priorities = {'+': 1, '-': 1, '*': 2, '/': 2, '%': 2, '^': 3};
  expression = (minimum) {
    var left = primary();
    while (cursor < tokens.length) {
      final op = tokens[cursor], priority = priorities[op];
      if (priority == null || priority < minimum) break;
      cursor++;
      final right = expression(op == '^' ? priority : priority + 1);
      if ((op == '/' || op == '%') && right == _zero)
        throw const FormatException('Division by zero');
      left = _guard(switch (op) {
        '+' => left + right,
        '-' => left - right,
        '*' => left * right,
        '/' => left / right,
        '%' => left.remainder(right),
        _ => _power(left, right),
      });
    }
    return left;
  };
  final result = expression(0);
  if (cursor != tokens.length)
    throw const FormatException('Invalid expression');
  return _format(result);
}

const unitGroups = <String, List<String>>{
  'length': ['mm', 'cm', 'm', 'km', 'in', 'ft', 'yd', 'mi'],
  'mass': ['mg', 'g', 'kg', 'lb', 'oz'],
  'volume': ['ml', 'l', 'us-gal'],
  'area': ['m2', 'km2', 'ha', 'acre'],
  'speed': ['m/s', 'km/h', 'mph'],
  'time': ['s', 'min', 'h', 'day'],
  'data': ['B', 'KB', 'MB', 'GB', 'KiB', 'MiB', 'GiB'],
  'temperature': ['C', 'F', 'K'],
};
final Map<String, (String, Rational)> _units = {
  for (final entry in <String, List<String>>{
    'length': [
      '0.001',
      '0.01',
      '1',
      '1000',
      '0.0254',
      '0.3048',
      '0.9144',
      '1609.344',
    ],
    'mass': ['0.001', '1', '1000', '453.59237', '28.349523125'],
    'volume': ['0.001', '1', '3.785411784'],
    'area': ['1', '1000000', '10000', '4046.8564224'],
    'speed': ['1', '0.2777777777777777777777777777777778', '0.44704'],
    'time': ['1', '60', '3600', '86400'],
    'data': [
      '1',
      '1000',
      '1000000',
      '1000000000',
      '1024',
      '1048576',
      '1073741824',
    ],
  }.entries)
    for (var i = 0; i < entry.value.length; i++)
      unitGroups[entry.key]![i]: (entry.key, _d(entry.value[i])),
};
String convert(String value, String from, String to) {
  var number = _d(value);
  if (['C', 'F', 'K'].contains(from) && ['C', 'F', 'K'].contains(to)) {
    number = from == 'F'
        ? (number - Rational.fromInt(32)) *
              Rational.fromInt(5) /
              Rational.fromInt(9)
        : from == 'K'
        ? number - _d('273.15')
        : number;
    if (number < _d('-273.15'))
      throw const FormatException('Below absolute zero');
    return _format(
      to == 'F'
          ? number * Rational.fromInt(9) / Rational.fromInt(5) +
                Rational.fromInt(32)
          : to == 'K'
          ? number + _d('273.15')
          : number,
      14,
    );
  }
  final a = _units[from], b = _units[to];
  if (a == null || b == null || a.$1 != b.$1)
    throw const FormatException('Incompatible or unknown units');
  return _format(number * a.$2 / b.$2, 14);
}

String loan(String principal, String annual, int months) {
  var balance = _d(principal);
  final rate = _d(annual) / Rational.fromInt(1200);
  if (balance < _zero ||
      balance > _d('1e15') ||
      rate < _zero ||
      rate > Rational.fromInt(1000) / Rational.fromInt(1200) ||
      months < 1 ||
      months > 1200)
    throw const FormatException('Invalid loan limits');
  final principalValue = balance, discount = _precision(_one / (_one + rate));
  var sum = _zero, factor = _one;
  for (var month = 0; month < months; month++) {
    factor = _precision(factor * discount);
    sum = _precision(sum + factor);
  }
  final payment = _precision(principalValue / sum);
  final rows = <String>['month,payment,interest,principal,balance'];
  for (var month = 1; month <= months; month++) {
    final interest = balance * rate;
    final paid = month == months ? balance : _min(balance, payment - interest);
    balance = _precision(_max(_zero, balance - paid));
    rows.add(
      '$month,${_fixed(paid + interest, 2)},${_fixed(interest, 2)},${_fixed(paid, 2)},${_fixed(balance, 2)}',
    );
  }
  return rows.join('\n');
}

Rational _min(Rational a, Rational b) => a < b ? a : b;
Rational _max(Rational a, Rational b) => a > b ? a : b;
