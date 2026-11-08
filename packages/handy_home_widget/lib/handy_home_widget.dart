import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// What an app's home-screen widget shows: its one question answered.
/// The native side (`HandyWidget.kt`) only draws these strings.
class HomeWidgetView {
  final String title, value, detail;

  /// Opened when the widget is tapped, e.g. `handy-spend://today`.
  final String uri;

  /// Tappable lines below, each with its own link (three by default; a
  /// layout with more rows sets [maxRows]).
  final List<(String text, String uri)> rows;
  final int maxRows;

  /// A progress bar, 0–100, for layouts that have one.
  final int? progress;

  /// Colours for the native side, ARGB hex: `bg`, `ink`, `muted`, `accent`.
  /// Null keeps the widget's own light/dark theme.
  final Map<String, String>? style;
  const HomeWidgetView({
    required this.title,
    required this.value,
    this.detail = '',
    required this.uri,
    this.rows = const [],
    this.maxRows = 3,
    this.progress,
    this.style,
  });

  HomeWidgetView styled(Map<String, String>? style) => HomeWidgetView(
    title: title,
    value: value,
    detail: detail,
    uri: uri,
    rows: rows,
    maxRows: maxRows,
    progress: progress,
    style: style,
  );

  Map<String, String?> toData() => {
    'title': title,
    'value': value,
    'detail': detail,
    'uri': uri,
    if (progress != null) 'progress': '${progress!.clamp(0, 100)}',
    for (final k in const ['bg', 'ink', 'muted', 'accent'])
      'style_$k': style?[k],
    for (var i = 0; i < maxRows; i++) ...{
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

  /// Prefixed keys let one app feed several widgets (`progress_title`...).
  final String prefix;
  HomeWidgetView? _last;
  HomeWidgetFeed(this.androidClass, {this.prefix = ''});

  Future<void> publish(HomeWidgetView view) async {
    if (!homeWidgetsSupported || view == _last) return;
    _last = view;
    try {
      for (final e in view.toData().entries) {
        await HomeWidget.saveWidgetData<String>('$prefix${e.key}', e.value);
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
