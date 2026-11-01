import 'package:flutter/material.dart';
import 'package:handy_workflow/handy_workflow.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Text transforms as chips. Tapping adds a step; the steps read as a chain
/// that can be saved and reused (a workflow, built by doing).
class HandyChainBar extends StatelessWidget {
  final List<String> chain;
  final List<Recipe> saved;

  /// Steps offered as chips, and how each is named.
  final List<String> steps;
  final String Function(BuildContext, String) label;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<Recipe> onUse;
  final VoidCallback onSave;
  const HandyChainBar({
    super.key,
    required this.chain,
    required this.saved,
    required this.steps,
    required this.label,
    required this.onAdd,
    required this.onRemove,
    required this.onUse,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: c.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chain.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.m,
              HandySpace.s,
              HandySpace.xs,
              HandySpace.s,
            ),
            decoration: BoxDecoration(
              color: c.select,
              borderRadius: BorderRadius.circular(HandyRadius.control),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: HandySpace.xs,
                    runSpacing: HandySpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < chain.length; i++) ...[
                        if (i > 0)
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: c.selectInk,
                          ),
                        InputChip(
                          key: Key('chain-step-$i'),
                          label: Text(label(context, chain[i])),
                          onDeleted: () => onRemove(i),
                          deleteButtonTooltipMessage: tr(
                            context,
                            'Remove step',
                            'Bỏ bước',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('chain-save'),
                  onPressed: onSave,
                  child: Text(tr(context, 'Save chain', 'Lưu chuỗi')),
                ),
              ],
            ),
          ),
          const SizedBox(height: HandySpace.m),
        ],
        Text(
          chain.isEmpty
              ? tr(
                  context,
                  'Showing counts. Change the text:',
                  'Đang đếm. Biến đổi văn bản:',
                )
              : tr(context, 'Then:', 'Tiếp theo:'),
          style: muted,
        ),
        const SizedBox(height: HandySpace.s),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final r in saved)
              ActionChip(
                key: Key('chain-use-${r.name}'),
                avatar: const Icon(Icons.bolt, size: 18),
                label: Text(r.name),
                onPressed: () => onUse(r),
              ),
            for (final id in steps)
              ActionChip(
                key: Key('transform-$id'),
                label: Text(label(context, id)),
                onPressed: chain.length >= 20 ? null : () => onAdd(id),
              ),
          ],
        ),
      ],
    );
  }
}

/// Names the current chain and stores it as a workflow recipe.
Future<void> saveHandyChain(
  BuildContext context,
  List<String> steps,
  Future<void> Function(Recipe) save,
) async {
  final name = TextEditingController();
  final ok = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr(context, 'Save this chain', 'Lưu chuỗi này')),
      content: TextField(
        key: const Key('chain-name'),
        controller: name,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(
          hintText: tr(context, 'e.g. Clean a list', 'VD: Làm sạch danh sách'),
          counterText: '',
        ),
        onSubmitted: (_) => Navigator.pop(context, true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr(context, 'Cancel', 'Hủy')),
        ),
        FilledButton(
          key: const Key('chain-save-confirm'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    ),
  );
  // Not disposed here: the dialog's field still paints during its exit
  // animation. The controller holds no listeners and is collected with it.
  final label = name.text.trim();
  if (ok != true || label.isEmpty || !context.mounted) return;
  try {
    await save(Recipe(label, steps));
    if (context.mounted)
      showHandyMessage(context, tr(context, 'Chain saved', 'Đã lưu chuỗi'));
  } catch (e) {
    if (context.mounted)
      showHandyMessage(
        context,
        e is FormatException
            ? e.message
            : tr(
                context,
                'Could not save. Nothing changed.',
                'Chưa lưu được. Không có gì thay đổi.',
              ),
      );
  }
}
