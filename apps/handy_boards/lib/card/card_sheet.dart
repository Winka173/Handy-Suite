import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../board/board_menus.dart';
import '../board/board_page.dart' show showUndo;
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';
import '../ui/look.dart';
import 'cover_picker.dart';

/// Opens a card: a sheet on phones, a dialog on wide screens. Every change
/// is kept as it is made (with Undo), so closing never loses anything.
Future<void> openCard(BuildContext context, BoardsScope scope, String card) {
  final wide = MediaQuery.sizeOf(context).width >= 900;
  Widget body(BuildContext context, ScrollController? scroll) =>
      ListenableBuilder(
        listenable: scope.controller,
        builder: (context, _) {
          final s = scope.controller.state;
          if (s == null || s.maybe('tasks', card) == null)
            return const SizedBox.shrink();
          return CardDetail(scope: scope, card: card, scroll: scroll);
        },
      );
  if (wide)
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
          child: body(context, null),
        ),
      ),
    );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .5,
      maxChildSize: .97,
      builder: (context, scroll) => body(context, scroll),
    ),
  );
}

class CardDetail extends StatefulWidget {
  final BoardsScope scope;
  final String card;
  final ScrollController? scroll;
  const CardDetail({
    super.key,
    required this.scope,
    required this.card,
    this.scroll,
  });
  @override
  State<CardDetail> createState() => _CardDetailState();
}

class _CardDetailState extends State<CardDetail> {
  late final title = TextEditingController(text: _card.str('title'));
  late final notes = TextEditingController(text: _card.str('notes'));
  final newSubtask = TextEditingController();
  final subtaskFocus = FocusNode();
  Timer? _notesTimer;
  BoardsScope get scope => widget.scope;
  BoardRecord get _card => scope.state.get('tasks', widget.card);

  @override
  void dispose() {
    _flushNotes();
    title.dispose();
    notes.dispose();
    newSubtask.dispose();
    subtaskFocus.dispose();
    super.dispose();
  }

  Future<void> _change(BoardsState Function(BoardsState) action) =>
      scope.run(context, () => scope.controller.change(action));

  Future<void> _saveTitle() async {
    final v = title.text.trim();
    if (v.isEmpty) {
      title.text = _card.str('title');
      return;
    }
    if (v == _card.str('title')) return;
    await _change(
      (s) => saveTask(
        s,
        s.get('tasks', widget.card).copy({'title': v}),
        now: scope.clock(),
      ),
    );
  }

