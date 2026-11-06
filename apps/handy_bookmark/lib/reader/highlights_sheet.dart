import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';

/// The person's highlights of one item, from the `highlights` preference.
List<Highlight> highlightsOf(SaveController c, String id) =>
    readHighlights(c.preferences['highlights'], [id])[id] ?? const [];

Future<void> saveHighlights(
  SaveController c,
  String id,
  List<Highlight> list,
) => c.update(
  (l) => l,
  prefs: {
    ...c.preferences,
    'highlights': {
      ...?(c.preferences['highlights'] as Map?)?.cast<String, dynamic>(),
      id: [for (final h in list) h.toJson()],
    },
  },
);

/// A highlight colour as a soft wash behind the words.
Color highlightWash(BuildContext context, String color) {
  final base = switch (color) {
    'green' => const Color(0xFF6FCF97),
    'blue' => const Color(0xFF56CCF2),
    'pink' => const Color(0xFFF299C1),
    'orange' => const Color(0xFFF2994A),
    _ => const Color(0xFFF2C94C),
  };
  final dark = Theme.of(context).brightness == Brightness.dark;
  return base.withValues(alpha: dark ? .42 : .45);
}

String _colorName(BuildContext context, String color) => switch (color) {
  'green' => tr(context, 'Green', 'Xanh lá'),
  'blue' => tr(context, 'Blue', 'Xanh dương'),
  'pink' => tr(context, 'Pink', 'Hồng'),
  'orange' => tr(context, 'Orange', 'Cam'),
  _ => tr(context, 'Yellow', 'Vàng'),
};

/// Edits a highlight's note and colour; null when cancelled.
Future<Highlight?> editHighlight(BuildContext context, Highlight h) =>
    showModalBottomSheet<Highlight>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _EditHighlight(h),
    );

class _EditHighlight extends StatefulWidget {
  final Highlight h;
  const _EditHighlight(this.h);
  @override
  State<_EditHighlight> createState() => _EditHighlightState();
}

class _EditHighlightState extends State<_EditHighlight> {
  late final note = TextEditingController(text: widget.h.note);
  late String color = widget.h.color;

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        key: const Key('highlight-edit'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlightWash(context, color),
              borderRadius: BorderRadius.circular(BookmarkRadii.field),
            ),
            child: Text(
              widget.h.quote,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final c in Highlight.colors)
                ChoiceChip(
                  key: Key('highlight-color-$c'),
                  avatar: CircleAvatar(
                    backgroundColor: highlightWash(context, c),
                  ),
                  label: Text(_colorName(context, c)),
                  selected: color == c,
                  onSelected: (_) => setState(() => color = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('highlight-note'),
            controller: note,
            minLines: 2,
            maxLines: 6,
            maxLength: Highlight.maxNote,
            decoration: InputDecoration(
              labelText: tr(context, 'Note', 'Ghi chú'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('highlight-save'),
            onPressed: () => Navigator.pop(
              context,
              widget.h.copyWith(color: color, note: note.text.trim()),
            ),
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    ),
  );
}

/// Every highlight of an item: jump to one, edit its note or colour,
/// delete it, or copy them all as text. Reading and managing them is
/// free; making new ones is Pro.
Future<void> showHighlights(
  BuildContext context, {
  required SaveController controller,
  required String id,
  required String title,
  required String url,
  required List<String> blocks,
  required ValueChanged<int> onJump,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (sheet) => ListenableBuilder(
    listenable: controller,
    builder: (sheet, _) {
      final theme = Theme.of(sheet);
      final p = BookmarkPalette.of(sheet);
      final list = highlightsOf(controller, id);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .8,
        ),
        child: Column(
          key: const Key('highlights-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(sheet, 'Highlights', 'Đoạn đánh dấu'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  if (list.isNotEmpty)
                    TextButton.icon(
                      key: const Key('highlights-copy'),
                      onPressed: () => copyToClipboard(
                        sheet,
                        highlightsAsText(title, url, list),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(tr(sheet, 'Copy all', 'Chép tất cả')),
                    ),
                ],
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  tr(
                    sheet,
                    'Select words in the article, then choose Highlight.',
                    'Chọn chữ trong bài, rồi chọn Đánh dấu.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [
                    for (final h in list)
                      _HighlightRow(
                        h: h,
                        placed: anchorHighlight(h, blocks) != null,
                        onJump: () {
                          final at = anchorHighlight(h, blocks);
                          if (at == null) return;
                          Navigator.pop(sheet);
                          onJump(at.$1);
                        },
                        onEdit: () async {
                          final next = await editHighlight(sheet, h);
                          if (next == null) return;
                          await saveHighlights(controller, id, [
                            for (final x in list) x.id == h.id ? next : x,
                          ]);
                        },
                        onDelete: () async {
                          // A note is the person's own writing: ask first.
                          if (h.note.isNotEmpty &&
                              !await confirmHandy(
                                sheet,
                                title: tr(
                                  sheet,
                                  'Delete this highlight and its note?',
                                  'Xóa đoạn đánh dấu và ghi chú này?',
                                ),
                                confirmLabel: tr(sheet, 'Delete', 'Xóa'),
                                destructive: true,
                              ))
                            return;
                          await saveHighlights(controller, id, [
                            for (final x in list)
                              if (x.id != h.id) x,
                          ]);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  ),
);

class _HighlightRow extends StatelessWidget {
  final Highlight h;
  final bool placed;
  final VoidCallback onJump, onEdit, onDelete;
  const _HighlightRow({
    required this.h,
    required this.placed,
    required this.onJump,
    required this.onEdit,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return InkWell(
      key: Key('highlight-${h.id}'),
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      onTap: placed ? onJump : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                color: highlightWash(context, h.color).withValues(alpha: 1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    h.quote,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (h.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        h.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (!placed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        tr(
                          context,
                          'No longer in this version of the page.',
                          'Không còn trong bản trang này.',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: p.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              key: Key('highlight-${h.id}-edit'),
              tooltip: tr(context, 'Note and colour', 'Ghi chú và màu'),
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_rounded),
            ),
            IconButton(
              key: Key('highlight-${h.id}-delete'),
              tooltip: tr(context, 'Delete highlight', 'Xóa đánh dấu'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
