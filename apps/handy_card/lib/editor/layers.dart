import 'package:flutter/services.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'studio_controller.dart';

IconData elementIcon(String type) => switch (type) {
  'text' => Icons.title,
  'contact' => Icons.contact_page_outlined,
  'rect' => Icons.crop_square,
  'ellipse' => Icons.circle_outlined,
  'line' => Icons.horizontal_rule,
  'polygon' => Icons.hexagon_outlined,
  'image' => Icons.image_outlined,
  'icon' => Icons.emoji_symbols_outlined,
  'qr' => Icons.qr_code_2,
  'group' => Icons.folder_outlined,
  'badge' => Icons.verified_outlined,
  _ => Icons.help_outline,
};

String elementLabel(BuildContext context, StudioController c, CardElement e) {
  if (e.name.isNotEmpty) return e.name;
  final spec = c.registry.lookup(e.type);
  final kind = spec == null ? e.type : tr(context, spec.en, spec.vi);
  final text = switch (e.type) {
    'text' || 'contact' => displayText(e, c.profile),
    'badge' => e.prop<String>('label', ''),
    _ => '',
  }.replaceAll('\n', ' ');
  // The row's icon already says what kind it is.
  return text.isEmpty ? kind : text;
}

/// The layers of the side (or of the group entered), topmost first. Drag
/// to restack; the eye hides, the lock stops canvas edits; a group opens.
class LayersPanel extends StatelessWidget {
  final StudioController c;
  const LayersPanel({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.session;
    final entered = s.entered == null
        ? null
        : findElement(s.elements, s.entered!);
    final level = entered?.children ?? s.elements;
    final rows = level.reversed.toList();
    final colors = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entered != null)
          ListTile(
            key: const Key('layers-exit-group'),
            dense: true,
            leading: const Icon(Icons.arrow_back),
            title: Text(
              elementLabel(context, c, entered),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(tr(context, 'Inside this group', 'Trong nhóm này')),
            onTap: () {
              s.enter(null);
              s.select({entered.id});
            },
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'No layers yet. Add text, a shape or a picture.',
                'Chưa có lớp nào. Thêm chữ, hình hoặc ảnh.',
              ),
              style: TextStyle(color: colors.muted),
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('layers'),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            onReorderItem: (from, to) {
              // Rows are topmost first; the layer list is bottom first.
              final id = rows[from].id;
              final index = level.length - 1 - to;
              c.edit(
                'Restack',
                (l) => moveInTree(
                  l,
                  id,
                  entered?.id,
                  index.clamp(0, level.length - 1),
                ),
              );
            },
            itemBuilder: (context, i) {
              final e = rows[i];
              final selected = s.selected.contains(e.id);
              return Material(
                key: ValueKey(e.id),
                color: selected ? colors.select : Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      HardwareKeyboard.instance.isShiftPressed ||
                          HardwareKeyboard.instance.isControlPressed
                      ? s.toggle(e.id)
                      : s.select({e.id}),
                  onDoubleTap: () =>
                      e.isGroup ? s.enter(e.id) : _rename(context, e),
                  child: SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HandySpace.s,
                            ),
                            child: Icon(
                              Icons.drag_indicator,
                              size: 18,
                              color: colors.muted,
                            ),
                          ),
                        ),
                        Icon(
                          elementIcon(e.type),
                          size: 18,
                          color: colors.muted,
                        ),
                        const SizedBox(width: HandySpace.s),
                        Expanded(
                          child: Text(
                            elementLabel(context, c, e),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: e.visible ? null : colors.muted,
                            ),
                          ),
                        ),
                        if (e.binding?.mode == 'live')
                          Tooltip(
                            message: tr(
                              context,
                              'Follows the profile',
                              'Theo hồ sơ',
                            ),
                            child: Icon(
                              Icons.link,
                              size: 16,
                              color: colors.muted,
                            ),
                          ),
                        if (e.isGroup)
                          IconButton(
                            tooltip: tr(context, 'Open group', 'Mở nhóm'),
                            icon: const Icon(Icons.chevron_right, size: 18),
                            onPressed: () => s.enter(e.id),
                          ),
                        IconButton(
                          tooltip: e.visible
                              ? tr(context, 'Hide', 'Ẩn')
                              : tr(context, 'Show', 'Hiện'),
                          icon: Icon(
                            e.visible
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => c.update(
                            e.id,
                            (x) => x.copyWith(visible: !x.visible),
                            label: e.visible ? 'Hide' : 'Show',
                          ),
                        ),
                        IconButton(
                          tooltip: e.locked
                              ? tr(context, 'Unlock', 'Mở khóa')
                              : tr(context, 'Lock', 'Khóa'),
                          icon: Icon(
                            e.locked ? Icons.lock_outline : Icons.lock_open,
                            size: 18,
                          ),
                          onPressed: () => c.update(
                            e.id,
                            (x) => x.copyWith(locked: !x.locked),
                            label: e.locked ? 'Unlock' : 'Lock',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, CardElement e) async {
    final text = TextEditingController(text: e.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Layer name', 'Tên lớp')),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 120,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(tr(context, 'Rename', 'Đổi tên')),
          ),
        ],
      ),
    );
    text.dispose();
    if (name != null)
      c.update(e.id, (x) => x.copyWith(name: name.trim()), label: 'Rename');
  }
}
