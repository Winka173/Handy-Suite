import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/requests/response_view.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

void main() {
  test('responses compare by content, not by key order', () {
    final a = comparable('{"b":1,"a":[{"y":2,"x":1}]}');
    final b = comparable('{"a":[{"x":1,"y":2}],"b":1}');
    expect(a, b);
    expect(
      diffText(a, comparable('{"a":[{"x":1,"y":3}],"b":1}')).identical,
      isFalse,
    );
    expect(comparable('plain text'), 'plain text');
  });
}