  void _notesChanged(String _) {
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 600), _flushNotes);
  }

  void _flushNotes() {
    _notesTimer?.cancel();
    final state = scope.controller.state;
    final t = state?.maybe('tasks', widget.card);
    if (t == null || t.str('notes') == notes.text) return;
    scope.controller.change(
      (s) => saveTask(
        s,
        s.get('tasks', widget.card).copy({'notes': notes.text}),
        now: scope.clock(),
      ),
    );
  }

  Future<void> _addSubtask() async {
    final v = newSubtask.text.trim();
    if (v.isEmpty) return;
    newSubtask.clear();
    await _change(
      (s) => s.put(
        'checklist',
        BoardRecord({
          'id': newId(),
          'task': widget.card,
          'title': v,
          'order': subtasksOf(s, widget.card).length,
          'done': false,
        }),
      ),
    );
    if (mounted) subtaskFocus.requestFocus();
  }

  Future<void> _cover() async {
    final s = scope.state, t = _card;
    final current = (t.data['cover'] as String?)?.replaceFirst('art:', '');
    final category = s.maybe('categories', t.data['category'] as String?);
    final b = s.get('boards', t.str('board'));
    final suggested = [
      ?b.data['cover'] as String?,
      for (final o in topTasks(s, board: t.str('board')))
        if ((o.data['cover'] as String?)?.startsWith('art:') == true &&
            o.data['category'] == category?.id)
          (o.data['cover'] as String).substring(4),
    ];
    final picked = await pickCover(
      context,
      scope,
      current: t.data['cover'] == null && t.data['coverPhoto'] == null
          ? null
          : current ?? '',
      suggested: suggested,
      preview: (cover) => _CoverPreview(state: s, card: t, cover: cover),
    );
    if (picked == null || !mounted) return;
    if (picked.photo) return _photo();
    if (picked.art != null &&
        coverById(picked.art)?.pro == true &&
        !await requirePro(context, ProFeature.covers))
      return;
    if (!mounted) return;
    await _change(
      (s) => setCardCover(
        s,
        widget.card,
        art: picked.art,
        color: picked.color,
        now: scope.clock(),
      ),
    );
  }

  Future<void> _photo() async {
    final file = await scope.files.importBytes(
      extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      maxBytes: 12000000,
    );
    if (file == null || !mounted) return;
    final id = newId(), ext = file.name.split('.').last.toLowerCase();
    final path = 'assets/$id.${ext == 'jpeg' ? 'jpg' : ext}';
    final preview = await compute(attachmentPreview, file.bytes);
    final previewPath = 'assets/${id}_preview.jpg';
    final t = _card;
    await _change(
      (s) => setCardCover(
        s
            .putFile(path, file.bytes)
            .putFile(previewPath, preview)
            .put(
              'attachments',
              BoardRecord({
                'id': id,
                'task': t.id,
                'board': t.str('board'),
                'name': file.name,
                'path': path,
                'sha256': sha256.convert(file.bytes).toString(),
                'preview': previewPath,
              }),
            ),
        t.id,
        photo: id,
        now: scope.clock(),
      ),
    );
  }

  Future<void> _due() async {
    final t = _card;
    final current = t.data['due'] is Map && t.data['due']['kind'] == 'day'
        ? t.data['due']['day'] as String
        : '';
    final picked = await pickHandyDate(context, current);
    if (picked == null || !mounted) return;
    await _change(
      (s) => saveTask(
        s,
        s.get('tasks', widget.card).copy({
          'due': picked.isEmpty ? null : {'kind': 'day', 'day': picked},
        }),
        now: scope.clock(),
      ),
    );
  }

  Future<void> _reminder(BoardRecord? existing) async {
    if (existing != null) {
      await _change((s) => s.remove('reminders', {existing.id}));
      return;
    }
    if (!scope.reminders.supported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Reminders show inside the app on this device.',
              'Trên máy này, nhắc chỉ hiện trong app.',
            ),
          ),
        ),
      );
    } else if (!await scope.reminders.request()) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                'Notifications are off for Handy Boards.',
                'Thông báo của Handy Boards đang tắt.',
              ),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    final due = dueDay(_card);
    final day = await pickHandyDate(
      context,
      due == null
          ? ''
          : '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
    );
    if (day == null || day.isEmpty || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    final d = DateTime.parse(day);
    final at = DateTime(d.year, d.month, d.day, time.hour, time.minute);
    final t = _card;
    await _change(
      (s) => s.put(
        'reminders',
        BoardRecord({
          'id': newId(),
          'task': t.id,
          'board': t.str('board'),
          'at': at.toUtc().toIso8601String(),
          'zone': s
              .get('boards', t.str('board'))
              .str('zone', 'Asia/Ho_Chi_Minh'),
          'enabled': true,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = scope.state, t = _card;
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final now = scope.clock();
    final board = t.str('board');
    final columns = columnsOf(s, board);
    final categories = categoriesOf(s, board);
    final column = s.get('statuses', t.str('status'));
    final category = s.maybe('categories', t.data['category'] as String?);
    final items = subtasksOf(s, t.id);
    final progress = subtaskProgress(s, t.id);
    final due = dueDay(t);
    final reminder = s
        .related('reminders', t.id)
        .where((r) => r.flag('enabled'))
        .firstOrNull;
    final cover = cardCover(context, s, t);
    final links = RegExp(
      r'https?://[^\s<>()]+',
    ).allMatches(t.str('notes')).map((m) => m[0]!).toSet().take(5);

    Widget chip({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool set = false,
    }) => ActionChip(
      key: key,
      avatar: Icon(icon, size: 18, color: set ? p.ink : p.muted),
      label: Text(label, style: TextStyle(color: set ? p.ink : p.muted)),
      onPressed: onTap,
      backgroundColor: set ? p.raised : p.surface,
      side: set ? BorderSide.none : BorderSide(color: p.line),
    );

    return Material(
      color: p.surface,
      child: ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (cover != null)
            Semantics(
              button: true,
              label: tr(context, 'Change cover', 'Đổi ảnh bìa'),
              child: InkWell(
                key: const Key('card-cover-art'),
                onTap: _cover,
                child: SizedBox(height: 140, child: cover),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('card-title'),
                    controller: title,
                    maxLines: null,
                    maxLength: 1000,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveTitle(),
                    onTapOutside: (_) => _saveTitle(),
                  ),
                ),
                IconButton(
                  key: const Key('card-more'),
                  tooltip: tr(context, 'Card options', 'Tuỳ chọn thẻ'),
                  onPressed: () => cardMenu(
                    context,
                    scope,
                    t.id,
                    onMoved: (card, col, i) => _change(
                      (s) => moveCard(
                        s,
                        card,
                        column: col,
                        index: i,
                        now: scope.clock(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MenuAnchor(
                  menuChildren: [
                    for (final c in columns)
                      MenuItemButton(
                        key: Key('card-column-${c.id}'),
                        leadingIcon: Icon(
                          c.id == column.id ? Icons.check : null,
                        ),
                        onPressed: () => _change(
                          (s) => moveCard(
                            s,
                            t.id,
                            column: c.id,
                            index: cardsIn(s, c.id).length,
                            now: scope.clock(),
                          ),
                        ),
                        child: Text(c.str('title')),
                      ),
                  ],
                  builder: (context, menu, _) => chip(
                    key: const Key('card-column'),
                    icon: Icons.view_column_outlined,
                    label: column.str('title'),
                    set: true,
                    onTap: () => menu.isOpen ? menu.close() : menu.open(),
                  ),
                ),
                MenuAnchor(
                  menuChildren: [
                    for (final c in [null, ...categories])
                      MenuItemButton(
                        key: Key('card-category-${c?.id ?? 'none'}'),
                        leadingIcon: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: categoryHue(context, c).mark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        onPressed: () => _change(
                          (s) => saveTask(
                            s,
                            s.get('tasks', t.id).copy({'category': c?.id}),
                            now: scope.clock(),
                          ),
                        ),
                        child: Text(categoryName(context, c)),
                      ),
                  ],
                  builder: (context, menu, _) => category == null
                      ? chip(
                          key: const Key('card-category'),
                          icon: Icons.label_outline,
                          label: tr(context, 'Category', 'Nhóm'),
                          onTap: () => menu.isOpen ? menu.close() : menu.open(),
                        )
                      : ActionChip(
                          key: const Key('card-category'),
                          avatar: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: categoryHue(context, category).mark,
                              shape: BoxShape.circle,
                            ),
                          ),
                          label: Text(category.str('title')),
                          backgroundColor: categoryHue(context, category).tint,
                          side: BorderSide.none,
                          onPressed: () =>
                              menu.isOpen ? menu.close() : menu.open(),
                        ),
                ),
                chip(
                  key: const Key('card-due'),
                  icon: Icons.event_outlined,
                  label: due == null
                      ? tr(context, 'Due date', 'Hạn')
                      : dueLabel(context, due, now),
                  set: due != null,
                  onTap: _due,
                ),
                chip(
                  key: const Key('card-reminder'),
                  icon: reminder == null
                      ? Icons.notifications_none
                      : Icons.notifications_active_outlined,
                  label: reminder == null
                      ? tr(context, 'Reminder', 'Nhắc')
                      : () {
                          final at = DateTime.parse(
                            reminder.str('at'),
                          ).toLocal();
                          return '${dueLabel(context, DateTime(at.year, at.month, at.day), now)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
                        }(),
                  set: reminder != null,
                  onTap: () => _reminder(reminder),
                ),
                if (cover == null)
                  chip(
                    key: const Key('card-cover'),
                    icon: Icons.image_outlined,
                    label: tr(context, 'Cover', 'Ảnh bìa'),
                    onTap: _cover,
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Text(
                  tr(context, 'Subtasks', 'Việc con'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: 10),
                if (progress.total > 0)
                  Text(
                    '${progress.done}/${progress.total}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: p.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
          if (progress.total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress.done / progress.total,
                  minHeight: 4,
                  color: progress.done == progress.total
                      ? p.positive
                      : p.primary,
                ),
              ),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) {
              final ids = items.map((c) => c.id).toList();
              final id = ids.removeAt(from);
              ids.insert(to, id);
              _change((s) => reorder(s, 'checklist', ids));
            },
            children: [
              for (var i = 0; i < items.length; i++)
                _SubtaskRow(
                  key: ValueKey(items[i].id),
                  item: items[i],
                  index: i,
                  onTick: (v) => _change(
                    (s) => finishWhenSubtasksDone(
                      toggleChecklist(s, items[i].id, v, now: scope.clock()),
                      widget.card,
                      now: scope.clock(),
                    ),
                  ),
                  onRename: (v) => _change(
                    (s) => s.put(
                      'checklist',
                      s.get('checklist', items[i].id).copy({'title': v}),
                    ),
                  ),
                  onRemove: () async {
                    await _change((s) => s.remove('checklist', {items[i].id}));
                    if (context.mounted)
                      showUndo(
                        context,
                        scope,
                        tr(context, 'Subtask removed', 'Đã xoá việc con'),
                      );
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextField(
              key: const Key('card-add-subtask'),
              controller: newSubtask,
              focusNode: subtaskFocus,
              textInputAction: TextInputAction.done,
              maxLength: 1000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.add),
                hintText: tr(context, 'Add a subtask', 'Thêm việc con'),
              ),
              onSubmitted: (_) => _addSubtask(),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Text(
              tr(context, 'Notes', 'Ghi chú'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('card-notes'),
              controller: notes,
              minLines: 3,
              maxLines: 12,
              maxLength: 100000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'Details, links, anything to remember',
                  'Chi tiết, link, điều cần nhớ',
                ),
              ),
              onChanged: _notesChanged,
              onTapOutside: (_) => _flushNotes(),
            ),
          ),
          if (links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final l in links)
                    ActionChip(
                      avatar: const Icon(Icons.open_in_new, size: 16),
                      label: Text(
                        Uri.parse(l).host,
                        overflow: TextOverflow.ellipsis,
                      ),
                      tooltip: l,
                      onPressed: () => launchUrl(
                        Uri.parse(l),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  final BoardRecord item;
  final int index;
  final ValueChanged<bool> onTick;
  final ValueChanged<String> onRename;
  final VoidCallback onRemove;
  const _SubtaskRow({
    super.key,
    required this.item,
    required this.index,
    required this.onTick,
    required this.onRename,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final done = item.flag('done');
    return Material(
      color: Colors.transparent,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Checkbox(value: done, onChanged: (v) => onTick(v ?? false)),
          Expanded(
            child: InkWell(
              onTap: () async {
                final v = await askText(
                  context,
                  title: tr(context, 'Edit subtask', 'Sửa việc con'),
                  value: item.str('title'),
                  max: 1000,
                );
                if (v != null && v.isNotEmpty) onRename(v);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  item.str('title'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: done ? p.muted : p.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: p.muted,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Remove subtask', 'Xoá việc con'),
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 20, color: p.muted),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
              child: Icon(
                Icons.drag_indicator,
                color: p.muted,
                semanticLabel: tr(context, 'Drag to reorder', 'Kéo để sắp xếp'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card as it will look with [cover], for the picker's live preview.
class _CoverPreview extends StatelessWidget {
  final BoardsState state;
  final BoardRecord card;
  final Widget? cover;
  const _CoverPreview({
    required this.state,
    required this.card,
    required this.cover,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final shown = cover ?? cardCover(context, state, card);
    return Container(
      color: p.raised,
      padding: const EdgeInsets.all(12),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BoardsRadii.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 72, child: shown ?? ColoredBox(color: p.raised)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                card.str('title'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
