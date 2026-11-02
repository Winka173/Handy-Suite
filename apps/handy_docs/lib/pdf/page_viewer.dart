import 'package:handy_ui/kit.dart';
import '../ui/paper.dart';
import 'pdf_desk.dart';

/// The open files as chips, and the current page of the chosen one on a
/// sheet, with turning and saving the page as a picture.
class PageViewer extends StatelessWidget {
  final PdfDesk desk;
  final bool busy;
  final double width;
  final void Function(int) onSelect, onRemove, onTurn;
  final VoidCallback onSavePage, onRead;
  const PageViewer({
    super.key,
    required this.desk,
    required this.busy,
    required this.width,
    required this.onSelect,
    required this.onRemove,
    required this.onTurn,
    required this.onSavePage,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
            children: [
              for (final (i, f) in desk.inputs.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: HandySpace.s),
                  child: InputChip(
                    key: Key('pdf-file-$i'),
                    label: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(f.name, overflow: TextOverflow.ellipsis),
                    ),
                    selected: i == desk.selected,
                    showCheckmark: false,
                    onSelected: busy || i == desk.selected
                        ? null
                        : (_) => onSelect(i),
                    deleteButtonTooltipMessage: tr(
                      context,
                      'Close ${f.name}',
                      'Đóng ${f.name}',
                    ),
                    onDeleted: busy ? null : () => onRemove(i),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: HandySpace.m),
        HandySwap(
          child: KeyedSubtree(
            key: ValueKey('${desk.selected}-${desk.page}'),
            child: Semantics(
              image: true,
              label: tr(
                context,
                'Page ${desk.page + 1} of ${desk.inputs[desk.selected].name}',
                'Trang ${desk.page + 1} của ${desk.inputs[desk.selected].name}',
              ),
              child: Paper(
                key: const Key('pdf-preview'),
                width: width,
                image: desk.preview,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(height: HandySpace.s),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('pdf-previous'),
              tooltip: tr(context, 'Previous page', 'Trang trước'),
              onPressed: busy || desk.page == 0
                  ? null
                  : () => onTurn(desk.page - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              tr(
                context,
                'Page ${desk.page + 1} of ${desk.pages}',
                'Trang ${desk.page + 1} / ${desk.pages}',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              key: const Key('pdf-next'),
              tooltip: tr(context, 'Next page', 'Trang sau'),
              onPressed: busy || desk.page + 1 >= desk.pages
                  ? null
                  : () => onTurn(desk.page + 1),
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: const Key('pdf-page-png'),
              tooltip: tr(
                context,
                'Save this page as a picture',
                'Lưu trang này thành ảnh',
              ),
              onPressed: busy || desk.preview == null ? null : onSavePage,
              icon: const Icon(Icons.image_outlined),
            ),
            IconButton(
              key: const Key('pdf-page-ocr'),
              tooltip: tr(
                context,
                'Read the text on this page',
                'Nhận dạng chữ trang này',
              ),
              onPressed: busy || desk.document == null ? null : onRead,
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
