import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show newId;

/// Name, kind and an optional target count of a collection.
class CollectionDialog extends StatefulWidget {
  final InventoryCollection? old;

  /// Identity hue for a new collection.
  final int hue;
  const CollectionDialog({super.key, this.old, this.hue = 0});
  @override
  State<CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<CollectionDialog> {
  late final name = TextEditingController(text: widget.old?.name ?? '');
  late final target = TextEditingController(
    text: (widget.old?.target ?? 0) > 0 ? '${widget.old!.target}' : '',
  );
  late String kind = widget.old?.kind ?? 'figures';
  String error = '';

  @override
  void dispose() {
    name.dispose();
    target.dispose();
    super.dispose();
  }

  void save() {
    final n = int.tryParse(target.text.trim().replaceAll('.', '')) ?? 0;
    if (name.text.trim().isEmpty) {
      setState(() => error = tr(context, 'Give it a name', 'Đặt tên cho bộ'));
      return;
    }
    if (target.text.trim().isNotEmpty && (n < 1 || n > 100000)) {
      setState(
        () => error = tr(
          context,
          'A target is a whole number from 1 to 100,000',
          'Mục tiêu là số nguyên từ 1 đến 100.000',
        ),
      );
      return;
    }
    final old = widget.old;
    Navigator.pop(
      context,
      old == null
          ? InventoryCollection(
              id: newId(),
              name: name.text,
              kind: kind,
              hue: widget.hue,
              target: n,
            )
          : old.copyWith({'name': name.text, 'kind': kind, 'target': n}),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.old == null
          ? tr(context, 'New collection', 'Bộ sưu tập mới')
          : tr(context, 'Edit collection', 'Sửa bộ sưu tập'),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HandyField(
            label: tr(context, 'Name', 'Tên'),
            child: TextField(
              key: const Key('collection-name'),
              controller: name,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(counterText: ''),
              onSubmitted: (_) => save(),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          HandyField(
            label: tr(context, 'What it holds', 'Sưu tầm gì'),
            child: DropdownButtonFormField<String>(
              key: const Key('collection-kind'),
              initialValue: kind,
              isExpanded: true,
              items: [
                for (final k in keepCollectionKinds)
                  DropdownMenuItem(
                    value: k.id,
                    child: Text(tr(context, k.en, k.vi)),
                  ),
              ],
              onChanged: (v) => setState(() => kind = v ?? kind),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          HandyField(
            label: tr(
              context,
              'How many in all (optional)',
              'Tổng cộng bao nhiêu món (không bắt buộc)',
            ),
            child: TextField(
              key: const Key('collection-target'),
              controller: target,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: tr(context, 'e.g. 24', 'ví dụ 24'),
                helperText: tr(
                  context,
                  'Your own count; Keep shows how many are still missing.',
                  'Số bạn tự đặt; Keep cho biết còn thiếu bao nhiêu.',
                ),
              ),
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: HandySpace.m),
            HandyNotice(error, tone: HandyTone.error),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Cancel', 'Hủy')),
      ),
      FilledButton(
        key: const Key('collection-save'),
        onPressed: save,
        child: Text(tr(context, 'Save', 'Lưu')),
      ),
    ],
  );
}
