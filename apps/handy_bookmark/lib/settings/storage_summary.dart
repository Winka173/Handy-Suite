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

class StorageSummary extends StatelessWidget {
  final SaveController controller;
  const StorageSummary({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => FutureBuilder<StorageUsage>(
    // Recounted whenever the library changes (the page rebuilds).
    future: storageUsage(controller),
    builder: (context, snap) {
      final u = snap.data;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      Widget row(String key, String label, String? value) => Padding(
        key: Key('storage-$key'),
        padding: const EdgeInsets.symmetric(
          horizontal: HandySpace.l,
          vertical: HandySpace.s + 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            ),
            Text(
              value ?? '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
      );
      return HandyGroup(
        children: [
          row('links', tr(context, 'Links', 'Link'), u?.links.toString()),
          row(
            'pictures',
            tr(context, 'Your pictures', 'Ảnh của bạn'),
            u == null ? null : '${u.pictures} · ${formatBytes(u.pictureBytes)}',
          ),
          row(
            'reading',
            tr(context, 'Offline copies', 'Bản đọc ngoại tuyến'),
            u?.readingCopies.toString(),
          ),
          row(
            'deleted',
            tr(context, 'In Recently Deleted', 'Trong Thùng rác'),
            u?.deleted.toString(),
          ),
        ],
      );
    },
  );
}
