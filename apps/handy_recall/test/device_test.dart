import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall_app/card_link.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/home_widget.dart';
import 'helpers.dart';

void main() {
  test('the widget answers how many cards are due', () {
    final now = DateTime.utc(2030);
    final view = recallWidgetView(fixture(), now, vi: true);
    expect(view.value, endsWith('thẻ'));
    expect(view.uri, 'handy-recall://review');
    expect(
      recallWidgetView(emptyRecallState(), now, vi: false).value,
      'No cards yet',
    );
  });

  test('a card from another app is parsed, bounded, never empty', () {
    final link = CardLink.parse(
      Uri.parse(
        'handy-recall://new?front=Bài%20viết%20hay&back=https://example.org/a',
      ),
    )!;
    expect(link.front, 'Bài viết hay');
    expect(link.back, 'https://example.org/a');
    expect(CardLink.parse(Uri.parse('handy-recall://new')), isNull);
    expect(CardLink.parse(Uri.parse('handy-recall://review')), isNull);
    final long = CardLink.parse(
      Uri.parse('handy-recall://new?front=${'a' * 900}'),
    )!;
    expect(long.front.length, 500);
  });
}
