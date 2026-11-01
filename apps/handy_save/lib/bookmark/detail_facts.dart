import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

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

/// Tags, the address, the person's own words, and the page's details,
/// fetched only on request. Edit and delete close the view.
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
    final c = HandyColors.of(context);
    final fetching = scope.c.fetching.containsKey(b.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.tags.isNotEmpty) ...[
          HandyLabel(tr(context, 'Tags', 'Thẻ')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [for (final t in b.tags) Chip(label: Text('#$t'))],
          ),
        ],
        HandyLabel(tr(context, 'Address', 'Địa chỉ')),
        HandyGroup(
          children: [
            ListTile(
              title: SelectableText(
                b.originalUrl,
                maxLines: 3,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                tr(
                  context,
                  'Opened ${b.openedCount} times from here',
                  'Đã mở ${b.openedCount} lần từ đây',
                ),
                style: TextStyle(color: c.muted),
              ),
              trailing: IconButton(
                key: const Key('detail-copy'),
                tooltip: tr(context, 'Copy address', 'Chép địa chỉ'),
                icon: const Icon(Icons.copy),
                onPressed: () => copyToClipboard(context, b.originalUrl),
              ),
            ),
          ],
        ),
        if ((b.description ?? '').isNotEmpty || b.note.isNotEmpty) ...[
          HandyLabel(tr(context, 'About it', 'Mô tả và ghi chú')),
          HandyGroup(
            children: [
              if ((b.description ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: SelectableText(b.description!),
                ),
              if (b.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(HandySpace.l),
                  child: SelectableText(
                    b.note,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
            ],
          ),
        ],
        HandyLabel(tr(context, 'From the page', 'Thông tin từ trang')),
        HandyGroup(
          children: [
            ListTile(
              title: Text(_metadataWords(context, b.metadataStatus)),
              textColor: c.muted,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                0,
                HandySpace.l,
                HandySpace.l,
              ),
              child: Wrap(
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
                      : OutlinedButton(
                          key: const Key('detail-metadata'),
                          onPressed: () => scope.run(
                            context,
                            () => scope.c.refreshMetadata(b.id),
                          ),
                          child: Text(
                            tr(context, 'Read the page', 'Đọc thông tin trang'),
                          ),
                        ),
                  OutlinedButton(
                    key: const Key('detail-thumbnail'),
                    onPressed: () => scope.chooseThumbnail(context, b),
                    child: Text(tr(context, 'Choose a picture', 'Chọn ảnh')),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.xl),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            OutlinedButton.icon(
              key: const Key('detail-edit'),
              onPressed: () => scope.edit(context, b),
              icon: const Icon(Icons.edit_outlined),
              label: Text(tr(context, 'Edit', 'Sửa')),
            ),
            TextButton.icon(
              key: const Key('detail-delete'),
              style: TextButton.styleFrom(foregroundColor: c.negative),
              onPressed: () async {
                if (await scope.delete(context, b)) onClosed();
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(tr(context, 'Delete', 'Xóa')),
            ),
          ],
        ),
      ],
    );
  }
}
