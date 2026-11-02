import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// What an app's home-screen widget shows: its one question answered.
/// The native side (`HandyWidget.kt`) only draws these strings.
class HomeWidgetView {
  final String title, value, detail;

  /// Opened when the widget is tapped, e.g. `handy-spend://today`.
  final String uri;

  /// Up to three tappable lines below, each with its own link.
  final List<(String text, String uri)> rows;
  const HomeWidgetView({
    required this.title,
    required this.value,
    this.detail = '',
    required this.uri,
    this.rows = const [],
  });

  Map<String, String?> toData() => {
    'title': title,
    'value': value,
    'detail': detail,
    'uri': uri,
    for (var i = 0; i < 3; i++) ...{
      'row${i}_text': i < rows.length ? rows[i].$1 : null,
      'row${i}_uri': i < rows.length ? rows[i].$2 : null,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetView && mapEquals(other.toData(), toData());
  @override
  int get hashCode => Object.hashAll(toData().values);
}

bool get homeWidgetsSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Sends [view] to the widget named [androidClass] (fully qualified, since
/// debug builds change the package name). Never throws: a widget that cannot
/// update must not break the app.
class HomeWidgetFeed {
  final String androidClass;
  HomeWidgetView? _last;
  HomeWidgetFeed(this.androidClass);

  Future<void> publish(HomeWidgetView view) async {
    if (!homeWidgetsSupported || view == _last) return;
    _last = view;
    try {
      for (final e in view.toData().entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: androidClass);
    } catch (_) {
      _last = null;
    }
  }

  /// Links from widget taps: the one that opened the app, then later ones.
  Stream<Uri> links() async* {
    if (!homeWidgetsSupported) return;
    // No widget plugin (a host test posing as Android): no links.
    Uri? first;
    try {
      first = await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return;
    }
    if (first != null) yield first;
    await for (final uri in HomeWidget.widgetClicked.handleError((_) {})) {
      if (uri != null) yield uri;
    }
  }
}
