import 'package:handy_ui/kit.dart';

/// The four ways to begin, in the order people need them.
class StartGrid extends StatelessWidget {
  final bool camera;
  final ValueChanged<String> onStart;
  const StartGrid({super.key, required this.camera, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'scan',
        Icons.document_scanner_outlined,
        tr(context, 'Scan paper', 'Quét giấy tờ'),
        camera
            ? tr(
                context,
                'Photograph pages, get one PDF',
                'Chụp các trang, ra một PDF',
              )
            : tr(
                context,
                'Straighten photos of pages into a PDF',
                'Nắn ảnh các trang thành PDF',
              ),
      ),
      (
        'write',
        Icons.edit_note,
        tr(context, 'Write Markdown', 'Viết Markdown'),
        tr(
          context,
          'See it as a page, export PDF or HTML',
          'Xem như trang in, xuất PDF hay HTML',
        ),
      ),
      (
        'pdf',
        Icons.picture_as_pdf_outlined,
        tr(context, 'Merge and fix PDFs', 'Ghép và sửa PDF'),
        tr(
          context,
          'Pick, reorder, turn and stamp pages',
          'Chọn, sắp, xoay và đóng dấu trang',
        ),
      ),
      (
        'read',
        Icons.chrome_reader_mode_outlined,
        tr(context, 'Read a file', 'Đọc một tệp'),
        tr(
          context,
          'Text, Markdown, web pages and code',
          'Văn bản, Markdown, trang web và mã',
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 840 ? 4 : (box.maxWidth >= 560 ? 2 : 1);
        final width = (box.maxWidth - (columns - 1) * HandySpace.m) / columns;
        return Wrap(
          spacing: HandySpace.m,
          runSpacing: HandySpace.m,
          children: [
            for (final (id, icon, title, hint) in items)
              SizedBox(
                width: width,
                child: _Start(
                  row: columns == 1,
                  id: id,
                  icon: icon,
                  title: title,
                  hint: hint,
                  onTap: () => onStart(id),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Start extends StatelessWidget {
  final String id, title, hint;
  final IconData icon;
  final VoidCallback onTap;

  /// One line per start on phones: the icon beside the words.
  final bool row;
  const _Start({
    required this.row,
    required this.id,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: HandySpace.xs),
        Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
      ],
    );
    return Material(
      color: c.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('desk-$id'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(row ? HandySpace.m : HandySpace.l),
          child: row
              ? Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.primary, size: 26),
                    const SizedBox(width: HandySpace.l),
                    Expanded(child: words),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(height: HandySpace.m),
                    words,
                  ],
                ),
        ),
      ),
    );
  }
}
