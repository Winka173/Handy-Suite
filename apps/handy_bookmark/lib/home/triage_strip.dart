import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';

/// The home's shelf of what was saved lately, as pictures. What still has
/// no collection comes first and carries one "Put in…" button; the rest
/// show where they live. Ten at most; "See all" opens Not sorted.
class TriageStrip extends StatelessWidget {
  final SaveController controller;
  final Future<void> Function(Bookmark, String collectionId) onFile;
  final ValueChanged<Bookmark> onOpen;
  final VoidCallback onAll;
  const TriageStrip({
    super.key,
    required this.controller,
    required this.onFile,
    required this.onOpen,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = controller.library!;
    final live = [
      for (final b in l.bookmarks)
        if (!b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final waiting = [
      for (final b in live)
        if (b.collectionId == null) b,
    ];
    final shown = [
      ...waiting,
      for (final b in live)
        if (b.collectionId != null) b,
    ].take(10).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHead(
          tr(context, 'Recently saved', 'Mới lưu'),
          note: waiting.isEmpty
              ? tr(context, 'All sorted', 'Đã xếp hết')
              : tr(
                  context,
                  '${waiting.length} not sorted yet',
                  '${waiting.length} mục chưa xếp',
                ),
          action: waiting.isEmpty
              ? null
              : TextButton(
                  key: const Key('triage-all'),
                  onPressed: onAll,
                  child: Text(tr(context, 'See all', 'Xem tất cả')),
                ),
        ),
        SizedBox(
          height:
              126 +
              140 * scale.clamp(1.0, 2.2) +
              24 * (scale - 1).clamp(0.0, 1.2),
          child: ListView.separated(
            key: const Key('triage'),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _ShelfCard(
              key: ValueKey(
                shown[i].collectionId == null
                    ? 'triage-${shown[i].id}'
                    : 'shelf-${shown[i].id}',
              ),
              controller: controller,
              bookmark: shown[i],
              onFile: onFile,
              onOpen: onOpen,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final Future<void> Function(Bookmark, String) onFile;
  final ValueChanged<Bookmark> onOpen;
  const _ShelfCard({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.onFile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final l = controller.library!;
    final home = collectionOf(l, b.collectionId);
    return SizedBox(
      width: 168,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(b),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 126,
                child: ItemPicture(controller, b, radius: 0),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title.isEmpty ? b.sourceDomain : b.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      b.isImage
                          ? ago(context, b.savedAt)
                          : '${sourceLine(b)} · ${ago(context, b.savedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: home == null
                    ? _PutIn(
                        controller: controller,
                        bookmark: b,
                        onFile: onFile,
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                        child: Row(
                          children: [
                            HandyDot(home.$2, size: 8),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                home.$1.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: p.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one way to file a new save from the shelf: a small button that
/// opens the person's usual collections, then every other one.
class _PutIn extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final Future<void> Function(Bookmark, String) onFile;
  const _PutIn({
    required this.controller,
    required this.bookmark,
    required this.onFile,
  });

  Future<void> _file(BuildContext context, String id) async {
    try {
      await onFile(bookmark, id);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // The write failed and nothing moved; the card stays as it was.
    }
  }

  Future<void> _choose(BuildContext context) async {
    final l = controller.library!;
    final usual = usualCollections(l);
    final b = bookmark;
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context, 'Put it in', 'Xếp vào'),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  b.title.isEmpty ? b.sourceDomain : b.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final col in usual)
                  ListTile(
                    key: Key('file-${b.id}-${col.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: HandyDot(collectionHue(l, col.id), size: 12),
                    minLeadingWidth: 20,
                    title: Text(
                      col.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, col.id),
                  ),
                ListTile(
                  key: Key('file-${b.id}-other'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.folder_open_outlined),
                  minLeadingWidth: 20,
                  title: Text(
                    usual.isEmpty
                        ? tr(
                            context,
                            'Choose a collection…',
                            'Chọn bộ sưu tập…',
                          )
                        : tr(
                            context,
                            'Another collection…',
                            'Bộ sưu tập khác…',
                          ),
                  ),
                  onTap: () async {
                    final id = await pickCollection(
                      context,
                      l,
                      allowInbox: false,
                    );
                    if (context.mounted && id != null && id.isNotEmpty)
                      Navigator.pop(context, id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && context.mounted) await _file(context, picked);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton.tonalIcon(
      key: Key('file-${bookmark.id}'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: BookmarkPalette.of(context).tint,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? BookmarkPalette.dark.ink
            : BookmarkPalette.light.pressed,
        shape: const StadiumBorder(),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      onPressed: () => _choose(context),
      icon: const Icon(Icons.drive_file_move_outline, size: 18),
      label: Text(tr(context, 'Put in…', 'Xếp vào…')),
    ),
  );
}
