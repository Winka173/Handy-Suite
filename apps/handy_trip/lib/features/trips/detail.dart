import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../itinerary/editor.dart';
import '../places/place_view.dart';
import '../checkins/editor.dart';
import '../journal/editor.dart';
import '../journal/timeline.dart';
import '../bookings/editor.dart';
import '../packing/list.dart';
import '../expenses/editor.dart';
import '../media/attachments.dart';
import '../sharing/export_panel.dart';
import '../settings/settings.dart';
import 'editor.dart';
import 'replay.dart';
import '../sharing/memory_book.dart';

class TripDetail extends StatelessWidget {
  final TripScope scope;
  final String tripId;
  const TripDetail({super.key, required this.scope, required this.tripId});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope, scope.controller]),
    builder: (context, _) {
      final trip = scope.state.trips.where((t) => t.key == tripId).firstOrNull;
      if (trip == null)
        return Center(
          child: Text(
            tr(
              context,
              'Trip removed. Its visit memories remain in Journal.',
              'Đã xóa chuyến. Kỷ niệm lượt ghé vẫn còn trong Nhật ký.',
            ),
          ),
        );
      void run(Future<void> Function() work) => scope.run(context, work);
      final labels = [
        tr(context, 'Overview', 'Tổng quan'),
        tr(context, 'Itinerary', 'Lịch trình'),
        tr(context, 'Places', 'Địa điểm'),
        tr(context, 'Packing', 'Hành lý'),
        tr(context, 'Bookings', 'Đặt chỗ'),
        tr(context, 'Expenses', 'Chi tiêu'),
        tr(context, 'Journal', 'Nhật ký'),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '${trip.start} — ${trip.end} · ${trip.zone}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr(context, 'Trip actions', 'Thao tác chuyến'),
                  onSelected: (v) => run(() async {
                    if (!context.mounted) return;
                    if (v == 'edit') return editTrip(context, scope, trip);
                    if (v == 'export')
                      return showTripData(context, scope, tripId: trip.key);
                    if (v == 'memory-book')
                      return exportMemoryBook(context, scope, trip.key);
                    if (v == 'replay')
                      return showTripReplay(context, scope, trip.key);
                    if (v == 'duplicate') {
                      await tripForm(
                        context,
                        tr(
                          context,
                          'Duplicate safe trip template',
                          'Nhân bản mẫu chuyến an toàn',
                        ),
                        [
                          const TripField(
                            'start',
                            'First day for copy',
                            'Ngày bắt đầu bản sao',
                            kind: 'date',
                          ),
                        ],
                        {'start': trip.start},
                        (v) async {
                          await scope.controller.change(
                            (s) => duplicateTrip(s, trip.key, v['start']),
                          );
                        },
                      );
                    }
                    if (v == 'archive')
                      await scope.controller.change(
                        (s) => s.put(
                          'trips',
                          trip.copy({
                            'status': trip.status == 'archived'
                                ? 'planned'
                                : 'archived',
                          }),
                        ),
                      );
                    if (v == 'finish')
                      await scope.controller.change(
                        (s) =>
                            s.put('trips', trip.copy({'status': 'completed'})),
                      );
                    if (v == 'delete' &&
                        context.mounted &&
                        await tripConfirm(
                          context,
                          tr(
                            context,
                            'Delete trip plans, bookings, packing and expenses? Visits/photos/notes stay as spontaneous memories. Keep a backup first.',
                            'Xóa kế hoạch, đặt chỗ, hành lý và chi tiêu của chuyến? Lượt ghé/ảnh/ghi chú vẫn giữ thành kỷ niệm tự do. Hãy backup trước.',
                          ),
                        ))
                      await scope.controller.change(
                        (s) => removeEntity(s, 'trips', trip.key),
                      );
                  }),
                  itemBuilder: (context) => [
                    for (final (key, en, vi) in [
                      ('edit', 'Edit trip', 'Sửa chuyến'),
                      ('export', 'Export / backup', 'Xuất / backup'),
                      ('memory-book', 'Create memory book', 'Tạo sách kỷ niệm'),
                      (
                        'replay',
                        'Replay confirmed pins',
                        'Xem lại điểm đã ghé',
                      ),
                      (
                        'duplicate',
                        'Duplicate without history/secrets',
                        'Nhân bản không lịch sử/bí mật',
                      ),
                      ('finish', 'Mark trip completed', 'Đánh dấu kết thúc'),
                      ('archive', 'Archive / unarchive', 'Lưu trữ / khôi phục'),
                      ('delete', 'Delete trip plan', 'Xóa kế hoạch chuyến'),
                    ])
                      PopupMenuItem(
                        value: key,
                        child: Text(tr(context, en, vi)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(labels[i]),
                      selected: scope.section == i,
                      onSelected: (_) => scope.update(() => scope.section = i),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: scope.section == 6
                ? TripTimeline(scope: scope, tripId: trip.key)
                : _TripBody(scope: scope, trip: trip, section: scope.section),
          ),
        ],
      );
    },
  );
}

