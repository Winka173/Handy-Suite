import 'package:handy_ui/kit.dart';

/// One piece of unfinished work on the desk: its papers, what it is, and
/// how far along. The top sheet lifts a little under the pointer.
class WorkCard extends StatefulWidget {
  final Widget papers;
  final String title, detail;
  final VoidCallback onOpen;
  const WorkCard({
    super.key,
    required this.papers,
    required this.title,
    required this.detail,
    required this.onOpen,
  });
  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  bool lifted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Two to a row on a phone, so no half of the desk stands empty.
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        width: ((box.maxWidth - HandySpace.s) / 2).clamp(120, 168),
        child: Semantics(
          button: true,
          label: '${widget.title}, ${widget.detail}',
          excludeSemantics: true,
          child: InkWell(
            onTap: widget.onOpen,
            onHover: (v) => setState(() => lifted = v),
            onHighlightChanged: (v) => setState(() => lifted = v),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSlide(
                    offset: lifted ? const Offset(0, -.025) : Offset.zero,
                    duration: HandyMotion.of(context, HandyMotion.short),
                    curve: HandyMotion.curve,
                    child: widget.papers,
                  ),
                  const SizedBox(height: HandySpace.m),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: HandyColors.of(context).muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
