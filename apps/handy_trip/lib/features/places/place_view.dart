import 'package:url_launcher/url_launcher.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../itinerary/editor.dart';
import '../checkins/editor.dart';
import 'editor.dart';

class ExplorePage extends StatefulWidget {
  final TripScope scope;
  const ExplorePage({super.key, required this.scope});
  @override
  State<ExplorePage> createState() => _ExploreState();
}

class _ExploreState extends State<ExplorePage> {
  String filter = 'saved';
  TripScope get scope => widget.scope;
  @override
  Widget build(BuildContext context) {
    final visited = uniquePlaces(scope.state), counts = <String, int>{};
    for (final v in scope.state.visits.where((v) => v.confirmed))
      counts[v.place] = (counts[v.place] ?? 0) + 1;
    final places = scope.state.places
        .where(
          (p) =>
              (filter == 'saved' ||
                  filter == 'wishlist' && p.wishlist ||
                  filter == 'visited' && visited.contains(p.key)) &&
              scope.match(
                '${p.name} ${p.text('note')} ${p.list('tags').join(' ')} ${p.text('country')} ${p.text('region')}',
              ),
        )
        .toList();
    void run(Future<void> Function() action) => scope.run(context, action);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Search saved places, tags and notes',
              'Tìm địa điểm, nhãn và ghi chú',
            ),
          ),
          onChanged: (v) => scope.update(() => scope.search = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (key, en, vi) in [
              ('saved', 'Saved', 'Đã lưu'),
              ('wishlist', 'Wishlist', 'Muốn đến'),
              ('visited', 'Visited', 'Đã ghé'),
            ])
              ChoiceChip(
                label: Text(tr(context, en, vi)),
                selected: filter == key,
                onSelected: (_) => setState(() => filter = key),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => run(() async {
                await editPlace(context, scope);
              }),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Save a place', 'Lưu địa điểm')),
            ),
            TextButton(
              onPressed: () => run(() => pastePlace(context, scope)),
              child: Text(tr(context, 'Paste source link', 'Dán link nguồn')),
            ),
          ],
        ),
        Text(
          tr(
            context,
            'Offline pin list. No basemap, geocoding or automatic visit inference. External maps may need internet.',
            'Danh sách tọa độ offline. Không có bản đồ nền, tra cứu địa chỉ hay tự suy đoán đã ghé. Bản đồ ngoài có thể cần mạng.',
          ),
        ),
        if (places.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr(
                context,
                'No places in this view. Save a name or source link; coordinates are optional.',
                'Chưa có địa điểm trong mục này. Lưu tên hoặc link nguồn; tọa độ không bắt buộc.',
              ),
            ),
          ),
        for (final p in places.take(scope.page))
          ListTile(
            leading: HandyDot(p.key.codeUnits.fold(0, (a, b) => a + b) % 8),
            title: Text(p.name),
            subtitle: Text(
              '${counts[p.key] ?? 0} ${tr(context, 'confirmed visits', 'lượt ghé đã xác nhận')}\n${p.geo == null ? tr(context, 'No coordinates', 'Chưa có tọa độ') : '${p.geo!.lat.toStringAsFixed(5)}, ${p.geo!.lon.toStringAsFixed(5)}'}',
            ),
            isThreeLine: true,
            onTap: () => run(() => showPlace(context, scope, p.key)),
          ),
        if (places.length > scope.page)
          TextButton(
            onPressed: () => scope.update(() => scope.page += 100),
            child: Text(tr(context, 'Load 100 more', 'Tải thêm 100')),
          ),
      ],
    );
  }
}

Future<void> showPlace(
  BuildContext context,
  TripScope scope,
  String key,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => ListenableBuilder(
      listenable: scope.controller,
      builder: (context, _) {
        final p = scope.state.places.where((p) => p.key == key).firstOrNull;
        if (p == null)
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(tr(context, 'Place removed', 'Đã xóa địa điểm')),
            ),
          );
        void run(Future<void> Function() action) => scope.run(context, action);
        return Scaffold(
          appBar: AppBar(title: Text(p.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(p.address),
              Text(
                '${p.text('country')} · ${p.text('region')} · ${p.text('city')}',
              ),
              if (p.geo != null) Text('${p.geo!.lat}, ${p.geo!.lon}'),
              Text(p.text('note')),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('place-visited-now'),
                    onPressed: () =>
                        run(() => quickCheckIn(context, scope, place: p)),
                    icon: const Icon(Icons.where_to_vote_outlined),
                    label: Text(tr(context, "I'm here now", 'Đã ghé, bây giờ')),
                  ),
                  TextButton(
                    key: const Key('place-visit-details'),
                    onPressed: () =>
                        run(() => editCheckIn(context, scope, place: p)),
                    child: Text(
                      tr(context, 'Visit with details', 'Ghi kèm chi tiết'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => run(
                      () => editCheckIn(context, scope, place: p, gps: true),
                    ),
                    child: Text(
                      tr(context, 'Use current GPS', 'Lấy GPS hiện tại'),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        run(() => editStop(context, scope, place: p)),
                    child: Text(
                      tr(context, 'Add to trip day', 'Thêm vào ngày đi'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => run(
                      () => editPlace(context, scope, old: p).then((_) {}),
                    ),
                    child: Text(tr(context, 'Edit place', 'Sửa địa điểm')),
                  ),
                  if (p.geo != null || p.address.trim().isNotEmpty)
                    TextButton(
                      onPressed: () => run(() async {
                        if (!await tripConfirm(
                          context,
                          tr(
                            context,
                            'Open an external map with this explicit coordinate/address?',
                            'Mở bản đồ ngoài với tọa độ/địa chỉ đã nhập?',
                          ),
                        ))
                          return;
                        if (!await launchUrl(
                          scope.map.navigation(p),
                          mode: LaunchMode.externalApplication,
                        ))
                          throw StateError('No external map handler');
                      }),
                      child: Text(
                        tr(context, 'Open external map', 'Mở bản đồ ngoài'),
                      ),
                    ),
                  if (p.url != null)
                    TextButton(
                      onPressed: () => run(() async {
                        if (!await launchUrl(
                          Uri.parse(p.url!),
                          mode: LaunchMode.externalApplication,
                        ))
                          throw StateError('No URL handler');
                      }),
                      child: Text(
                        tr(context, 'Open source link', 'Mở link nguồn'),
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => run(
                  () => scope.controller.change(
                    (s) => s.put('places', p.copy({'favorite': !p.favorite})),
                  ),
                ),
                child: Text(
                  p.favorite
                      ? tr(context, 'Remove favorite', 'Bỏ yêu thích')
                      : tr(context, 'Favorite', 'Yêu thích'),
                ),
              ),
              TextButton(
                onPressed: () => run(() async {
                  if (await tripConfirm(
                    context,
                    tr(
                      context,
                      'Delete this place only if no stop or visit references it?',
                      'Xóa địa điểm nếu không còn điểm dừng hay lượt ghé tham chiếu?',
                    ),
                  ))
                    await scope.controller.change(
                      (s) => removeEntity(s, 'places', p.key),
                    );
                }),
                child: Text(
                  tr(
                    context,
                    'Delete unreferenced place',
                    'Xóa địa điểm chưa được dùng',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),
);
