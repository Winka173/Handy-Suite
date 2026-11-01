import 'package:flutter/material.dart';
import 'app.dart';
import 'l10n.dart';
import 'theme.dart';

/// The suite's top bar: the app's mark and name, an optional switch between
/// its areas, the finder (Ctrl K) or the app's own [actions], and settings.
/// Nothing else lives up here.
class HandyTopBar extends StatelessWidget implements PreferredSizeWidget {
  final IconData mark;
  final String name;

  /// Opens the finder; leave null when the screen itself is the search.
  final VoidCallback? onFind;
  final String findLabel;

  /// App actions before settings (Keep's label scanner, for example).
  final List<Widget> actions;

  /// Marks the name as the screen's heading when no other title is shown.
  final bool nameIsTitle;

  /// Area switch, placed after the name (a segmented control, for example).
  final Widget? areas;
  const HandyTopBar({
    super.key,
    required this.mark,
    required this.name,
    this.onFind,
    this.findLabel = '',
    this.actions = const [],
    this.nameIsTitle = true,
    this.areas,
  });
  @override
  Size get preferredSize => const Size.fromHeight(60);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final c = HandyColors.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      titleSpacing: HandySpace.l,
      title: Row(
        children: [
          HandyMark(mark, size: 30),
          const SizedBox(width: HandySpace.m),
          // On narrow screens the area switch takes the name's place.
          if (areas == null || width >= 560)
            Flexible(
              child: Semantics(
                header: nameIsTitle,
                child: Text(
                  name,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (areas != null) ...[
            const SizedBox(width: HandySpace.l),
            Flexible(child: areas!),
          ],
        ],
      ),
      actions: [
        ...actions,
        if (onFind == null)
          const SizedBox.shrink()
        else if (width >= 720)
          Padding(
            padding: const EdgeInsets.only(right: HandySpace.s),
            child: OutlinedButton.icon(
              key: const Key('open-catalog'),
              onPressed: onFind,
              icon: const Icon(Icons.search, size: 18),
              label: Row(
                children: [
                  Text(findLabel),
                  const SizedBox(width: HandySpace.l),
                  Text(
                    'Ctrl K',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          IconButton(
            key: const Key('open-catalog'),
            tooltip: findLabel,
            icon: const Icon(Icons.search),
            onPressed: onFind,
          ),
        IconButton(
          key: const Key('open-settings'),
          tooltip: tr(context, 'Settings', 'Cài đặt'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
        const SizedBox(width: HandySpace.s),
      ],
    );
  }
}
