import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'detail_notes.dart';
import '../design/theme.dart';
import '../links/recall_link.dart';
import '../scope.dart';
import 'detail_links.dart';

String _metadataWords(BuildContext c, String status) => switch (status) {
  'complete' => tr(
    c,
    'Details read from the page.',
    'Đã đọc thông tin từ trang.',
  ),
  'partial' => tr(
    c,
    'Some details read from the page.',
    'Đã đọc một phần thông tin từ trang.',
  ),
  'failed' => tr(c, 'The page could not be read.', 'Chưa đọc được trang.'),
  'pending' => tr(c, 'Waiting to read the page.', 'Đang chờ đọc trang.'),
  _ => tr(
    c,
    'Only what was shared. Nothing is fetched unless you ask.',
    'Chỉ có những gì được chia sẻ. Không tải gì trừ khi bạn bấm.',
  ),
};

/// A quiet button for the folded tools: the raised tone, no outline.
ButtonStyle detailToolStyle(BuildContext context) {
  final p = BookmarkPalette.of(context);
  return FilledButton.styleFrom(
    backgroundColor: p.raised,
    foregroundColor: p.ink,
    minimumSize: const Size(48, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: const StadiumBorder(),
  );
}

/// A small heading inside the folded tools.
class DetailToolHead extends StatelessWidget {
  final String text;
  const DetailToolHead(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// The person's tags and note (open, editable in place), the library's
/// tools (folded), then Edit and Delete. Edit and delete close the view.
class DetailFacts extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  final VoidCallback onClosed;
  const DetailFacts({
    super.key,
    required this.scope,
    required this.bookmark,
    required this.onClosed,
  });

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final p = BookmarkPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: HandySpace.xl),
        // Open on the page: tags to add or remove, a note that saves
        // itself.
        DetailNotes(scope: scope, bookmark: b),
        const SizedBox(height: HandySpace.xl),
        _Tools(scope: scope, bookmark: b),
        const SizedBox(height: HandySpace.l),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            FilledButton.icon(
              key: const Key('detail-edit'),
              style: detailToolStyle(context),
              onPressed: () => scope.edit(context, b),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: Text(tr(context, 'Edit', 'Sửa')),
            ),
            TextButton.icon(
              key: const Key('detail-delete'),
              style: TextButton.styleFrom(
                foregroundColor: p.danger,
                minimumSize: const Size(48, 44),
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                if (await scope.delete(context, b)) onClosed();
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(tr(context, 'Delete', 'Xóa')),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.l),
      ],
    );
  }
}

/// A folded panel: its title and a one-line summary of what is inside, a
/// turn mark, and the content once opened. Reads as a button that is
/// expanded or not.
class DetailFold extends StatefulWidget {
  final String title, summary;
  final Widget child;

  /// On the header that folds and unfolds (tests tap it).
  final Key? toggleKey;
  const DetailFold({
    super.key,
    this.toggleKey,
    required this.title,
    required this.summary,
    required this.child,
  });
  @override
  State<DetailFold> createState() => _DetailFoldState();
}

