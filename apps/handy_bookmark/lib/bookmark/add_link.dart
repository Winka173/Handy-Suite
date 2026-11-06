import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';

/// Saves links the person pasted or typed. The clipboard is read only when
/// they ask ([fromClipboard]); nothing is fetched. A single link that is
/// already saved asks first: open it, review it, or add a copy anyway.
/// Returns the bookmark to show, if any.
Future<Bookmark?> addLinks(
  BuildContext context,
  SaveScope scope, {
  bool fromClipboard = false,
}) async {
  final c = scope.c;
  var initial = '';
  if (fromClipboard) {
    try {
      final text = await c.clipboard();
      if (text == null) {
        if (context.mounted) {
          showHandyMessage(
            context,
            tr(
              context,
              'That clipboard text was already offered.',
              'Nội dung clipboard này đã được dùng.',
            ),
          );
        }
        return null;
      }
      initial = text;
    } catch (_) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'The clipboard could not be read.',
            'Chưa đọc được clipboard.',
          ),
        );
      return null;
    }
  }
  if (!context.mounted) return null;
  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _SeveralLinks(initial: initial),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return null;
  return saveCapturedLinks(context, scope, text);
}

/// Reuses duplicate review for dialog, clipboard and inline capture.
Future<Bookmark?> saveCapturedLinks(
  BuildContext context,
  SaveScope scope,
  String text, {
  VoidCallback? onSaved,
}) async {
  final c = scope.c;
  final found = UrlTools.extract(text);
  if (found.isEmpty) {
    showHandyMessage(
      context,
      tr(
        context,
        'No http or https link found.',
        'Không thấy link http hoặc https nào.',
      ),
    );
    return null;
  }
  if (found.length == 1) {
    final u = found.single;
    final old = scope.library.bookmarks
        .where(
          (b) =>
              b.hasUrl &&
              (b.normalizedUrl == u.normalizedUrl ||
                  UrlTools.normalize(b.originalUrl).canonicalUrl ==
                      u.canonicalUrl),
        )
        .firstOrNull;
    if (old != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) => _AlreadySaved(old),
      );
      if (!context.mounted) return null;
      switch (choice) {
        case 'open':
          return old;
        case 'edit':
          await scope.edit(context, old);
          return null;
        case 'copy':
          final saved = <Bookmark>[];
          final ok = await scope.run(
            context,
            () async =>
                saved.addAll(await c.quickSave(text, allowDuplicates: true)),
          );
          if (ok) onSaved?.call();
          return saved.firstOrNull;
        default:
          return null;
      }
    }
  }
  final saved = <Bookmark>[];
  final ok = await scope.run(
    context,
    () async => saved.addAll(await c.quickSave(text)),
  );
  if (ok) onSaved?.call();
  if (ok && context.mounted) {
    showHandyMessage(
      context,
      saved.length == 1
          ? tr(
              context,
              'Saved. It waits in Not sorted.',
              'Đã lưu. Link nằm trong Chưa xếp.',
            )
          : tr(
              context,
              '${saved.length} links saved to Not sorted.',
              'Đã lưu ${saved.length} link vào Chưa xếp.',
            ),
    );
  }
  return null;
}

/// Several links at once: one roomy field, how it reads them, and Save.
/// Cancel keeps nothing; the field keeps its text until Save is pressed.
class _SeveralLinks extends StatefulWidget {
  final String initial;
  const _SeveralLinks({required this.initial});
  @override
  State<_SeveralLinks> createState() => _SeveralLinksState();
}

class _SeveralLinksState extends State<_SeveralLinks> {
  late final input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final found = input.text.trim().isEmpty
        ? 0
        : UrlTools.extract(input.text).length;
    final count = input.text.trim().isEmpty
        ? tr(
            context,
            'Links start with http:// or https://. Other words are skipped.',
            'Link bắt đầu bằng http:// hoặc https://. Chữ khác được bỏ qua.',
          )
        : found == 0
        ? tr(context, 'No link found yet.', 'Chưa thấy link nào.')
        : found == 1
        ? tr(context, '1 link found.', 'Thấy 1 link.')
        : tr(context, '$found links found.', 'Thấy $found link.');
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Save several links', 'Lưu nhiều link'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'Paste a list or a whole message. Saving works offline.',
                  'Dán một danh sách hay cả tin nhắn. Lưu được cả khi không có mạng.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('save-text-input'),
                controller: input,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: 262144,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'https://…',
                  counterText: '',
                  fillColor: theme.brightness == Brightness.dark
                      ? p.raised
                      : p.canvas,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(BookmarkRadii.field),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(count, style: theme.textTheme.bodySmall),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-text-confirm'),
                onPressed: () => Navigator.pop(context, input.text),
                child: Text(
                  found > 1
                      ? tr(context, 'Save $found links', 'Lưu $found link')
                      : tr(context, 'Save', 'Lưu'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'Cancel', 'Hủy')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A link that is already in the library: show the saved one (the usual
/// wish), look over its details, or keep a second copy on purpose.
class _AlreadySaved extends StatelessWidget {
  final Bookmark old;
  const _AlreadySaved(this.old);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Already saved', 'Link này đã được lưu'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? p.raised
                    : p.canvas,
                borderRadius: BorderRadius.circular(BookmarkRadii.item),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    old.title.isEmpty ? old.sourceDomain : old.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tr(
                      context,
                      'Saved ${formatDay(context, old.savedAt.substring(0, 10))}',
                      'Đã lưu ${formatDay(context, old.savedAt.substring(0, 10))}',
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('dup-open'),
              onPressed: () => Navigator.pop(context, 'open'),
              child: Text(tr(context, 'Show it', 'Xem link cũ')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('dup-edit'),
              onPressed: () => Navigator.pop(context, 'edit'),
              child: Text(tr(context, 'Review details', 'Xem lại chi tiết')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('dup-copy'),
              onPressed: () => Navigator.pop(context, 'copy'),
              child: Text(tr(context, 'Add anyway', 'Vẫn lưu bản mới')),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
          ],
        ),
      ),
    );
  }
}
