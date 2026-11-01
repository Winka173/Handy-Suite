import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../session.dart';
import '../ui/paper.dart';
import 'scan_store.dart';

/// The scanned pages as sheets, in order. Tap a sheet to fix its corners;
/// its menu moves, saves or deletes it. A new page rises into place.
class PageGrid extends StatelessWidget {
  final ScanStore store;
  final bool busy;
  final HandyFiles files;
  final ValueChanged<ScanPage> onEdit;
  final Future<void> Function(Future<void> Function(), {String? done}) onRun;
  const PageGrid({
    super.key,
    required this.store,
    required this.busy,
    required this.files,
    required this.onEdit,
    required this.onRun,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final pages = store.pages;
      final columns = (box.maxWidth / 180).floor().clamp(2, 6);
      final width = (box.maxWidth - (columns - 1) * HandySpace.l) / columns;
      return Wrap(
        spacing: HandySpace.l,
        runSpacing: HandySpace.l,
        children: [
          for (final (i, p) in pages.indexed)
            _Appear(
              key: ValueKey('scan-page-${p.id}'),
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    label: tr(
                      context,
                      'Page ${i + 1}, fix corners',
                      'Trang ${i + 1}, sửa góc',
                    ),
                    child: InkWell(
                      onTap: busy ? null : () => onEdit(p),
                      child: Paper(width: width, image: p.png),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i + 1}. ${p.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      HandyMenuButton(
                        items: [
                          HandyMenuItem(
                            Icons.crop,
                            tr(context, 'Fix corners', 'Sửa góc'),
                            busy ? null : () => onEdit(p),
                          ),
                          HandyMenuItem(
                            Icons.arrow_back,
                            tr(context, 'Move earlier', 'Lên trước'),
                            i == 0 || busy
                                ? null
                                : () => onRun(() => store.move(i, i - 1)),
                          ),
                          HandyMenuItem(
                            Icons.arrow_forward,
                            tr(context, 'Move later', 'Ra sau'),
                            i == pages.length - 1 || busy
                                ? null
                                : () => onRun(() => store.move(i, i + 1)),
                          ),
                          HandyMenuItem(
                            Icons.image_outlined,
                            tr(context, 'Save as PNG', 'Lưu PNG'),
                            () => onRun(
                              () async => files.exportBytes(
                                'scan-page-${i + 1}.png',
                                p.png,
                                mimeType: 'image/png',
                              ),
                            ),
                          ),
                          HandyMenuItem(
                            Icons.delete_outline,
                            tr(context, 'Delete', 'Xóa'),
                            busy
                                ? null
                                : () async {
                                    final ok = await confirmHandy(
                                      context,
                                      title: tr(
                                        context,
                                        'Delete page ${i + 1}?',
                                        'Xóa trang ${i + 1}?',
                                      ),
                                      confirmLabel: tr(
                                        context,
                                        'Delete',
                                        'Xóa',
                                      ),
                                      destructive: true,
                                    );
                                    if (ok)
                                      await onRun(() => store.remove(p.id));
                                  },
                            destructive: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// A page that rises and fades in the first time it is shown.
class _Appear extends StatelessWidget {
  final double width;
  final Widget child;
  const _Appear({super.key, required this.width, required this.child});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: HandyMotion.of(context, HandyMotion.long),
      curve: HandyMotion.curve,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    ),
  );
}
