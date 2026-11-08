import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

/// No task names leave private storage until the owner enables the widget.
HomeWidgetView boardsHomeView(BoardsState s, DateTime now, {required bool vi}) {
  final enabled = s.preferences['homeWidget'] == true;
  final due = <BoardRecord>[];
  if (enabled) {
    for (final t in s.rows('tasks')) {
      if (t.flag('trashed') ||
          t.flag('archived') ||
          t.data['parent'] != null ||
          t.data['due'] == null ||
          completed(s, t))
        continue;
      final b = s.get('boards', t.str('board'));
      final today = localDay(now, b.str('zone'));
      if (deadlineDay(object(t.data['due']), b.str('zone')).compareTo(today) <=
          0)
        due.add(t);
      else if (scheduledDay(t) == calendarDay(now))
        // Planned for today (the plan, not a deadline).
        due.add(t);
    }
    due.sort((a, b) => compareTasks(a, b, 'due'));
  }
  return HomeWidgetView(
    title: 'Handy Boards',
    value: enabled
        ? '${due.length} ${vi ? 'việc đến hạn' : 'due tasks'}'
        : (vi ? 'Mở bảng của bạn' : 'Open your boards'),
    detail: enabled
        ? (vi ? 'Cập nhật khi mở ứng dụng' : 'Updated when the app opens')
        : (vi
              ? 'Bật nội dung widget trong Cài đặt'
              : 'Enable widget content in Settings'),
    uri: 'handy-boards://today',
    rows: [
      for (final t in due.take(3))
        (
          t.str('title'),
          'handy-boards://task?id=${Uri.encodeQueryComponent(t.id)}',
        ),
    ],
  );
}

/// The other widgets, each under its own key prefix (see BoardsWidgets.kt).
/// Every number comes from the same queries as My Work and Time; names
/// appear only when the owner allowed them (`homeWidget`), and the Pro
/// widgets say they are Pro instead of showing data without it.
Map<String, HomeWidgetView> boardsWidgetViews(
  BoardsState s,
  DateTime now, {
  required bool vi,
  required bool pro,
}) {
  String t(String en, String v) => vi ? v : en;
  final names = s.preferences['homeWidget'] == true;
  final work = myWork(s, now, days: 7);
  String line(WorkItem i) => names
      ? '${i.overdue ? (vi ? 'Quá hạn · ' : 'Overdue · ') : ''}${i.card.str('title')}'
      : '';
  List<(String, String)> rows(Iterable<WorkItem> items) => [
    if (names)
      for (final i in items.take(3))
        (
          line(i),
          'handy-boards://task?id=${Uri.encodeQueryComponent(i.card.id)}',
        ),
  ];

  // Board Progress: the chosen board, or the first one.
  final boards = homeBoards(s);
  final chosen =
      boards.where((b) => b.id == s.preferences['widgetBoard']).firstOrNull ??
      boards.firstOrNull;
  HomeWidgetView progress;
  if (chosen == null) {
    progress = HomeWidgetView(
      title: 'Handy Boards',
      value: t('No board yet', 'Chưa có bảng'),
      detail: t('Make one in the app', 'Tạo một bảng trong app'),
      uri: 'handy-boards://today',
      progress: 0,
    );
  } else {
    final sum = boardSummary(s, chosen.id, now: now);
    progress = HomeWidgetView(
      title: names ? chosen.str('title') : 'Handy Boards',
      value: t(
        '${sum.done}/${sum.cards} done',
        '${sum.done}/${sum.cards} xong',
      ),
      detail: sum.cards == 0
          ? t('No cards yet', 'Chưa có thẻ')
          : '${(sum.done * 100 / sum.cards).round()}%',
      uri: 'handy-boards://board?id=${Uri.encodeQueryComponent(chosen.id)}',
      progress: sum.cards == 0 ? 0 : (sum.done * 100 / sum.cards).round(),
    );
  }

  final upcoming = HomeWidgetView(
    title: t('Left behind · coming up', 'Còn tồn · sắp tới'),
    value: t(
      '${work.behind.length} left · ${work.upcoming.length} soon',
      '${work.behind.length} còn tồn · ${work.upcoming.length} sắp tới',
    ),
    detail: t('Next 7 days', '7 ngày tới'),
    uri: 'handy-boards://my-work',
    rows: rows(work.behind),
  );

  HomeWidgetView locked(String title) => HomeWidgetView(
    title: '$title · Pro',
    value: t('Unlock in the app', 'Mở khoá trong app'),
    detail: t('A Pro widget', 'Widget Pro'),
    uri: 'handy-boards://pro',
  );

  final my = pro
      ? HomeWidgetView(
          title: t('My Work', 'Việc của tôi'),
          value: t(
            '${work.today.length} today · ${work.behind.length} left',
            '${work.today.length} hôm nay · ${work.behind.length} còn tồn',
          ),
          detail: t('All boards', 'Mọi bảng'),
          uri: 'handy-boards://my-work',
          rows: rows([...work.today, ...work.behind]),
        )
      : locked(t('My Work', 'Việc của tôi'));

  final today = calendarDay(now);
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const viDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  final open = [
    for (final c in topTasks(s))
      if (isOpenCard(s, c)) c,
  ];
  final week = pro
      ? HomeWidgetView(
          title: t('This week', 'Tuần này'),
          value: t(
            '${work.behind.length} left behind',
            '${work.behind.length} việc còn tồn',
          ),
          uri: 'handy-boards://my-work',
          maxRows: 7,
          rows: [
            for (var i = 0; i < 7; i++)
              () {
                final d = addDays(today, i);
                final n = open.where((c) {
                  final planned = scheduledDay(c), due = dueDay(c);
                  return planned == d || (planned == null && due == d);
                }).length;
                final name = vi ? viDays[d.weekday - 1] : en[d.weekday - 1];
                return (
                  '${i == 0 ? (vi ? 'Hôm nay' : 'Today') : name} ${d.day}/${d.month} · '
                      '${n == 0 ? '–' : (vi ? '$n việc' : '$n')}',
                  'handy-boards://my-work',
                );
              }(),
          ],
        )
      : locked(t('Week', 'Tuần'));
  return {
    'progress_': progress,
    'upcoming_': upcoming,
    'work_': my,
    'week_': week,
  };
}

