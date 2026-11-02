import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import '../settings/settings.dart';
import 'editor.dart';

class PackingView extends StatelessWidget {
  final TripScope scope;
  final Trip trip;
  const PackingView({super.key, required this.scope, required this.trip});
  @override
  Widget build(BuildContext context) {
    final rows = scope.state.packing.where((p) => p.trip == trip.key).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    void run(Future<void> Function() action) => scope.run(context, action);
    Future<void> reorder(int from, int to) => scope.controller.change((s) {
      final ordered = s.packing.where((p) => p.trip == trip.key).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final item = ordered.removeAt(from);
      ordered.insert(to, item);
      final byId = {for (var i = 0; i < ordered.length; i++) ordered[i].key: i};
      return s.copy({
        'packing': s.packing
            .map(
              (p) => p.trip == trip.key
                  ? p.copy({'order': byId[p.key]}).toJson()
                  : p.toJson(),
            )
            .toList(),
      });
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextButton.icon(
          onPressed: () => run(() => editPacking(context, scope)),
          icon: const Icon(Icons.add),
          label: Text(tr(context, 'Add packing item', 'Thêm đồ cần mang')),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (kind, en, vi) in [
              ('weekend', 'Weekend template', 'Mẫu cuối tuần'),
              ('beach', 'Beach template', 'Mẫu đi biển'),
              ('business', 'Business template', 'Mẫu công tác'),
              ('hiking', 'Hiking template', 'Mẫu đi bộ đường dài'),
            ])
              TextButton(
                onPressed: () => run(
                  () => scope.controller.change(
                    (s) => s.copy({
                      'packing': [
                        ...s.packing.map((p) => p.toJson()),
                        ...packingTemplate(
                          trip.key,
                          kind,
                          vietnamese:
                              Localizations.localeOf(context).languageCode ==
                              'vi',
                        ).map((p) => p.toJson()),
                      ],
                    }),
                  ),
                ),
                child: Text(tr(context, en, vi)),
              ),
          ],
        ),
        Text(
          '${rows.where((p) => p.packed).length}/${rows.length} ${tr(context, 'checklist rows packed; quantities shown separately', 'dòng checklist đã xếp; số lượng hiển thị riêng')}',
        ),
        if (rows.isEmpty)
          Text(
            tr(
              context,
              'Add your own list or an editable offline template.',
              'Thêm danh sách của bạn hoặc mẫu offline có thể sửa.',
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          onReorderItem: (a, b) => run(() => reorder(a, b)),
          itemBuilder: (context, index) {
            final p = rows[index];
            return ListTile(
              key: Key(p.key),
              contentPadding: EdgeInsets.zero,
              leading: Checkbox(
                value: p.packed,
                onChanged: (v) => run(
                  () => scope.controller.change(
                    (s) => s.put('packing', p.copy({'packed': v == true})),
                  ),
                ),
              ),
              title: Text(p.title),
              subtitle: Text(
                '${p.text('list')} · ${p.text('category')} · ×${p.quantity} · ${p.data['weightGrams'] ?? 0}g',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: tr(context, 'Packing actions', 'Thao tác hành lý'),
                onSelected: (value) => run(() async {
                  if (value == 'edit') await editPacking(context, scope, p);
                  if (value == 'remind' && context.mounted)
                    await editAlarm(context, scope, 'packing', p.key, trip.key);
                  if (value == 'duplicate')
                    await scope.controller.change(
                      (s) => s.put(
                        'packing',
                        p.copy({
                          'id': newId(),
                          'packed': false,
                          'order': rows.length,
                        }),
                      ),
                    );
                  if (value == 'up' && index > 0)
                    await reorder(index, index - 1);
                  if (value == 'down' && index < rows.length - 1)
                    await reorder(index, index + 1);
                  if (value == 'delete' &&
                      context.mounted &&
                      await tripConfirm(
                        context,
                        tr(
                          context,
                          'Delete this packing row?',
                          'Xóa dòng hành lý này?',
                        ),
                      ))
                    await scope.controller.change(
                      (s) => removeEntity(s, 'packing', p.key),
                    );
                }),
                itemBuilder: (context) => [
                  for (final (key, en, vi) in [
                    ('edit', 'Edit', 'Sửa'),
                    ('remind', 'Reminder', 'Nhắc'),
                    ('duplicate', 'Duplicate unchecked', 'Nhân bản chưa xếp'),
                    ('up', 'Move up', 'Lên trên'),
                    ('down', 'Move down', 'Xuống dưới'),
                    ('delete', 'Delete', 'Xóa'),
                  ])
                    PopupMenuItem(value: key, child: Text(tr(context, en, vi))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
