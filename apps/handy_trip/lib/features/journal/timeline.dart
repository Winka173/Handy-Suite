import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../media/attachments.dart';
import '../checkins/editor.dart';
import 'editor.dart';

class TripTimeline extends StatefulWidget {
  final TripScope scope;
  final String? tripId;
  const TripTimeline({super.key, required this.scope, this.tripId});
  @override
  State<TripTimeline> createState() => _TimelineState();
}

class _TimelineState extends State<TripTimeline> {
  String? from, until, place, tripFilter;
  bool album = false;
  TripScope get scope => widget.scope;
  @override
  Widget build(BuildContext context) {
    final rows =
        <Entity>[...scope.state.visits, ...scope.state.notes].where((e) {
          final trip = e.ref('trip'),
              at = e.text('at'),
              d = localDay(DateTime.parse(at), e.text('zone'));
          return (widget.tripId == null || trip == widget.tripId) &&
              (tripFilter == null || trip == tripFilter) &&
              (from == null || d.compareTo(from!) >= 0) &&
              (until == null || d.compareTo(until!) <= 0) &&
              (place == null || e.data['place'] == place) &&
              scope.match(
                '${e.data['title'] ?? ''} ${e.data['body'] ?? e.data['note'] ?? ''} ${e is Visit ? scope.state.place(e.place).name : ''}',
              );
        }).toList()..sort(
          (a, b) => DateTime.parse(
            b.text('at'),
          ).compareTo(DateTime.parse(a.text('at'))),
        );
    void run(Future<void> Function() action) => scope.run(context, action);
    final pictures = <String>{for (final e in rows) ...e.list('assets')};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr(context, 'Travel memories', 'Kỷ niệm hành trình'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextField(
          decoration: InputDecoration(
            labelText: tr(
              context,
              'Search memory text / place',
              'Tìm nội dung kỷ niệm / địa điểm',
            ),
          ),
          onChanged: (v) => scope.update(() => scope.search = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => run(() => editNote(context, scope)),
              child: Text(tr(context, 'Add a memory', 'Thêm kỷ niệm')),
            ),
            TextButton(
              onPressed: () => run(() async {
                await tripForm(
                  context,
                  tr(context, 'Timeline filters', 'Lọc nhật ký'),
                  [
                    const TripField(
                      'from',
                      'From',
                      'Từ ngày',
                      kind: 'date',
                      optional: true,
                    ),
                    const TripField(
                      'until',
                      'Through',
                      'Đến hết ngày',
                      kind: 'date',
                      optional: true,
                    ),
                    TripField(
                      'place',
                      'Place',
                      'Địa điểm',
                      kind: 'choice',
                      optional: true,
                      choices: {
                        '': tr(context, 'All places', 'Tất cả địa điểm'),
                        for (final p in scope.state.places) p.key: p.name,
                      },
                    ),
                    if (widget.tripId == null)
                      TripField(
                        'trip',
                        'Trip',
                        'Chuyến đi',
                        kind: 'choice',
                        optional: true,
                        choices: {
                          '': tr(context, 'All trips', 'Tất cả chuyến'),
                          for (final t in scope.state.trips) t.key: t.title,
                        },
                      ),
                  ],
                  {
                    'from': from ?? '',
                    'until': until ?? '',
                    'place': place ?? '',
                    'trip': tripFilter ?? '',
                  },
                  (v) async {
                    final first = v['from'] as String?,
                        last = v['until'] as String?;
                    if (first?.isNotEmpty == true &&
                        last?.isNotEmpty == true &&
                        first!.compareTo(last!) > 0)
                      throw const FormatException('Invalid range');
                    setState(() {
                      from = first?.isEmpty == true ? null : first;
                      until = last?.isEmpty == true ? null : last;
                      place = v['place'] == '' ? null : v['place'];
                      tripFilter = v['trip'] == '' ? null : v['trip'];
                    });
                  },
                );
              }),
              child: Text(
                tr(
                  context,
                  'Date / trip / place filters',
                  'Lọc ngày / chuyến / địa điểm',
                ),
              ),
            ),
            FilterChip(
              label: Text(tr(context, 'Photo album', 'Album ảnh')),
              selected: album,
              onSelected: (v) => setState(() => album = v),
            ),
          ],
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr(
                context,
                'No memories in this view. A confirmed visit or your own note starts the timeline.',
                'Chưa có kỷ niệm trong mục này. Xác nhận lượt ghé hoặc thêm ghi chú để bắt đầu.',
              ),
            ),
          ),
        if (album)
          GridView.extent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final key in pictures.take(scope.page))
                Builder(
                  builder: (context) {
                    final a = scope.state.assets.firstWhere(
                      (a) => a.key == key,
                    );
                    return Tooltip(
                      message: a.text('caption').isEmpty
                          ? a.text('name')
                          : a.text('caption'),
                      child: InkWell(
                        onTap: () => run(
                          () => showAsset(
                            context,
                            scope,
                            key,
                            album: pictures.toList(),
                          ),
                        ),
                        child: Image.memory(
                          scope.state.files[a.data['preview'] ?? a.path]!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        if (!album)
          for (var i = 0; i < rows.length && i < scope.page; i++)
            Builder(
              builder: (context) {
                final e = rows[i],
                    d = localDay(DateTime.parse(e.text('at')), e.text('zone')),
                    first =
                        i == 0 ||
                        localDay(
                              DateTime.parse(rows[i - 1].text('at')),
                              rows[i - 1].text('zone'),
                            ).substring(0, 4) !=
                            d.substring(0, 4);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (first)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          d.substring(0, 4),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e is Visit
                            ? scope.state.place(e.place).name
                            : (e as JournalNote).title,
                      ),
                      subtitle: Text(
                        '$d · ${e.text('zone')}\n${e is Visit ? '${e.confirmed ? tr(context, 'Confirmed by you', 'Bạn đã xác nhận') : tr(context, 'Not confirmed', 'Chưa xác nhận')} · ${e.origin}' : (e as JournalNote).body}\n${e is Visit ? e.note : ''}',
                      ),
                      isThreeLine: true,
                      onTap: () => run(
                        () => e is Visit
                            ? editCheckIn(context, scope, old: e)
                            : editNote(context, scope, old: e as JournalNote),
                      ),
                      trailing: IconButton(
                        tooltip: tr(context, 'Delete memory', 'Xóa kỷ niệm'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => run(() async {
                          if (await tripConfirm(
                            context,
                            tr(
                              context,
                              'Remove this memory? Gallery originals remain unchanged. Undo is available until another action.',
                              'Gỡ kỷ niệm này? Bản gốc trong thư viện không đổi. Có thể hoàn tác trước thao tác tiếp theo.',
                            ),
                          ))
                            await scope.controller.change(
                              (s) => removeEntity(
                                s,
                                e is Visit ? 'visits' : 'notes',
                                e.key,
                              ),
                            );
                        }),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final key in e.list('assets').take(6))
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: InkWell(
                              onTap: () => run(
                                () => showAsset(
                                  context,
                                  scope,
                                  key,
                                  album: e.list('assets'),
                                ),
                              ),
                              child: Image.memory(
                                scope.state.files[scope.state.assets
                                        .firstWhere((a) => a.key == key)
                                        .data['preview'] ??
                                    scope.state.assets
                                        .firstWhere((a) => a.key == key)
                                        .path]!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, st) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
        if (rows.length > scope.page)
          TextButton(
            onPressed: () => scope.update(() => scope.page += 100),
            child: Text(tr(context, 'Load 100 more', 'Tải thêm 100')),
          ),
      ],
    );
  }
}
