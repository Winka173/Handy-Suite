import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import 'collection_picker.dart';

/// Files a save that is not sorted yet: an icon button on its row that
/// opens the likeliest collections for it ([suggestCollections]), then
/// every other one. A failed write moves nothing.
class PutIn extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final Future<void> Function(Bookmark, String) onFile;
  const PutIn({
    super.key,
    required this.controller,
    required this.bookmark,
    required this.onFile,
  });

  Future<void> _file(String id) async {
    try {
      await onFile(bookmark, id);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // The write failed and nothing moved; the row stays as it was.
    }
  }

  Future<void> _choose(BuildContext context) async {
    final l = controller.library!;
    final b = bookmark;
    final likely = suggestCollections(l, b);
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
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
                for (final col in likely)
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
                    likely.isEmpty
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
    if (picked != null) await _file(picked);
  }

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key('file-${bookmark.id}'),
    tooltip: tr(context, 'Put in a collection', 'Xếp vào bộ sưu tập'),
    onPressed: () => _choose(context),
    icon: const Icon(Icons.drive_file_move_outline),
  );
}
