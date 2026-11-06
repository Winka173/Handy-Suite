import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../links/recall_link.dart';
import '../scope.dart';
import '../ui/visual.dart';
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

/// The person's note and the page's description, the tags, then the
/// library's tools folded away, then Edit and Delete. Edit and delete
/// close the view.
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
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final description = (b.description ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.note.isNotEmpty) ...[
          SectionHead(tr(context, 'Your note', 'Ghi chú của bạn')),
          Container(
            padding: const EdgeInsets.all(HandySpace.l),
            decoration: BoxDecoration(
              color: p.sageTint,
              borderRadius: BorderRadius.circular(BookmarkRadii.item),
            ),
            child: SelectableText(
              b.note,
              style: theme.textTheme.bodyLarge?.copyWith(color: p.ink),
            ),
          ),
        ],
        if (description.isNotEmpty) ...[
          SectionHead(tr(context, 'About it', 'Mô tả')),
          SelectableText(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: p.ink,
              height: 1.5,
            ),
          ),
        ],
        if (b.tags.isNotEmpty) ...[
          SectionHead(tr(context, 'Tags', 'Thẻ')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [for (final t in b.tags) Chip(label: Text('#$t'))],
          ),
        ],
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

/// "Details and tools": folded by default, with the item's state in its
/// header so nothing hides behind the fold. Pin, read and archive; the
/// address or the picture file; the page's details; the offline copy and
/// the link check; Handy Recall.
class _Tools extends StatefulWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const _Tools({required this.scope, required this.bookmark});
  @override
  State<_Tools> createState() => _ToolsState();
}

class _ToolsState extends State<_Tools> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.bookmark;
    final scope = widget.scope;
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final state = [
      if (b.isPinned) tr(context, 'Pinned', 'Đã ghim'),
      if (b.isRead) tr(context, 'Read', 'Đã đọc'),
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
            'Pin, read, archive, offline copy, link check',
            'Ghim, đã đọc, lưu trữ, bản offline, kiểm tra link',
          )
        : tr(
            context,
            'Pin, read, archive, the picture file',
            'Ghim, đã xem, lưu trữ, thông tin tệp ảnh',
          );
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: open,
            child: InkWell(
              key: const Key('detail-tools'),
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
                            tr(
                              context,
                              'Details and tools',
                              'Chi tiết và công cụ',
                            ),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(summary, style: theme.textTheme.bodySmall),
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
                    child: _ToolsBody(scope: scope, bookmark: b),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
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
          children: [
            flag(
              'pin',
              b.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              tr(context, 'Pin', 'Ghim'),
              b.isPinned,
              (x) => x.copyWith(isPinned: !x.isPinned),
            ),
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
          ],
        ),
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