class _TripBody extends StatelessWidget {
  final TripScope scope;
  final Trip trip;
  final int section;
  const _TripBody({
    required this.scope,
    required this.trip,
    required this.section,
  });
  @override
  Widget build(BuildContext context) {
    final state = scope.state,
        expenses = expenseTotals(state, trip.key),
        spent = expenses[trip.currency] ?? BigInt.zero,
        pack = state.packing.where((p) => p.trip == trip.key).toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
        stops = state.stops.where((s) => s.trip == trip.key).toList(),
        bookings = state.bookings.where((b) => b.trip == trip.key).toList()
          ..sort(
            (a, b) =>
                DateTime.parse(a.start).compareTo(DateTime.parse(b.start)),
          );
    void run(Future<void> Function() work) => scope.run(context, work);
    // Timetable heads: small capitals over each part of the day.
    Widget title(String en, String vi) => HandyLabel(tr(context, en, vi));
    final children = <Widget>[];
    if (section == 0) {
      final today = localDay(scope.clock(), trip.zone),
          visits =
              state.visits
                  .where((v) => v.trip == trip.key && v.confirmed)
                  .toList()
                ..sort(
                  (a, b) =>
                      DateTime.parse(b.at).compareTo(DateTime.parse(a.at)),
                );
      if (trip.cover != null) {
        final a = state.assets.firstWhere((a) => a.key == trip.cover);
        children.add(
          SizedBox(
            height: 180,
            child: InkWell(
              onTap: () => run(() => showAsset(context, scope, a.key)),
              child: Image.memory(
                state.files[a.data['preview'] ?? a.path]!,
                fit: BoxFit.cover,
                errorBuilder: (_, e, st) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      }
      children.addAll([
        Text(trip.destination),
        Text(trip.text('description')),
        title('Today’s plan', 'Lịch hôm nay'),
        if (!stops.any((s) => s.on == today))
          Text(
            tr(
              context,
              'No planned stops today. Choose another day in Itinerary.',
              'Hôm nay chưa có điểm dừng. Chọn ngày khác trong Lịch trình.',
            ),
          ),
        for (final s in itinerary(state, trip.key, today).take(5))
          StopRow(scope: scope, stop: s),
        FilledButton.icon(
          onPressed: () => run(() => editStop(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(
            tr(context, 'Add stop / activity', 'Thêm điểm dừng / hoạt động'),
          ),
        ),
        title('Recent confirmed visits', 'Lượt ghé đã xác nhận gần đây'),
        Text(
          '${visits.length} ${tr(context, 'visits', 'lượt ghé')} · ${uniquePlaces(state, trip: trip.key).length} ${tr(context, 'unique places', 'địa điểm duy nhất')}',
        ),
        for (final v in visits.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(state.place(v.place).name),
            subtitle: Text(
              '${localDay(DateTime.parse(v.at), v.zone)} · ${v.origin}',
            ),
            onTap: () => run(() => editCheckIn(context, scope, old: v)),
          ),
        title('Packing progress', 'Tiến độ hành lý'),
        Text(
          '${pack.where((p) => p.packed).length} / ${pack.length} ${tr(context, 'checklist rows packed', 'dòng checklist đã xếp')}',
        ),
        LinearProgressIndicator(
          value: pack.isEmpty
              ? 0
              : pack.where((p) => p.packed).length / pack.length,
        ),
        title('Budget, whole trip', 'Ngân sách toàn chuyến'),
        // A ledger: labels left, figures right, what is left as the answer.
        HandyValueRows([
          (
            tr(context, 'Planned budget', 'Ngân sách dự kiến'),
            '${formatFigure(context, amount(trip.budget, trip.currency))} ${trip.currency}',
          ),
          (
            tr(context, 'Actual spending', 'Đã chi'),
            '${formatFigure(context, amount(spent, trip.currency))} ${trip.currency}',
          ),
          (
            tr(context, 'Remaining', 'Còn lại'),
            '${formatFigure(context, amount(trip.budget - spent, trip.currency))} ${trip.currency}',
          ),
        ], lead: 2),
        if (expenses.keys.any((k) => k != trip.currency))
          Text(
            tr(
              context,
              'Other currencies are separate; no exchange rates are inferred.',
              'Các tiền tệ khác được tính riêng; không tự suy đoán tỷ giá.',
            ),
          ),
        title('Upcoming bookings', 'Đặt chỗ sắp tới'),
        for (final b
            in bookings
                .where((b) => DateTime.parse(b.end).isAfter(scope.clock()))
                .take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(b.title),
            subtitle: Text(
              '${localDay(DateTime.parse(b.start), b.zone)} · ${b.maskedCode}',
            ),
            onTap: () => run(() => editBooking(context, scope, b)),
          ),
        title('Local reminder list', 'Danh sách nhắc cục bộ'),
        for (final alarm
            in (state.alarms
                    .where((a) => a.trip == trip.key && a.enabled)
                    .toList()
                  ..sort(
                    (a, b) =>
                        DateTime.parse(a.at).compareTo(DateTime.parse(b.at)),
                  ))
                .take(10))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${localDay(DateTime.parse(alarm.at), alarm.zone)} · ${alarm.zone}',
            ),
            subtitle: Text(alarm.at),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => run(
                () => scope.controller.change(
                  (s) => v == 'snooze'
                      ? s.put(
                          'alarms',
                          alarm.copy({
                            'at': scope
                                .clock()
                                .toUtc()
                                .add(const Duration(minutes: 10))
                                .toIso8601String(),
                          }),
                        )
                      : s.copy({
                          'alarms': s.alarms
                              .where((a) => a.key != alarm.key)
                              .map((a) => a.toJson())
                              .toList(),
                        }),
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'snooze',
                  child: Text(
                    tr(context, 'Snooze 10 minutes', 'Nhắc lại sau 10 phút'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(tr(context, 'Cancel reminder', 'Hủy nhắc')),
                ),
              ],
            ),
          ),
      ]);
    } else if (section == 1) {
      final on = trip.days.contains(scope.selectedDay)
              ? scope.selectedDay!
              : trip.days.contains(scope.today)
              ? scope.today
              : trip.start,
          items = itinerary(state, trip.key, on),
          warnings = overlaps(state, trip.key);
      children.addAll([
        title(
          'Day ${trip.days.indexOf(on) + 1} · $on',
          'Ngày ${trip.days.indexOf(on) + 1} · $on',
        ),
        DropdownButton<String>(
          value: on,
          isExpanded: true,
          items: [
            for (final d in trip.days)
              DropdownMenuItem(value: d, child: Text(d)),
          ],
          onChanged: (v) => scope.update(() => scope.selectedDay = v),
        ),
        if (warnings.isNotEmpty)
          Text(
            '${warnings.length} ${tr(context, 'schedule overlaps across this trip. Review times; saving is allowed.', 'lịch trùng trong chuyến. Kiểm tra giờ; vẫn có thể lưu.')}',
          ),
        TextButton.icon(
          onPressed: () => run(() => editStop(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(
            tr(context, 'Add activity on this day', 'Thêm hoạt động ngày này'),
          ),
        ),
        if (items.isEmpty)
          Text(
            tr(
              context,
              'No stops on this day. Time fields are optional.',
              'Chưa có điểm dừng ngày này. Giờ không bắt buộc.',
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          onReorderItem: (a, b) => run(
            () => scope.controller.change((s) {
              final keys = itinerary(
                    s,
                    trip.key,
                    on,
                  ).map((s) => s.key).toList(),
                  key = keys.removeAt(a);
              keys.insert(b, key);
              return reorderStops(s, trip.key, on, keys);
            }),
          ),
          itemBuilder: (context, i) =>
              StopRow(key: Key(items[i].key), scope: scope, stop: items[i]),
        ),
      ]);
    } else if (section == 2) {
      final keys = {
        ...stops.map((s) => s.place).whereType<String>(),
        ...state.visits.where((v) => v.trip == trip.key).map((v) => v.place),
      };
      children.addAll([
        title('Places linked to this trip', 'Địa điểm gắn với chuyến này'),
        if (keys.isEmpty)
          Text(
            tr(
              context,
              'Save a place in Explore, then add it to a day.',
              'Lưu địa điểm trong mục Địa điểm rồi thêm vào ngày đi.',
            ),
          ),
        for (final key in keys)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(state.place(key).name),
            subtitle: Text(state.place(key).address),
            onTap: () => run(() => showPlace(context, scope, key)),
          ),
      ]);
    } else if (section == 3) {
      return PackingView(scope: scope, trip: trip);
    } else if (section == 4) {
      children.addAll([
        Text(
          tr(
            context,
            'Codes stay masked here. Open an editor to view your private confirmation. Booking costs are informational; expenses are entered separately.',
            'Mã được che ở đây. Mở phần sửa để xem mã riêng. Giá đặt chỗ chỉ để tham khảo; chi tiêu được ghi riêng.',
          ),
        ),
        TextButton.icon(
          onPressed: () => run(() => editBooking(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'Add booking', 'Thêm đặt chỗ')),
        ),
        for (final b in bookings)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(b.title),
            subtitle: Text(
              '${b.type} · ${localDay(DateTime.parse(b.start), b.zone)} · ${b.maskedCode}',
            ),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => run(() => editBooking(context, scope, b)),
                    child: Text(
                      tr(
                        context,
                        'Edit / view private code',
                        'Sửa / xem mã riêng',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => run(
                      () =>
                          editAlarm(context, scope, 'booking', b.key, trip.key),
                    ),
                    child: Text(tr(context, 'Reminder', 'Nhắc')),
                  ),
                  TextButton(
                    onPressed: () => run(() async {
                      if (await tripConfirm(
                        context,
                        tr(
                          context,
                          'Delete this booking record? Original gallery/files are not deleted.',
                          'Xóa bản ghi đặt chỗ này? Không xóa ảnh/tệp gốc.',
                        ),
                      ))
                        await scope.controller.change(
                          (s) => removeEntity(s, 'bookings', b.key),
                        );
                    }),
                    child: Text(tr(context, 'Delete booking', 'Xóa đặt chỗ')),
                  ),
                ],
              ),
              for (final key in b.list('assets'))
                ListTile(
                  title: Text(
                    state.assets.firstWhere((a) => a.key == key).text('name'),
                  ),
                  onTap: () => run(() => showAsset(context, scope, key)),
                ),
            ],
          ),
      ]);
    } else if (section == 5) {
      final estimates = estimateTotals(state, trip.key);
      children.addAll([
        HandyValueRows([
          for (final e in estimates.entries)
            (
              tr(context, 'Estimated stops', 'Chi phí dự kiến'),
              '${formatFigure(context, amount(e.value, e.key))} ${e.key}',
            ),
          for (final e in expenses.entries)
            (
              tr(context, 'Spent', 'Đã chi'),
              '${formatFigure(context, amount(e.value, e.key))} ${e.key}',
            ),
          (
            tr(context, 'Budget remaining', 'Ngân sách còn lại'),
            '${formatFigure(context, amount(trip.budget - spent, trip.currency))} ${trip.currency}',
          ),
        ], lead: estimates.length + expenses.length),
        Text(
          tr(
            context,
            'Booking prices and stop estimates are not charged automatically. No FX conversion, split payments or Spend sync.',
            'Giá booking và dự toán điểm dừng không tự cộng vào chi tiêu. Không quy đổi tỷ giá, chia tiền hay đồng bộ Spend.',
          ),
        ),
        TextButton.icon(
          onPressed: () => run(() => editExpense(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'Record expense', 'Ghi chi tiêu')),
        ),
        for (final e in state.expenses.where((e) => e.trip == trip.key))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              e.text('description').isEmpty
                  ? e.category
                  : e.text('description'),
            ),
            subtitle: Text('${e.category} · ${e.text('payer')}'),
            trailing: Text(
              '${formatFigure(context, amount(e.minor, e.currency))} ${e.currency}',
              style: const TextStyle(fontFeatures: tabular),
            ),
            onTap: () => run(() => editExpense(context, scope, e)),
            onLongPress: () => run(() async {
              if (await tripConfirm(
                context,
                tr(
                  context,
                  'Delete this expense? Only this Trip record changes; no other app is updated.',
                  'Xóa khoản chi này? Chỉ đổi bản ghi Trip; không cập nhật app khác.',
                ),
              ))
                await scope.controller.change(
                  (s) => removeEntity(s, 'expenses', e.key),
                );
            }),
          ),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }
}

class StopRow extends StatelessWidget {
  final TripScope scope;
  final Stop stop;
  const StopRow({super.key, required this.scope, required this.stop});
  @override
  Widget build(BuildContext context) {
    final confirmed = scope.state.visits.any(
      (v) => v.confirmed && v.stop == stop.key,
    );
    void run(Future<void> Function() work) => scope.run(context, work);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: MediaQuery.textScalerOf(context).scale(12) > 18
          ? Icon(
              confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
            )
          : SizedBox(
              width: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    confirmed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 16,
                    // The hue marks what was confirmed, nothing else.
                    color: confirmed
                        ? HandyColors.of(context).accent
                        : Theme.of(context).colorScheme.outline,
                  ),
                  Text(
                    stop.time ?? '—',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
      title: Text(
        MediaQuery.textScalerOf(context).scale(12) > 18 && stop.time != null
            ? '${stop.time} · ${stop.title}'
            : stop.title,
      ),
      subtitle: Text(
        confirmed
            ? tr(context, 'Confirmed visit', 'Lượt ghé đã xác nhận')
            : stop.status == 'visited'
            ? tr(
                context,
                'Activity marked complete (no visit record)',
                'Hoạt động hoàn thành (không phải lượt ghé)',
              )
            : stop.status == 'skipped'
            ? tr(context, 'Skipped', 'Đã bỏ qua')
            : tr(context, 'Planned', 'Dự kiến'),
      ),
      onTap: () => run(() => editStop(context, scope, old: stop)),
      trailing: PopupMenuButton<String>(
        tooltip: tr(context, 'Activity actions', 'Thao tác hoạt động'),
        onSelected: (action) => run(() async {
          if (!context.mounted) return;
          if (action == 'checkin' || action == 'gps')
            return editCheckIn(
              context,
              scope,
              stop: stop,
              gps: action == 'gps',
            );
          if (action == 'note') return editNote(context, scope, stop: stop.key);
          if (action == 'remind')
            return editAlarm(context, scope, 'stop', stop.key, stop.trip);
          if (['skip', 'planned', 'done'].contains(action)) {
            if (confirmed)
              throw const FormatException('Edit/unconfirm the check-in first');
            await scope.controller.change(
              (s) => s.put(
                'stops',
                stop.copy({
                  'status': action == 'skip'
                      ? 'skipped'
                      : action == 'done'
                      ? 'visited'
                      : 'planned',
                  'manualComplete': action == 'done',
                }),
              ),
            );
          }
          if (action == 'delete' &&
              context.mounted &&
              await tripConfirm(
                context,
                tr(
                  context,
                  'Delete the stop? Existing visit memories will keep their place and become unlinked from this stop.',
                  'Xóa điểm dừng? Kỷ niệm đã ghi giữ địa điểm và được gỡ liên kết khỏi điểm dừng này.',
                ),
              ))
            await scope.controller.change(
              (s) => removeEntity(s, 'stops', stop.key),
            );
        }),
        itemBuilder: (context) => [
          for (final (key, en, vi) in [
            ('checkin', 'Manual check-in', 'Ghi nhận thủ công'),
            ('gps', 'GPS check-in', 'Ghi nhận GPS'),
            if (stop.place == null)
              ('done', 'Complete activity', 'Hoàn thành hoạt động'),
            ('skip', 'Skip', 'Bỏ qua'),
            ('planned', 'Mark planned', 'Đặt lại dự kiến'),
            ('note', 'Add memory note', 'Thêm ghi chú kỷ niệm'),
            ('remind', 'Add reminder', 'Thêm nhắc'),
            ('delete', 'Delete stop', 'Xóa điểm dừng'),
          ])
            PopupMenuItem(value: key, child: Text(tr(context, en, vi))),
        ],
      ),
    );
  }
}
