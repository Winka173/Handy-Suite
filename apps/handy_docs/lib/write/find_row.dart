import 'package:handy_ui/kit.dart';
import 'draft.dart';

/// Find and replace, one row over the text. Matches are literal: what is
/// typed is what is found, and the replacement is inserted as written.
class FindRow extends StatefulWidget {
  final DraftController draft;
  final VoidCallback onClose;
  const FindRow({super.key, required this.draft, required this.onClose});
  @override
  State<FindRow> createState() => _FindRowState();
}

class _FindRowState extends State<FindRow> {
  final query = TextEditingController(), replacement = TextEditingController();
  String count = '';

  @override
  void dispose() {
    query.dispose();
    replacement.dispose();
    super.dispose();
  }

  void find() {
    final m = widget.draft.find(query.text);
    setState(
      () => count = query.text.isEmpty
          ? ''
          : m.count == 0
          ? tr(context, 'No matches', 'Không thấy')
          : tr(
              context,
              '${m.count} found · first at line ${m.line}',
              '${m.count} chỗ · đầu tiên ở dòng ${m.line}',
            ),
    );
  }

  void replaceAll() {
    final n = widget.draft.find(query.text).count;
    if (n == 0) return find();
    widget.draft.replaceAll(query.text, replacement.text);
    setState(() => count = tr(context, 'Replaced $n', 'Đã thay $n chỗ'));
  }

  @override
  Widget build(BuildContext context) {
    final fields = [
      TextField(
        key: const Key('markdown-find'),
        controller: query,
        autofocus: true,
        onChanged: (_) => find(),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          hintText: tr(context, 'Find', 'Tìm'),
        ),
      ),
      TextField(
        key: const Key('markdown-replacement'),
        controller: replacement,
        onSubmitted: (_) => replaceAll(),
        decoration: InputDecoration(
          isDense: true,
          hintText: tr(context, 'Replace with', 'Thay bằng'),
        ),
      ),
    ];
    final actions = [
      Expanded(
        child: Text(
          count,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        key: const Key('markdown-replace-all'),
        onPressed: replaceAll,
        child: Text(tr(context, 'Replace all', 'Thay tất cả')),
      ),
      IconButton(
        key: const Key('markdown-find-close'),
        tooltip: tr(context, 'Close find', 'Đóng tìm kiếm'),
        onPressed: widget.onClose,
        icon: const Icon(Icons.close),
      ),
    ];
    return Material(
      color: HandyColors.of(context).raised,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.s,
          HandySpace.s,
          HandySpace.s,
        ),
        child: LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 720
              ? Row(
                  children: [
                    for (final f in fields) ...[
                      Expanded(flex: 2, child: f),
                      const SizedBox(width: HandySpace.s),
                    ],
                    ...actions,
                  ],
                )
              : Column(
                  children: [
                    fields[0],
                    const SizedBox(height: HandySpace.s),
                    fields[1],
                    Row(children: actions),
                  ],
                ),
        ),
      ),
    );
  }
}
