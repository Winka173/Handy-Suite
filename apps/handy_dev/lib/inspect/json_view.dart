import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';

/// `/items/3/price` (the engine's pointer) → `$.items[3].price`.
String jsonPathOf(JsonTreeIndex index, String pointer) {
  final parts = <String>[];
  var node = index.nodes[pointer];
  while (node != null && node.parent != null) {
    final parent = index.nodes[node.parent]!;
    final key = node.key;
    parts.add(
      parent.kind == 'array'
          ? '[$key]'
          : RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*$').hasMatch(key)
          ? '.$key'
          : "['${key.replaceAll("'", r"\'")}']",
    );
    node = parent;
  }
  return '\$${parts.reversed.join()}';
}

/// Collapsible tree of a JSON value with search. Choosing a row reports its
/// JSONPath, which the status line shows and copies.
class JsonTreeView extends StatefulWidget {
  final dynamic value;
  final ValueChanged<String> onSelect;
  const JsonTreeView({super.key, required this.value, required this.onSelect});
  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  late JsonTreeIndex index;
  final expanded = <String>{''};
  String query = '', selected = '';
  String? error;

  @override
  void initState() {
    super.initState();
    reindex();
  }

  @override
  void didUpdateWidget(JsonTreeView old) {
    super.didUpdateWidget(old);
    if (!identical(old.value, widget.value)) reindex();
  }

  void reindex() {
    try {
      index = indexJson(widget.value);
      error = null;
      expanded
        ..clear()
        ..add('')
        ..addAll(index.nodes['']!.children.take(20));
    } on FormatException catch (e) {
      error = e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return HandyNotice(error!, tone: HandyTone.error);
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    List<JsonTreeNode> rows;
    try {
      rows = visibleJsonRows(index, expanded, query);
    } on FormatException catch (e) {
      return HandyNotice(e.message, tone: HandyTone.error);
    }
    final code = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
      fontSize: 13.5,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandySearchField(
          key: const Key('tree-search'),
          hint: tr(context, 'Find a key or value', 'Tìm khóa hoặc giá trị'),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: HandySpace.s),
        Card(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final n = rows[i];
                final branch = n.kind == 'object' || n.kind == 'array';
                final open = expanded.contains(n.path) || query.isNotEmpty;
                final path = jsonPathOf(index, n.path);
                return Material(
                  color: n.path == selected ? c.select : Colors.transparent,
                  child: InkWell(
                    key: Key('tree-row-$path'),
                    onTap: () {
                      setState(() {
                        selected = n.path;
                        if (branch && query.isEmpty) {
                          open ? expanded.remove(n.path) : expanded.add(n.path);
                        }
                      });
                      widget.onSelect(path);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: HandySpace.s + n.depth * 16.0,
                          right: HandySpace.m,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: branch
                                  ? AnimatedRotation(
                                      turns: open ? .25 : 0,
                                      duration: HandyMotion.of(
                                        context,
                                        HandyMotion.short,
                                      ),
                                      curve: HandyMotion.curve,
                                      child: Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color: c.muted,
                                      ),
                                    )
                                  : null,
                            ),
                            // Long keys give way before the value does.
                            Flexible(
                              child: Text(
                                n.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: code?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(': ', style: code?.copyWith(color: c.muted)),
                            Expanded(
                              child: Text(
                                n.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: code?.copyWith(
                                  color: branch ? c.muted : c.selectInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
