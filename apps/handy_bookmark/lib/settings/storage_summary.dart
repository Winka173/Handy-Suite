import 'package:handy_ui/kit.dart';
import '../controller.dart';

/// What the library takes on this device.
class StorageUsage {
  final int links, pictures, pictureBytes, readingCopies, deleted;
  const StorageUsage({
    required this.links,
    required this.pictures,
    required this.pictureBytes,
    required this.readingCopies,
    required this.deleted,
  });
}

/// Counts from the library and sizes from the store; pictures count every
/// stored original (items, Recently Deleted and ones waiting to be
/// reclaimed), since that is what the device holds.
Future<StorageUsage> storageUsage(SaveController c) async {
  final l = c.library!;
  final media = await c.store!.mediaIndex();
  final reading = await c.store!.readingIndex();
  return StorageUsage(
    links: l.bookmarks.where((b) => b.hasUrl).length,
    pictures: l.bookmarks.where((b) => b.isImage).length,
    pictureBytes: media.values.fold(0, (a, b) => a + b),
    readingCopies: reading.length,
    deleted: l.trash.length,
  );
}

/// "0 B", "812 KB", "18.4 MB", "1.2 GB".
String formatBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1024 * 1024) return '${(n / 1024).round()} KB';
  if (n < 1024 * 1024 * 1024)
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(n / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Space on this device, in the person's words: the pictures they added at
/// full size (the one figure the store can weigh), then what else it
/// holds, each with the one thing that can be done about it. Previews and
/// page pictures are small and rebuilt when needed; offline copies go
/// only when asked; Recently Deleted empties itself after 30 days.
class StorageSummary extends StatelessWidget {
  final SaveController controller;
  final VoidCallback? onClearPreviews, onClearCopies, onTrash;
  const StorageSummary({
    super.key,
    required this.controller,
    this.onClearPreviews,
    this.onClearCopies,
    this.onTrash,
  });
  @override
  Widget build(BuildContext context) => FutureBuilder<StorageUsage>(
    // Recounted whenever the library changes (the page rebuilds).
    future: storageUsage(controller),
    builder: (context, snap) {
      final u = snap.data;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(color: c.muted);
      String count(int? n) => n == null ? '—' : '$n';
      Widget row({
        required String key,
        required String label,
        String? note,
        required String value,
        Widget? action,
        VoidCallback? onTap,
      }) {
        final body = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.s,
              action == null && onTap == null ? HandySpace.l : HandySpace.s,
              HandySpace.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.bodyLarge),
                      if (note != null)
                        Text(note, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: HandySpace.m),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: tabular,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: HandySpace.xs),
                  action,
                ],
                if (onTap != null) Icon(Icons.chevron_right, color: c.muted),
              ],
            ),
          ),
        );
        return KeyedSubtree(
          key: Key('storage-$key'),
          child: onTap == null ? body : InkWell(onTap: onTap, child: body),
        );
      }

      return HandyGroup(
        children: [
          Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                HandySpace.l,
                HandySpace.l,
                HandySpace.m,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u == null ? '—' : formatBytes(u.pictureBytes),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontFeatures: tabular,
                    ),
                  ),
                  Text(
                    u == null
                        ? tr(context, 'Counting…', 'Đang đếm…')
                        : tr(
                            context,
                            'Your pictures at full size. ${u.pictures} in the library.',
                            'Ảnh của bạn ở cỡ gốc. ${u.pictures} ảnh trong thư viện.',
                          ),
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
          row(
            key: 'links',
            label: tr(context, 'Links', 'Link'),
            note: tr(
              context,
              'Addresses, titles and notes take little space',
              'Địa chỉ, tiêu đề và ghi chú chiếm rất ít chỗ',
            ),
            value: count(u?.links),
          ),
          row(
            key: 'previews',
            label: tr(context, 'Previews', 'Ảnh xem trước'),
            note: tr(
              context,
              'Small copies for lists, and pictures fetched from pages',
              'Bản nhỏ cho danh sách và ảnh lấy từ trang web',
            ),
            value: '',
            action: onClearPreviews == null
                ? null
                : TextButton(
                    key: const Key('save-thumbnails'),
                    onPressed: onClearPreviews,
                    child: Text(tr(context, 'Clear', 'Xóa')),
                  ),
          ),
          row(
            key: 'reading',
            label: tr(context, 'Offline copies', 'Bản đọc ngoại tuyến'),
            note: (u?.readingCopies ?? 0) == 0
                ? tr(
                    context,
                    'Save one from a link\'s page',
                    'Lưu từ trang chi tiết của một link',
                  )
                : tr(
                    context,
                    'Pages saved to read without a connection',
                    'Trang đã lưu để đọc khi không có mạng',
                  ),
            value: count(u?.readingCopies),
            action: onClearCopies == null || (u?.readingCopies ?? 0) == 0
                ? null
                : TextButton(
                    key: const Key('save-copies-clear'),
                    onPressed: onClearCopies,
                    child: Text(tr(context, 'Remove', 'Xóa')),
                  ),
          ),
          row(
            key: 'deleted',
            label: tr(context, 'Recently Deleted', 'Thùng rác'),
            note: tr(
              context,
              'Kept 30 days, then removed',
              'Giữ 30 ngày rồi xóa hẳn',
            ),
            value: count(u?.deleted),
            onTap: onTrash,
          ),
        ],
      );
    },
  );
}
