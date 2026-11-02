import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../features/trips/editor.dart';
import '../features/trips/detail.dart';
import '../features/places/editor.dart';
import '../features/places/place_view.dart';
import '../features/journal/timeline.dart';
import '../features/journal/editor.dart';
import '../features/checkins/editor.dart';
import '../features/settings/settings.dart';
import '../features/passport/passport.dart';
import '../platform/share_inbox.dart';

class TripShell extends StatefulWidget {
  final TripScope scope;
  final int initialArea;
  const TripShell({super.key, required this.scope, this.initialArea = 0});
  @override
  State<TripShell> createState() => _ShellState();
}

class _ShellState extends State<TripShell> with WidgetsBindingObserver {
  final inbox = TripShareInbox();
  List<TripShare> shared = [];
  bool shareError = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inbox.listen(() => unawaited(refreshShares()));
    unawaited(refreshShares());
  }

  Future<void> refreshShares() async {
    try {
      final rows = await inbox.pending();
      if (mounted)
        setState(() {
          shared = rows;
          shareError = false;
        });
    } catch (_) {
      if (mounted) setState(() => shareError = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshShares());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    inbox.dispose();
    super.dispose();
  }

  Future<void> reviewShare() async {
    if (shared.isEmpty) {
      await refreshShares();
      return;
    }
    final item = shared.first;
    final alreadySaved = scope.state.places.any(
      (p) => p.data['shareId'] == item.id,
    );
    if (!alreadySaved) {
      final raw = RegExp(r'https?://[^\s<>]+').firstMatch(item.text)?.group(0);
      final saved = await editPlace(
        context,
        scope,
        url: raw,
        name:
            item.title ??
            (raw == null && item.text.length <= 300 ? item.text : null),
        note: item.text.length <= 10000 ? item.text : null,
        shareId: item.id,
      );
      if (saved == null) return;
    }
    await inbox.acknowledge(item.id);
    await refreshShares();
  }

  TripScope get scope => widget.scope;
  late int area = widget.initialArea;
  void run(Future<void> Function() action) =>
      unawaited(scope.run(context, action));
  void select(int n) {
    if (n == area) return;
    if (kIsWeb) {
      unawaited(
        Navigator.of(
          context,
        ).pushNamed<void>(['/', '/explore', '/journal', '/passport'][n]),
      );
    } else {
      setState(() => area = n);
      scope.area = n;
      scope.search = '';
    }
  }

  Future<void> add() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (en, vi, action)
                in <(String, String, Future<void> Function())>[
                  (
                    'New trip',
                    'Chuyến đi mới',
                    () => editTrip(this.context, scope),
                  ),
                  (
                    'Save a place',
                    'Lưu địa điểm',
                    () async {
                      await editPlace(this.context, scope);
                    },
                  ),
                  (
                    'Manual check-in',
                    'Ghi nhận ghé thăm thủ công',
                    () => editCheckIn(this.context, scope),
                  ),
                  (
                    'GPS check-in',
                    'Ghi nhận bằng GPS',
                    () => editCheckIn(this.context, scope, gps: true),
                  ),
                  (
                    'Add a memory',
                    'Thêm kỷ niệm',
                    () => editNote(this.context, scope),
                  ),
                ])
              ListTile(
                title: Text(tr(context, en, vi)),
                onTap: () {
                  Navigator.pop(context);
                  run(action);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope, scope.controller]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, bounds) {
        final wide = bounds.maxWidth >= 1024,
            labels = [
              tr(context, 'Trips', 'Chuyến đi'),
              tr(context, 'Explore', 'Địa điểm'),
              tr(context, 'Journal', 'Nhật ký'),
              tr(context, 'Passport', 'Hộ chiếu'),
            ],
            icons = [
              Icons.luggage_outlined,
              Icons.place_outlined,
              Icons.book_outlined,
              Icons.public_outlined,
            ];
        Widget content;
        if (scope.state.settings['onboarded'] != true) {
          content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Handy Trip',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      context,
                      'Plan. Visit. Remember. Your saved trips and photos stay on this device. No account, cloud sync or AI.',
                      'Lên lịch. Ghé thăm. Lưu kỷ niệm. Chuyến đi và ảnh đã lưu ở trên thiết bị này. Không tài khoản, cloud sync hay AI.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      context,
                      'Manual check-in works without GPS. A saved place never counts as visited until you confirm. Browser storage may be cleared: keep private backups.',
                      'Ghi nhận thủ công không cần GPS. Địa điểm đã lưu chỉ được tính đã ghé khi bạn xác nhận. Trình duyệt có thể xóa dữ liệu: hãy sao lưu riêng tư.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: scope.controller.busy
                        ? null
                        : () => run(
                            () => scope.controller.change(
                              (s) => s.copy({
                                'settings': {...s.settings, 'onboarded': true},
                              }),
                            ),
                          ),
                    child: Text(
                      tr(
                        context,
                        'Start without sample data',
                        'Bắt đầu với dữ liệu trống',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else
          content = switch (area) {
            0 => _trips(wide),
            1 => ExplorePage(scope: scope),
            2 => TripTimeline(scope: scope),
            _ => PassportPage(scope: scope),
          };
        return Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                const _Add(),
          },
          child: Actions(
            actions: {
              _Add: CallbackAction<_Add>(
                onInvoke: (_) {
                  run(add);
                  return null;
                },
              ),
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  'Handy Trip · ${labels[area]}',
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    tooltip: tr(context, 'Undo', 'Hoàn tác'),
                    onPressed:
                        scope.controller.canUndo && !scope.controller.busy
                        ? () => run(scope.controller.undo)
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    key: const Key('trip-add'),
                    tooltip: tr(context, 'Add', 'Thêm'),
                    onPressed: scope.controller.busy ? null : () => run(add),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: tr(context, 'Settings', 'Cài đặt'),
                    onPressed: () =>
                        run(() => showTripSettings(context, scope)),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              body: Row(
                children: [
                  if (wide && scope.state.settings['onboarded'] == true)
                    NavigationRail(
                      selectedIndex: area,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: select,
                      destinations: [
                        for (var i = 0; i < 4; i++)
                          NavigationRailDestination(
                            icon: Icon(icons[i]),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (shared.isNotEmpty || shareError)
                          ListTile(
                            title: Text(
                              shareError
                                  ? tr(
                                      context,
                                      'Shared inbox unavailable; retry',
                                      'Chưa đọc được hộp nhận; thử lại',
                                    )
                                  : tr(
                                      context,
                                      '${shared.length} shared links/text to review',
                                      '${shared.length} link/văn bản chờ xác nhận',
                                    ),
                            ),
                            subtitle: Text(
                              tr(
                                context,
                                'Nothing is marked visited automatically.',
                                'Không tự đánh dấu đã ghé thăm.',
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: () => run(reviewShare),
                              child: Text(tr(context, 'Review', 'Xem lại')),
                            ),
                          ),
                        Expanded(child: content),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar:
                  wide || scope.state.settings['onboarded'] != true
                  ? null
                  : NavigationBar(
                      selectedIndex: area,
                      onDestinationSelected: select,
                      destinations: [
                        for (var i = 0; i < 4; i++)
                          NavigationDestination(
                            icon: Icon(icons[i]),
                            label: labels[i],
                          ),
                      ],
                    ),
            ),
          ),
        );
      },
    ),
  );
  Widget _trips(bool wide) {
    final trips =
        scope.state.trips
            .where(
              (t) => scope.match('${t.title} ${t.destination} ${t.status}'),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final list = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('trip-search'),
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Search trips / status',
              'Tìm chuyến đi / trạng thái',
            ),
          ),
          onChanged: (v) => scope.update(() => scope.search = v),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => run(() => editTrip(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'New trip', 'Chuyến đi mới')),
        ),
        if (trips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr(
                context,
                'No trips here. Create one with dates and a timezone.',
                'Chưa có chuyến đi. Tạo chuyến với ngày và múi giờ.',
              ),
            ),
          ),
        for (final t in trips.take(scope.page))
          ListTile(
            key: Key('trip-${t.key}'),
            contentPadding: EdgeInsets.zero,
            selected: scope.selectedTrip == t.key,
            title: Text(t.title),
            subtitle: Text(
              '${t.start} — ${t.end}\n${t.destination} · ${t.status}',
            ),
            isThreeLine: true,
            onTap: () {
              scope.chooseTrip(t.key);
              if (!wide)
                run(
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(
                          title: Text(
                            tr(context, 'Travel daybook', 'Sổ hành trình'),
                          ),
                        ),
                        body: TripDetail(scope: scope, tripId: t.key),
                      ),
                    ),
                  ),
                );
            },
          ),
        if (trips.length > scope.page)
          TextButton(
            onPressed: () => scope.update(() => scope.page += 100),
            child: Text(tr(context, 'Load 100 more', 'Tải thêm 100')),
          ),
      ],
    );
    if (!wide) return list;
    return Row(
      children: [
        SizedBox(width: 300, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: scope.trip == null
              ? Center(
                  child: Text(
                    tr(
                      context,
                      'Choose a trip to open its daybook.',
                      'Chọn chuyến đi để mở sổ hành trình.',
                    ),
                  ),
                )
              : TripDetail(scope: scope, tripId: scope.trip!.key),
        ),
      ],
    );
  }
}

class _Add extends Intent {
  const _Add();
}
