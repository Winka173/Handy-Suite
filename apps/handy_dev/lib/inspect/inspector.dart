import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_workflow/handy_workflow.dart';
import 'detect.dart';
import 'inspection.dart';
import 'lens_bar.dart';
import 'lenses.dart';
import 'result_panel.dart';
import 'source_panel.dart';

Lens lensById(String id) => [
  for (final k in DataKind.values) ...lensesFor(k),
].firstWhere((l) => l.id == id, orElse: () => Lens(id, tool: id));

const examples = [
  (
    'JSON',
    '{"order": 1042, "items": [{"sku": "A-17", "qty": 2, "price": 129000}], "paid": true}',
  ),
  (
    'JWT',
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyLTQyIiwicm9sZSI6ImFkbWluIiwiZXhwIjoxNzk4NzYxNjAwfQ.',
  ),
  ('YAML', 'service: billing\nreplicas: 3\nports:\n  - 8080\n  - 9090'),
  (
    'cURL',
    "curl https://api.example.com/v1/orders/1042 -H 'Accept: application/json'",
  ),
  ('Base64', 'SGVsbG8gVmnhu4d0IE5hbQ=='),
];

/// Paste anything, see what it is and what is inside.
class Inspector extends StatefulWidget {
  final HandyFiles files;
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final ValueChanged<ApiRequest> onOpenRequest;
  const Inspector({
    super.key,
    required this.files,
    required this.read,
    required this.save,
    required this.onOpenRequest,
  });
  @override
  State<Inspector> createState() => InspectorState();
}

class InspectorState extends State<Inspector> {
  final input = TextEditingController(), option = TextEditingController();
  final focus = FocusNode();
  final chain = <String>[];
  int kind = 0, lens = 0;
  String? forced, path;

  @override
  void dispose() {
    input.dispose();
    option.dispose();
    focus.dispose();
    super.dispose();
  }

  void changed() => setState(() {
    kind = 0;
    lens = 0;
    path = null;
    chain.clear();
  });

  /// Opens a tool chosen from the finder, whatever the payload looks like.
  void use(String toolId, {String text = ''}) => setState(() {
    forced = toolId;
    if (text.isNotEmpty) input.text = text;
    option.clear();
    chain.clear();
    path = null;
  });

  void fill(String text) {
    input.text = text;
    forced = null;
    changed();
  }

