import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_recall/handy_recall.dart';
import 'study/schedule.dart';

/// The fully qualified Android widget class.
const recallWidgetClass = 'com.example.handysuite.recall.HandyWidget';

/// What the home-screen widget shows: the cards due now and the minutes
/// they take, or tomorrow's count when today is clear.
HomeWidgetView recallWidgetView(
  RecallState s,
  DateTime now, {
  required bool vi,
}) {
  final ahead = forecast(s, now);
  final due = ahead.first, tomorrow = ahead.length > 1 ? ahead[1] : 0;
  final title = vi ? 'Handy Recall · Ôn hôm nay' : 'Handy Recall · Today';
  if (s.cards.isEmpty)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Chưa có thẻ' : 'No cards yet',
      detail: vi ? 'Chạm để tạo bộ thẻ đầu tiên' : 'Tap to make a first deck',
      uri: 'handy-recall://home',
    );
  if (due == 0)
    return HomeWidgetView(
      title: title,
      value: vi ? 'Xong hôm nay' : 'Done for today',
      detail: vi ? 'Ngày mai: $tomorrow thẻ' : 'Tomorrow: $tomorrow cards',
      uri: 'handy-recall://home',
    );
  return HomeWidgetView(
    title: title,
    value: vi ? '$due thẻ' : '$due cards',
    detail: vi
        ? 'Khoảng ${minutesFor(due)} phút · chạm để ôn'
        : 'About ${minutesFor(due)} min · tap to review',
    uri: 'handy-recall://review',
  );
}
