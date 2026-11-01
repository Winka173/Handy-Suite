import 'package:flutter/material.dart';
import 'kit/l10n.dart';
import 'kit/theme.dart';
export 'package:flutter/material.dart';
export 'kit/l10n.dart';

/// Legacy entry point; apps not yet rebuilt still get the new visual language.
ThemeData handyTheme(Color accent, Brightness brightness) =>
    buildHandyTheme(accent, brightness);

class HandyScaffold extends StatelessWidget {
  final String title;
  final List<NavigationDestination> destinations;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget body;
  final List<Widget>? actions;
  const HandyScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.body,
    this.actions,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide = size.maxWidth >= 800;
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: selected,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (d) => NavigationRailDestination(
                        icon: d.icon,
                        label: Text(d.label),
                      ),
                    )
                    .toList(),
              ),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: onSelect,
                destinations: destinations,
              ),
      );
    },
  );
}

class HandyErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const HandyErrorState(this.message, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          SelectableText(message),
          if (retry != null)
            TextButton(
              onPressed: retry,
              child: Text(tr(context, 'Retry', 'Thử lại')),
            ),
        ],
      ),
    ),
  );
}

class HandyEmptyState extends StatelessWidget {
  final String message;
  const HandyEmptyState(this.message, {super.key});
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(24), child: Text(message));
}

class HandyToolCard extends StatelessWidget {
  final String title, description;
  final VoidCallback onOpen;
  final bool pinned;
  final VoidCallback onPin;
  const HandyToolCard({
    super.key,
    required this.title,
    required this.description,
    required this.onOpen,
    required this.pinned,
    required this.onPin,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(title),
    subtitle: Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
    onTap: onOpen,
    trailing: IconButton(
      tooltip: tr(
        context,
        pinned ? 'Unpin' : 'Pin',
        pinned ? 'Bỏ ghim' : 'Ghim',
      ),
      onPressed: onPin,
      icon: Icon(pinned ? Icons.star : Icons.star_border),
    ),
  );
}