  Future<void> saveFile(Inspection r) async {
    try {
      final uri = await widget.files.exportText('handy-dev.txt', r.copy);
      if (mounted && uri != null)
        showHandyMessage(context, tr(context, 'Saved', 'Đã lưu'));
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not save the file.', 'Chưa lưu được file.'),
        );
    }
  }

  Future<void> saveDraft(Lens l) async {
    final key = l.tool ?? 'json';
    try {
      final p = widget.read();
      await widget.save(p.copyWith(drafts: {...p.drafts, key: input.text}));
      if (mounted)
        showHandyMessage(context, tr(context, 'Draft saved', 'Đã lưu nháp'));
    } catch (_) {
      if (mounted)
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

  Future<void> saveChain(Recipe r) async {
    final p = widget.read();
    if (p.recipes.length >= 30)
      throw const FormatException('Up to 30 chains / Tối đa 30 chuỗi');
    await widget.save(p.copyWith(recipes: [...p.recipes, r]));
    if (mounted) setState(() {});
  }

  /// Draft save for the overflow menu; null when the lens is sensitive.
  VoidCallback? draftAction() {
    if (input.text.isEmpty) return null;
    final l = current().$2;
    return l.sensitive ? null : () => saveDraft(l);
  }

  (List<DataKind>, Lens, List<Lens>) current() {
    final kinds = detect(input.text);
    if (forced != null) {
      final l = lensById(forced!);
      return (kinds, l, [l]);
    }
    final k = kinds.isEmpty
        ? DataKind.text
        : kinds[kind.clamp(0, kinds.length - 1)];
    final lenses = lensesFor(k);
    return (kinds, lenses[lens.clamp(0, lenses.length - 1)], lenses);
  }

  Widget empty(BuildContext context) {
    final p = widget.read();
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: HandyColors.of(context).muted);
    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: muted),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: chips,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group(tr(context, 'Try one', 'Thử một mẫu'), [
          for (final e in examples)
            ActionChip(
              key: Key('example-${e.$1}'),
              label: Text(e.$1),
              onPressed: () => fill(e.$2),
            ),
        ]),
        if (p.favorites.isNotEmpty)
          group(tr(context, 'Pinned', 'Đã ghim'), [
            for (final id in p.favorites)
              ActionChip(
                key: Key('pinned-$id'),
                label: Text(lensById(id).title(context)),
                onPressed: () => use(id),
              ),
          ]),
        if (p.drafts.isNotEmpty)
          group(tr(context, 'Saved drafts', 'Nháp đã lưu'), [
            for (final d in p.drafts.entries)
              ActionChip(
                key: Key('draft-${d.key}'),
                avatar: const Icon(Icons.bookmark_outline, size: 18),
                label: Text(lensById(d.key).title(context)),
                onPressed: () => use(d.key, text: d.value),
              ),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (kinds, l, lenses) = current();
    final text = input.text;
    final r = text.trim().isEmpty
        ? null
        : inspect(
            text,
            kinds.isEmpty
                ? DataKind.text
                : kinds[kind.clamp(0, kinds.length - 1)],
            l,
            option: option.text,
            chain: chain,
          );
    final chainable_ = chainable.contains(l.id) || chain.isNotEmpty;
    final source = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SourcePanel(
          input: input,
          focus: focus,
          files: widget.files,
          onChanged: changed,
          onSaveDraft: draftAction(),
        ),
        const SizedBox(height: HandySpace.l),
        if (r != null) ...[
          LensBar(
            kinds: forced == null ? kinds : const [],
            kind: kind,
            lenses: lenses,
            lens: forced == null ? lens : 0,
            option: option,
            onKind: (i) => setState(() {
              kind = i;
              lens = 0;
              chain.clear();
            }),
            onLens: (i) => setState(() {
              lens = i;
              path = null;
              chain.clear();
            }),
            onOption: () => setState(() {}),
          ),
          if (forced != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('lens-auto'),
                onPressed: () => setState(() => forced = null),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(
                  tr(context, 'Detect automatically', 'Tự nhận dạng'),
                ),
              ),
            ),
          if (chainable_)
            HandyChainBar(
              chain: chain,
              saved: widget.read().recipes,
              steps: chainable.toList(),
              label: (c, id) => lensById(id).title(c),
              onAdd: (id) => setState(
                () => chain.isEmpty ? chain.addAll([l.id, id]) : chain.add(id),
              ),
              onRemove: (i) => setState(() => chain.removeAt(i)),
              onUse: (rec) => setState(
                () => chain
                  ..clear()
                  ..addAll(rec.steps),
              ),
              onSave: () => saveHandyChain(context, chain, saveChain),
            ),
        ] else
          empty(context),
      ],
    );
    // Another lens or kind fades the result over; edits update it in place.
    final result = HandySwap(
      child: r == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : ResultPanel(
              key: ValueKey('$kind-$lens-${r.error.isEmpty}'),
              result: r,
              input: text,
              path: path,
              onPath: (p) => setState(() => path = p),
              onCopy: () => copyToClipboard(context, r.copy),
              onSave: () => saveFile(r),
              onOpenRequest: widget.onOpenRequest,
            ),
    );
    return LayoutBuilder(
      builder: (context, size) {
        const pad = EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.l,
          HandySpace.l,
          HandySpace.xxl,
        );
        if (size.maxWidth < 900) {
          return ListView(
            padding: pad,
            children: [
              source,
              if (r != null) ...[const SizedBox(height: HandySpace.xl), result],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ListView(padding: pad, children: [source]),
            ),
            Expanded(
              flex: 6,
              child: ListView(
                padding: pad,
                children: [
                  if (r == null)
                    HandyEmpty(
                      title: tr(
                        context,
                        'The result appears here.',
                        'Kết quả hiện ở đây.',
                      ),
                      message: tr(
                        context,
                        'Paste on the left or try a sample.',
                        'Dán ở bên trái hoặc thử một mẫu.',
                      ),
                    )
                  else
                    result,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
