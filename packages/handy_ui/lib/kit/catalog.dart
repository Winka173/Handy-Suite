import 'package:flutter/material.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

class HandyCatalogEntry {
  final String id, title, hint, group;
  final IconData icon;
  final bool pinnable;

  /// Extra words that should find this entry (other-language names, aliases).
  final String keywords;
  const HandyCatalogEntry({
    required this.id,
    required this.title,
    required this.hint,
    required this.group,
    required this.icon,
    this.pinnable = true,
    this.keywords = '',
  });
}

/// The finder of every tool in an app (Ctrl K): a sheet on phones, a dialog
/// on wide screens. Search forgives missing accents. Returns the chosen id.
Future<String?> showHandyCatalog(
  BuildContext context, {
  required List<HandyCatalogEntry> entries,
  required List<String> groups,
  required Set<String> pinned,
  required Future<void> Function(String id) onTogglePin,
  required String searchHint,
}) {
  final body = _Catalog(
    entries: entries,
    groups: groups,
    pinned: pinned,
    onTogglePin: onTogglePin,
    searchHint: searchHint,
  );
  if (MediaQuery.sizeOf(context).width >= 720) {
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(heightFactor: .88, child: body),
  );
}

class _Catalog extends StatefulWidget {
  final List<HandyCatalogEntry> entries;
  final List<String> groups;
  final Set<String> pinned;
  final Future<void> Function(String id) onTogglePin;
  final String searchHint;
  const _Catalog({
    required this.entries,
    required this.groups,
    required this.pinned,
    required this.onTogglePin,
    required this.searchHint,
  });
  @override
  State<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends State<_Catalog> {
  String query = '';
  late final pins = {...widget.pinned};

  Future<void> pin(String id) async {
    try {
      await widget.onTogglePin(id);
      setState(() => pins.contains(id) ? pins.remove(id) : pins.add(id));
    } catch (_) {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Could not save. Nothing changed.',
            'Chưa lưu được. Không có gì thay đổi.',
          ),
        );
      }
    }
  }

  Widget row(BuildContext context, HandyCatalogEntry e) {
    final c = HandyColors.of(context);
    final on = pins.contains(e.id);
    return ListTile(
      key: Key('catalog-${e.id}'),
      minTileHeight: 52,
      leading: Icon(e.icon, size: 20),
      title: Text(e.title),
      subtitle: Text(e.hint, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: e.pinnable
          ? IconButton(
              key: Key('catalog-pin-${e.id}'),
              tooltip: on
                  ? tr(context, 'Unpin', 'Bỏ ghim')
                  : tr(context, 'Pin', 'Ghim'),
              icon: Icon(
                on ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
                color: on ? c.selectInk : c.muted,
              ),
              onPressed: () => pin(e.id),
            )
          : null,
      onTap: () => Navigator.pop(context, e.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final terms = foldAccents(
      query,
    ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final found = widget.entries.where((e) {
      final text = foldAccents('${e.id} ${e.title} ${e.hint} ${e.keywords}');
      return terms.every(text.contains);
    }).toList();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(HandyRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: HandySearchField(
              key: const Key('catalog-search'),
              autofocus: true,
              hint: widget.searchHint,
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: found.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(HandySpace.l),
                    child: HandyEmpty(
                      key: const Key('no-results'),
                      title: tr(
                        context,
                        'Nothing matches.',
                        'Không có kết quả phù hợp.',
                      ),
                      message: tr(
                        context,
                        'Try a shorter word.',
                        'Thử một từ ngắn hơn.',
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: HandySpace.l),
                    children: [
                      for (final g in widget.groups)
                        if (found.any((e) => e.group == g)) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              HandySpace.l,
                              HandySpace.m,
                              HandySpace.l,
                              HandySpace.xs,
                            ),
                            child: Text(
                              g,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: HandyColors.of(context).muted,
                              ),
                            ),
                          ),
                          for (final e in found.where((e) => e.group == g))
                            row(context, e),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