class _DetailFoldState extends State<DetailFold> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              key: widget.toggleKey,
              onTap: () => setState(() => open = !open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (widget.summary.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? .5 : 0,
                      duration: HandyMotion.of(context, HandyMotion.short),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(Icons.expand_more, color: p.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: HandyMotion.of(context, HandyMotion.short),
            curve: HandyMotion.curve,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// "Details and tools": folded by default, with the item's state in its
/// header so nothing hides behind the fold. Read and archive (and Unpin
/// for an item pinned before pins were retired); the address or the
/// picture file; the page's details; the offline copy and the link check;
/// Handy Recall.
class _Tools extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _Tools({required this.scope, required this.bookmark});

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final state = [
      if (b.isPinned) tr(context, 'Pinned', 'Đã ghim'),
      if (b.isRead)
        b.isImage
            ? tr(context, 'Seen', 'Đã xem')
            : tr(context, 'Read', 'Đã đọc'),
      if (b.isArchived) tr(context, 'Archived', 'Đã lưu trữ'),
      if (b.linkCheck?.status == 'gone') tr(context, 'Gone', 'Không còn'),
      if (b.linkCheck?.status == 'moved') tr(context, 'Moved', 'Đã chuyển'),
      if (scope.c.readingIds.containsKey(b.id))
        tr(context, 'Offline copy', 'Có bản offline'),
    ];
    final summary = state.isNotEmpty
        ? state.join(' · ')
        : b.hasUrl && !b.isImage
        ? tr(
            context,
            'Read, archive, address, offline copy, link check',
            'Đã đọc, lưu trữ, địa chỉ, bản offline, kiểm tra link',
          )
        : tr(
            context,
            'Seen, archive, the picture file',
            'Đã xem, lưu trữ, thông tin tệp ảnh',
          );
    return DetailFold(
      toggleKey: const Key('detail-tools'),
      title: tr(context, 'Details and tools', 'Chi tiết và công cụ'),
      summary: summary,
      child: _ToolsBody(scope: scope, bookmark: b),
    );
  }
}

class _ToolsBody extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _ToolsBody({required this.scope, required this.bookmark});

  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final fetching = scope.c.fetching.containsKey(b.id);
    final description = (b.description ?? '').trim();
    final muted = theme.textTheme.bodyMedium?.copyWith(color: p.muted);
    Widget flag(
      String key,
      IconData icon,
      String label,
      bool value,
      Bookmark Function(Bookmark) flip,
    ) => FilterChip(
      key: Key('detail-$key'),
      selected: value,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: value
            ? (theme.brightness == Brightness.dark ? p.ink : p.pressed)
            : p.muted,
      ),
      label: Text(label),
      onSelected: (_) => scope.toggle(context, b, flip),
    );
    final media = b.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: HandySpace.xs),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            flag(
              'read',
              b.isRead ? Icons.done_all : Icons.done,
              b.isImage
                  ? tr(context, 'Seen', 'Đã xem')
                  : tr(context, 'Read', 'Đã đọc'),
              b.isRead,
              (x) => x.copyWith(isRead: !x.isRead),
            ),
            flag(
              'archive',
              b.isArchived ? Icons.archive : Icons.archive_outlined,
              tr(context, 'Archive', 'Lưu trữ'),
              b.isArchived,
              (x) => x.copyWith(isArchived: !x.isArchived),
            ),
            // Pins are retired: an item pinned before keeps its pin until
            // the person lets it go here; nothing sets a new one.
            if (b.isPinned)
              TextButton.icon(
                key: const Key('detail-unpin'),
                style: TextButton.styleFrom(
                  foregroundColor: p.muted,
                  minimumSize: const Size(48, 44),
                ),
                onPressed: () => scope.toggle(
                  context,
                  b,
                  (x) => x.copyWith(isPinned: false),
                ),
                icon: const Icon(Icons.push_pin_outlined, size: 18),
                label: Text(tr(context, 'Unpin', 'Bỏ ghim')),
              ),
          ],
        ),
        if (description.isNotEmpty) ...[
          DetailToolHead(tr(context, 'About it', 'Mô tả')),
          SelectableText(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: p.ink,
              height: 1.5,
            ),
          ),
        ],
        if (b.hasUrl) ...[
          DetailToolHead(tr(context, 'Address', 'Địa chỉ')),
          SelectableText(
            b.originalUrl,
            minLines: 1,
            maxLines: 3,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.ink),
          ),
          const SizedBox(height: 2),
          Text(
            tr(
              context,
              'Opened ${b.openedCount} times from here',
              'Đã mở ${b.openedCount} lần từ đây',
            ),
            style: muted,
          ),
        ],
        if (b.isImage && media != null) ...[
          DetailToolHead(tr(context, 'The picture file', 'Tệp ảnh')),
          if (media.name.isNotEmpty)
            SelectableText(
              media.name,
              style: theme.textTheme.bodyMedium?.copyWith(color: p.ink),
            ),
          Text(
            '${media.width} × ${media.height} · ${fileSize(media.bytes)}',
            style: muted,
          ),
        ],
        if (b.hasUrl && !b.isImage) ...[
          DetailToolHead(tr(context, 'From the page', 'Thông tin từ trang')),
          Text(_metadataWords(context, b.metadataStatus), style: muted),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              fetching
                  ? TextButton.icon(
                      key: const Key('detail-metadata-cancel'),
                      onPressed: () => scope.c.fetching[b.id]?.cancel(),
                      icon: const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: Text(tr(context, 'Stop', 'Dừng')),
                    )
                  : FilledButton(
                      key: const Key('detail-metadata'),
                      style: detailToolStyle(context),
                      onPressed: () => scope.run(
                        context,
                        () => scope.c.refreshMetadata(b.id),
                      ),
                      child: Text(
                        tr(context, 'Read the page', 'Đọc thông tin trang'),
                      ),
                    ),
              FilledButton(
                key: const Key('detail-thumbnail'),
                style: detailToolStyle(context),
                onPressed: () => scope.chooseThumbnail(context, b),
                child: Text(
                  b.media == null
                      ? tr(context, 'Choose a picture', 'Chọn ảnh')
                      : tr(context, 'Choose another', 'Chọn ảnh khác'),
                ),
              ),
              if (b.media != null)
                TextButton(
                  key: const Key('detail-thumbnail-reset'),
                  onPressed: () => scope.resetThumbnail(context, b),
                  child: Text(
                    tr(context, "Use the page's picture", 'Dùng ảnh của trang'),
                  ),
                ),
            ],
          ),
        ],
        if (b.hasUrl && !b.isImage) DetailLinks(scope: scope, bookmark: b),
        if (canHandOff) ...[
          DetailToolHead(tr(context, 'Study it', 'Ôn lại')),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              key: const Key('detail-recall'),
              style: detailToolStyle(context),
              onPressed: () => sendToRecall(context, b),
              icon: const Icon(Icons.style_outlined, size: 20),
              label: Text(
                tr(
                  context,
                  'Make a study card in Handy Recall',
                  'Tạo thẻ ôn trong Handy Recall',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A file's size in KB or MB, one decimal.
String fileSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
