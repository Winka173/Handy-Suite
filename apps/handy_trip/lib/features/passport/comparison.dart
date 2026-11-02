import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';

Future<void> showTripComparison(BuildContext context, TripScope scope) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => _Comparison(scope)));

class _Comparison extends StatefulWidget {
  final TripScope scope;
  const _Comparison(this.scope);
  @override
  State<_Comparison> createState() => _ComparisonState();
}

class _ComparisonState extends State<_Comparison> {
  final selected = <String>{};
  @override
  Widget build(BuildContext context) {
    final lifetime = LifetimeScope.maybeOf(context);
    final pro = lifetime?.pro == true,
        limit = pro ? 10 : 2,
        s = widget.scope.state;
    final rows = selected.length >= 2
        ? compareTrips(s, selected.toList())
        : <Json>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Compare trips', 'So sánh chuyến')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tr(
              context,
              'Select two trips. Amounts in different currencies remain separate; there is no FX conversion.',
              'Chọn hai chuyến. Tiền khác loại được giữ riêng; không quy đổi tỷ giá.',
            ),
          ),
          if (lifetime?.configured == true || pro)
            Text(
              tr(
                context,
                'Pro supports up to ten trips in one report.',
                'Pro hỗ trợ tối đa mười chuyến trong một báo cáo.',
              ),
            ),
          for (final trip in s.trips)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(trip.title),
              value: selected.contains(trip.key),
              onChanged:
                  !selected.contains(trip.key) && selected.length >= limit
                  ? null
                  : (v) => setState(
                      () => v == true
                          ? selected.add(trip.key)
                          : selected.remove(trip.key),
                    ),
            ),
          if (rows.isEmpty)
            Text(
              tr(
                context,
                'Select two saved trips to see a comparison.',
                'Chọn hai chuyến đã lưu để xem so sánh.',
              ),
            ),
          for (final row in rows) ...[
            const Divider(height: 32),
            Text(row['title'], style: Theme.of(context).textTheme.titleLarge),
            Text(
              '${row['days']} ${tr(context, 'calendar days', 'ngày lịch')} · ${row['visits']} ${tr(context, 'confirmed visits', 'lượt ghé xác nhận')} · ${row['uniquePlaces']} ${tr(context, 'unique places', 'địa điểm duy nhất')}',
            ),
            Text(
              '${tr(context, 'Budget', 'Ngân sách')}: ${formatFigure(context, amount(minorValue(row['budget']['minor']), row['budget']['currency']))} ${row['budget']['currency']}',
            ),
            for (final e in object(row['expenses']).entries)
              Text(
                '${tr(context, 'Actual', 'Đã chi')} ${e.key}: ${formatFigure(context, amount(minorValue(e.value), e.key))}',
              ),
            for (final e in object(row['estimates']).entries)
              Text(
                '${tr(context, 'Estimated', 'Dự kiến')} ${e.key}: ${formatFigure(context, amount(minorValue(e.value), e.key))}',
              ),
            Text(
              row['ratingCount'] == 0
                  ? tr(
                      context,
                      'No personal ratings',
                      'Chưa có đánh giá cá nhân',
                    )
                  : '${tr(context, 'Personal rating', 'Đánh giá cá nhân')}: ${(row['ratingSum'] / row['ratingCount']).toStringAsFixed(1)} / 5 (${row['ratingCount']})',
            ),
          ],
        ],
      ),
    );
  }
}
