import 'package:handy_ui/kit.dart';

/// The same actions by mouse, touch or a visible keyboard-focusable button.
class HabitContextMenu extends StatelessWidget {
  final List<HandyMenuItem> items;
  final Widget child;
  const HabitContextMenu({super.key, required this.items, required this.child});
  @override
  Widget build(BuildContext context) {
    Future<void> open(Offset at) async {
      final overlay =
          Navigator.of(context).overlay!.context.findRenderObject()!
              as RenderBox;
      final position = overlay.globalToLocal(at);
      final selected = await showMenu<int>(
        context: context,
        position: RelativeRect.fromSize(
          Rect.fromLTWH(position.dx, position.dy, 0, 0),
          overlay.size,
        ),
        popUpAnimationStyle: AnimationStyle(
          duration: HandyMotion.of(context),
          reverseDuration: HandyMotion.of(context),
        ),
        items: habitMenuEntries(context, items),
      );
      if (selected != null && context.mounted) items[selected].onTap?.call();
    }

    return GestureDetector(
      // More is the accessible alternative to these pointer gestures.
      excludeFromSemantics: true,
      onLongPressStart: (details) => open(details.globalPosition),
      onSecondaryTapDown: (details) => open(details.globalPosition),
      child: child,
    );
  }
}

List<PopupMenuEntry<int>> habitMenuEntries(
  BuildContext context,
  List<HandyMenuItem> items,
) => [
  for (var i = 0; i < items.length; i++)
    PopupMenuItem<int>(
      key: items[i].key,
      value: i,
      height: 48,
      enabled: items[i].onTap != null,
      child: Row(
        children: [
          Icon(
            items[i].icon,
            size: 20,
            color: items[i].destructive
                ? HandyColors.of(context).negative
                : HandyColors.of(context).muted,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(items[i].label)),
        ],
      ),
    ),
];

class HabitMenuButton extends StatelessWidget {
  final List<HandyMenuItem> items;
  final String? tooltip;
  const HabitMenuButton({super.key, required this.items, this.tooltip});
  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
    key: const Key('more-menu'),
    tooltip: tooltip ?? tr(context, 'More', 'Thêm'),
    icon: const Icon(Icons.more_horiz),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 340),
    popUpAnimationStyle: AnimationStyle(
      duration: HandyMotion.of(context),
      reverseDuration: HandyMotion.of(context),
    ),
    onSelected: (i) => items[i].onTap?.call(),
    itemBuilder: (context) => habitMenuEntries(context, items),
  );
}
