import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show askText, ProBadge;
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';

String fieldTypeName(BuildContext context, String type) => switch (type) {
  'text' => tr(context, 'Text', 'Chữ'),
  'number' => tr(context, 'Number', 'Số'),
  'date' => tr(context, 'Date', 'Ngày'),
  'checkbox' => tr(context, 'Yes / no', 'Có / không'),
  'single' => tr(context, 'One choice', 'Một lựa chọn'),
  _ => tr(context, 'Link', 'Đường link'),
};

/// Board ⋮ › Custom fields (Pro): add, rename, show on the card front, set
/// aside (values stay on the cards).
Future<void> fieldsSheet(
  BuildContext context,
  BoardsScope scope,
  String board,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => ListenableBuilder(
    listenable: scope.controller,
    builder: (sheet, _) {
      final theme = Theme.of(sheet);
      final p = BoardsPalette.of(sheet);
      final all = fieldsOf(scope.state, board, all: true);
      Future<void> pro(Future<void> Function() then) async {
        if (await requirePro(sheet, ProFeature.fields) && sheet.mounted) {
          await scope.run(sheet, then);
        }
      }

      return ListView(
        key: const Key('fields-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(sheet, 'Custom fields', 'Trường tuỳ chỉnh'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (!hasPro(sheet)) const ProBadge(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              sheet,
              'A few properties of this board\'s own. Setting a field aside '
                  'keeps its values on the cards.',
              'Vài thuộc tính riêng của bảng này. Gỡ một trường vẫn giữ giá '
                  'trị trên thẻ.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
          ),
          for (final f in all)
            ListTile(
              key: Key('field-${f.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                f.str('title'),
                style: f.flag('archived') ? TextStyle(color: p.muted) : null,
              ),
              subtitle: Text(
                [
                  fieldTypeName(sheet, f.str('type')),
                  if (f.flag('onCard'))
                    tr(sheet, 'on the card', 'hiện trên thẻ'),
                  if (f.flag('archived')) tr(sheet, 'set aside', 'đã gỡ'),
                ].join(' · '),
              ),
              trailing: PopupMenuButton<String>(
                key: Key('field-menu-${f.id}'),
                onSelected: (v) => pro(
                  () => switch (v) {
                    'rename' => () async {
                      final name = await askText(
                        sheet,
                        title: tr(sheet, 'Rename field', 'Đổi tên trường'),
                        value: f.str('title'),
                        max: 60,
                      );
                      if (name == null || name.trim().isEmpty) return;
                      await scope.controller.change(
                        (s) => updateField(s, f.id, title: name),
                      );
                    }(),
                    'card' => scope.controller.change(
                      (s) => updateField(s, f.id, onCard: !f.flag('onCard')),
                    ),
                    _ => scope.controller.change(
                      (s) => archiveField(s, f.id, restore: f.flag('archived')),
                    ),
                  },
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(tr(sheet, 'Rename', 'Đổi tên')),
                  ),
                  PopupMenuItem(
                    value: 'card',
                    child: Text(
                      f.flag('onCard')
                          ? tr(sheet, 'Hide on the card', 'Ẩn trên thẻ')
                          : tr(sheet, 'Show on the card', 'Hiện trên thẻ'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      f.flag('archived')
                          ? tr(sheet, 'Bring back', 'Dùng lại')
                          : tr(sheet, 'Set aside', 'Gỡ trường'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('field-add'),
            onPressed: () => pro(() async {
              final made = await _newField(sheet);
              if (made == null) return;
              await scope.controller.change(
                (s) => addField(s, board, made.$1, made.$2, options: made.$3),
              );
            }),
            icon: const Icon(Icons.add),
            label: Text(tr(sheet, 'Add a field', 'Thêm trường')),
          ),
        ],
      );
    },
  ),
);

Future<(String, String, List<String>)?> _newField(BuildContext context) {
  final name = TextEditingController(), options = TextEditingController();
  var type = 'text';
  return showDialog<(String, String, List<String>)>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => AlertDialog(
        title: Text(tr(d, 'New field', 'Trường mới')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('field-name'),
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: tr(d, 'Name', 'Tên')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('field-type'),
                initialValue: type,
                decoration: InputDecoration(labelText: tr(d, 'Kind', 'Kiểu')),
                items: [
                  for (final t in fieldTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(fieldTypeName(d, t)),
                    ),
                ],
                onChanged: (v) => set(() => type = v ?? 'text'),
              ),
              if (type == 'single') ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('field-options'),
                  controller: options,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: tr(
                      d,
                      'Choices, one per line',
                      'Lựa chọn, mỗi dòng một',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(tr(d, 'Cancel', 'Huỷ')),
          ),
          FilledButton(
            key: const Key('field-save'),
            onPressed: () => name.text.trim().isEmpty
                ? null
                : Navigator.pop(d, (name.text, type, options.text.split('\n'))),
            child: Text(tr(d, 'Add', 'Thêm')),
          ),
        ],
      ),
    ),
  );
}

/// Card detail: the board's fields with this card's values. Values stay
/// readable without Pro (and for set-aside fields); changing one asks.
class CardFieldsSection extends StatelessWidget {
  final BoardsScope scope;
  final BoardRecord card;
  const CardFieldsSection({super.key, required this.scope, required this.card});

  @override
  Widget build(BuildContext context) {
    final s = scope.state, theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final values = object(card.data['custom'] ?? {});
    final fields = fieldsOf(
      s,
      card.str('board'),
      all: true,
    ).where((f) => !f.flag('archived') || values.containsKey(f.id)).toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    final vi = isVi(context);
    Future<void> edit(BoardRecord f) async {
      if (!await requirePro(context, ProFeature.fields) || !context.mounted) {
        return;
      }
      final old = values[f.id];
      Object? v;
      switch (f.str('type')) {
        case 'checkbox':
          v = old != true;
        case 'date':
          final picked = await pickHandyDate(context, '${old ?? ''}');
          if (picked == null) return;
          v = picked;
        case 'single':
          v = await showDialog<String>(
            context: context,
            builder: (d) => SimpleDialog(
              title: Text(f.str('title')),
              children: [
                for (final o in f.strings('options'))
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(d, o),
                    child: Text(o),
                  ),
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(d, ''),
                  child: Text(tr(d, 'Clear', 'Bỏ trống')),
                ),
              ],
            ),
          );
          if (v == null) return;
        default:
          v = await askText(
            context,
            title: f.str('title'),
            value: '${old ?? ''}',
            max: 1000,
          );
          if (v == null) return;
      }
      if (!context.mounted) return;
      await scope.run(
        context,
        () => scope.controller.change(
          (s) => setFieldValue(s, card.id, f.id, v, now: scope.clock()),
        ),
      );
    }

    return Padding(
      key: const Key('card-fields'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'Fields', 'Trường'),
            style: theme.textTheme.titleMedium,
          ),
          for (final f in fields)
            ListTile(
              key: Key('card-field-${f.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(f.str('title')),
              subtitle: Text(
                values.containsKey(f.id)
                    ? fieldText(f, values[f.id], vi: vi)
                    : tr(context, 'Empty', 'Trống'),
                style: TextStyle(
                  color: values.containsKey(f.id) ? p.ink : p.muted,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => edit(f),
            ),
        ],
      ),
    );
  }
}

bool isVi(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'vi';
