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

class BoardsHomeSurface {
  static const channel = MethodChannel('handy.boards/home');
  final feed = HomeWidgetFeed(
    'com.example.handysuite.handy_boards.HandyWidget',
  );
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

  Future<void> publish(BoardsState s, DateTime now, {required bool vi}) async {
    if (!supported) return;
    final view = boardsHomeView(s, now, vi: vi);
    await feed.publish(view);
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
