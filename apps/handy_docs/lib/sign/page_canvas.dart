import 'package:flutter/services.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import 'fill_controller.dart';

/// Ink for filled-in text: near-black, as on the copy.
const fillInk = Color(0xFF1A1A1A);

/// Filled-in text drawn exactly as the copy draws it: the line stretched
/// to its box, Geist, the same baseline.
TextStyle fillStyle() => const TextStyle(
  fontFamily: 'Geist',
  package: 'handy_ui',
  fontSize: 100,
  height: textLineHeight,
  leadingDistribution: TextLeadingDistribution.even,
  color: fillInk,
);

/// Width ÷ height of [text] set on one line in [fillStyle].
double textAspect(String text) {
  final p = TextPainter(
    text: TextSpan(text: text, style: fillStyle()),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final aspect = p.width / p.height;
  p.dispose();
  return aspect.clamp(.2, 80.0);
}

/// One page as a sheet of paper with its marks on it. Drag a mark to move
/// it, drag its corner to resize it; arrows nudge, Delete removes.
class PageCanvas extends StatelessWidget {
  final FillController fill;
  final double width;
  const PageCanvas({super.key, required this.fill, required this.width});

  @override
  Widget build(BuildContext context) {
    final height = width / fill.pageAspect;
    final picture = fill.picture;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) => _key(event),
      child: GestureDetector(
        onTap: () => fill.select(null),
        child: Container(
          key: const Key('fill-page'),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: HandyColors.of(context).border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (picture != null)
                Positioned.fill(
                  child: Image.memory(
                    picture,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    semanticLabel: tr(
                      context,
                      'Page ${fill.page + 1}',
                      'Trang ${fill.page + 1}',
                    ),
                  ),
                ),
              for (final p in fill.onPage)
                _Mark(
                  key: ValueKey(p.id),
                  fill: fill,
                  mark: p,
                  width: width,
                  height: height,
                ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _key(KeyEvent event) {
    final id = fill.selected;
    if (id == null || event is KeyUpEvent) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? .05 : .01;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      fill.remove(id);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      fill.move(id, -step, 0);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      fill.move(id, step, 0);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      fill.move(id, 0, -step);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      fill.move(id, 0, step);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

class _Mark extends StatelessWidget {
  final FillController fill;
  final Placed mark;
  final double width, height;
  const _Mark({
    super.key,
    required this.fill,
    required this.mark,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final b = mark.box;
    final on = fill.selected == mark.id;
    final primary = Theme.of(context).colorScheme.primary;
    final what = switch (mark.kind) {
      MarkKind.signature => tr(context, 'Signature', 'Chữ ký'),
      MarkKind.date => '${tr(context, 'Date', 'Ngày')} ${mark.text}',
      MarkKind.text => mark.text,
    };
    return Positioned(
      left: b.left * width,
      top: b.top * height,
      width: b.width * width,
      height: b.height * height,
      child: Semantics(
        button: true,
        selected: on,
        label: what,
        child: GestureDetector(
          key: Key('fill-mark-${mark.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => fill.select(mark.id),
          onPanStart: (_) => fill.select(mark.id),
          onPanUpdate: (d) =>
              fill.move(mark.id, d.delta.dx / width, d.delta.dy / height),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: on ? primary : const Color(0x00000000),
                      width: 1.5,
                    ),
                  ),
                  child: mark.kind == MarkKind.signature
                      ? Image.memory(
                          mark.png!,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        )
                      : FittedBox(
                          fit: BoxFit.fill,
                          child: Text(
                            mark.text,
                            maxLines: 1,
                            softWrap: false,
                            style: fillStyle(),
                          ),
                        ),
                ),
              ),
              if (on) ...[
                Positioned(
                  right: -16,
                  bottom: -16,
                  child: Tooltip(
                    message: tr(context, 'Drag to resize', 'Kéo để đổi cỡ'),
                    child: GestureDetector(
                      key: Key('fill-resize-${mark.id}'),
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) =>
                          fill.resize(mark.id, d.delta.dx / width),
                      child: SizedBox.square(
                        dimension: 32,
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -14,
                  top: -14,
                  child: Material(
                    color: Colors.white,
                    shape: CircleBorder(side: BorderSide(color: primary)),
                    child: InkWell(
                      key: Key('fill-remove-${mark.id}'),
                      customBorder: const CircleBorder(),
                      onTap: () => fill.remove(mark.id),
                      child: Tooltip(
                        message: tr(context, 'Remove', 'Gỡ'),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 16, color: primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
