import 'package:flutter_test/flutter_test.dart';
import 'package:handy_home_widget/handy_home_widget.dart';

void main() {
  test('rows beyond the three slots are cleared, links kept per row', () {
    const view = HomeWidgetView(
      title: 'Hôm nay',
      value: 'Còn 2 việc',
      uri: 'handy-habit://today',
      rows: [('○ Đọc sách', 'handy-habit://checkin/read')],
    );
    final data = view.toData();
    expect(data['row0_text'], '○ Đọc sách');
    expect(data['row0_uri'], 'handy-habit://checkin/read');
    expect(data['row1_text'], isNull);
    expect(data['row2_uri'], isNull);
    expect(
      view,
      const HomeWidgetView(
        title: 'Hôm nay',
        value: 'Còn 2 việc',
        uri: 'handy-habit://today',
        rows: [('○ Đọc sách', 'handy-habit://checkin/read')],
      ),
    );
  });

  test('publishing off Android does nothing', () async {
    // Host tests run as a desktop platform: no widget, no error.
    await HomeWidgetFeed(
      'x.HandyWidget',
    ).publish(const HomeWidgetView(title: 't', value: 'v', uri: 'a://b'));
  });
}
