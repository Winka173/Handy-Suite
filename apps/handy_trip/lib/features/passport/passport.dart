import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../places/place_view.dart';
import 'stamp_collection.dart';
import 'stamp_studio.dart';

class PassportPage extends StatefulWidget {
  final TripScope scope;
  const PassportPage({super.key, required this.scope});
  @override
  State<PassportPage> createState() => _PassportState();
}

class _PassportState extends State<PassportPage> {
  int? year;
  int limit = 100;
  @override
  Widget build(BuildContext context) {
    final s = widget.scope.state,
        years =
            s.visits
                .map(
                  (v) => DateTime.parse(
                    localDay(DateTime.parse(v.at), v.zone),
                  ).year,
                )
                .toSet()
                .toList()
              ..sort(),
        keys = uniquePlaces(s, year: year),
        visits = s.visits
            .where(
              (v) =>
                  v.confirmed &&
                  (year == null ||
                      DateTime.parse(
                            localDay(DateTime.parse(v.at), v.zone),
                          ).year ==
                          year),
            )
            .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tr(
            context,
            'Places you confirmed visiting',
            'Những nơi bạn xác nhận đã ghé',
          ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        DropdownButton<int?>(
          value: year,
          isExpanded: true,
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(tr(context, 'All years', 'Tất cả năm')),
            ),
            for (final y in years)
              DropdownMenuItem<int?>(value: y, child: Text('$y')),
          ],
          onChanged: (v) => setState(() {
            year = v;
            limit = 100;
          }),
        ),
        const SizedBox(height: 16),
        Text(
          '$visits ${tr(context, 'visits', 'lượt ghé')} · ${keys.length} ${tr(context, 'unique places', 'địa điểm duy nhất')}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        StampCollection(scope: widget.scope),
        const SizedBox(height: 24),
        Text(
          tr(
            context,
            'Planned places do not count. Geography is entered/confirmed by you; these are labels, not official administrative coverage or proof of GPS verification.',
            'Địa điểm dự kiến không được tính. Địa lý do bạn nhập/xác nhận; đây là nhãn, không phải độ phủ hành chính chính thức hay bằng chứng xác minh GPS.',
          ),
        ),
        for (final field in ['country', 'region', 'city']) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(
              field == 'country'
                  ? tr(context, 'Known country labels', 'Nhãn quốc gia đã biết')
                  : field == 'region'
                  ? tr(context, 'Known region labels', 'Nhãn vùng đã biết')
                  : tr(context, 'Known city labels', 'Nhãn thành phố đã biết'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (geography(s, field, year: year).isEmpty)
            Text(
              tr(
                context,
                'No confirmed labels yet',
                'Chưa có nhãn được xác nhận',
              ),
            ),
          for (final e in geography(s, field, year: year).entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.key),
              trailing: Text('${e.value} ${tr(context, 'places', 'địa điểm')}'),
            ),
        ],
        for (final key in keys.take(limit))
          Builder(
            builder: (context) {
              final memories =
                  s.visits
                      .where(
                        (v) =>
                            v.place == key &&
                            v.confirmed &&
                            (year == null ||
                                localTime(DateTime.parse(v.at), v.zone).year ==
                                    year),
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          DateTime.parse(b.at).compareTo(DateTime.parse(a.at)),
                    );
              final cover = memories
                  .expand((v) => v.assets)
                  .where(
                    (id) => s.assets.any(
                      (a) => a.key == id && a.mime.startsWith('image/'),
                    ),
                  )
                  .firstOrNull;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: cover == null
                    ? const Icon(Icons.place_outlined)
                    : SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.memory(
                          s.files[s.assets
                                  .firstWhere((a) => a.key == cover)
                                  .data['preview'] ??
                              s.assets.firstWhere((a) => a.key == cover).path]!,
                          fit: BoxFit.cover,
                        ),
                      ),
                title: Text(s.place(key).name),
                subtitle: Text(
                  '${memories.length} ${tr(context, 'confirmed visits', 'lượt ghé xác nhận')} · ${localDay(DateTime.parse(memories.first.at), memories.first.zone)}',
                ),
                trailing: IconButton(
                  tooltip: tr(
                    context,
                    'Personal memory stamp',
                    'D\u1ea5u k\u1ef7 ni\u1ec7m c\u00e1 nh\u00e2n',
                  ),
                  icon: const Icon(Icons.approval_outlined),
                  onPressed: () => openStampStudio(
                    context,
                    widget.scope,
                    memories.first.key,
                  ),
                ),
                onTap: () => widget.scope.run(
                  context,
                  () => showPlace(context, widget.scope, key),
                ),
              );
            },
          ),
        if (keys.length > limit)
          TextButton(
            onPressed: () => setState(() => limit += 100),
            child: Text(tr(context, 'Load 100 more', 'Tải thêm 100')),
          ),
      ],
    );
  }
}