class BoardsHomeSurface {
  static const channel = MethodChannel('handy.boards/home');
  final feed = HomeWidgetFeed(
    'com.example.handysuite.handy_boards.HandyWidget',
  );
  final others = {
    for (final (prefix, cls) in const [
      ('progress_', 'ProgressWidget'),
      ('upcoming_', 'UpcomingWidget'),
      ('work_', 'WorkWidget'),
      ('week_', 'WeekWidget'),
    ])
      prefix: HomeWidgetFeed(
        'com.example.handysuite.handy_boards.$cls',
        prefix: prefix,
      ),
  };
  StreamSubscription<Uri>? subscription;
  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  void listen(void Function(Uri) onLink) {
    if (!supported) return;
    // The native URI bridge handles both widget and shortcut intents once.
    channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        final uri = Uri.tryParse(call.arguments as String);
        if (uri != null) {
          onLink(uri);
          await channel.invokeMethod('ack', call.arguments);
        }
      }
    });
    unawaited(
      channel
          .invokeMethod<String>('pending')
          .then((value) {
            if (value != null) {
              final uri = Uri.tryParse(value);
              if (uri != null) onLink(uri);
            }
          })
          .catchError((_) {}),
    );
  }

  Future<void> publish(
    BoardsState s,
    DateTime now, {
    required bool vi,
    bool pro = false,
  }) async {
    if (!supported) return;
    final view = boardsHomeView(s, now, vi: vi);
    await feed.publish(view);
    for (final MapEntry(key: prefix, value: v) in boardsWidgetViews(
      s,
      now,
      vi: vi,
      pro: pro,
    ).entries) {
      await others[prefix]!.publish(v);
    }
    try {
      await channel.invokeMethod('publish', {...view.toData(), 'vi': vi});
    } on MissingPluginException {
      /* Host tests and unsupported OS adapters. */
    }
  }

  void dispose() {
    subscription?.cancel();
    channel.setMethodCallHandler(null);
  }
}
