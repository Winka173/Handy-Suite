import 'dart:convert';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'kit.dart';
import 'package:handy_workflow/handy_workflow.dart';

class SharedWorkflowPage extends StatefulWidget {
  final HandyPreferences preferences;
  final Future<void> Function(HandyPreferences) onSave;
  final HandyFiles files;
  final Map<String, WorkflowStep> registry;
  const SharedWorkflowPage({
    super.key,
    required this.preferences,
    required this.onSave,
    required this.files,
    required this.registry,
  });
  @override
  State<SharedWorkflowPage> createState() => _SharedWorkflowPageState();
}

class _SharedWorkflowPageState extends State<SharedWorkflowPage> {
  final name = TextEditingController(), input = TextEditingController();
  final steps = <String>[];
  String chosen = 'uppercase', output = '', message = '';
  bool busy = false;
  double progress = 0;
  CancellationToken? cancellation;
  Map<String, WorkflowStep> get registry => widget.registry;
  late HandyPreferences current = widget.preferences;
  @override
  void didUpdateWidget(covariant SharedWorkflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences)
      current = widget.preferences;
  }

  Future<void> saveRecipe() async {
    final next = recipe();
    plan(next, registry, 'text/plain');
    if (current.recipes.length >= 30)
      throw const FormatException('Workflow limit: 30');
    final prefs = current.copyWith(recipes: [...current.recipes, next]);
    await widget.onSave(prefs);
    if (mounted) setState(() => current = prefs);
  }

  @override
  void dispose() {
    cancellation?.cancel();
    name.dispose();
    input.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
    } on Cancelled {
      if (mounted)
        setState(
          () => message = tr(context, 'Workflow canceled', 'Đã hủy quy trình'),
        );
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          cancellation = null;
        });
    }
  }

  Recipe recipe() => Recipe(name.text, steps);
  @override
  Widget build(BuildContext context) {
    final candidates = registry.keys.toList();
    if (!candidates.contains(chosen) && candidates.isNotEmpty)
      chosen = candidates.first;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(context, 'Text workflows', 'Quy trình văn bản'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        TextField(
          controller: name,
          enabled: !busy,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: tr(context, 'Workflow name', 'Tên quy trình'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: chosen,
          isExpanded: true,
          items: candidates
              .map((id) => DropdownMenuItem(value: id, child: Text(id)))
              .toList(),
          onChanged: busy ? null : (v) => setState(() => chosen = v!),
        ),
        TextButton(
          onPressed: busy || steps.length >= 20
              ? null
              : () => setState(() {
                  steps.add(chosen);
                  output = '';
                }),
          child: Text(tr(context, 'Add step', 'Thêm bước')),
        ),
        for (var i = 0; i < steps.length; i++)
          ListTile(
            title: Text('${i + 1}. ${steps[i]}'),
            trailing: IconButton(
              tooltip: tr(context, 'Remove step', 'Bỏ bước'),
              onPressed: busy
                  ? null
                  : () => setState(() {
                      steps.removeAt(i);
                      output = '';
                    }),
              icon: const Icon(Icons.close),
            ),
          ),
        TextField(
          controller: input,
          enabled: !busy,
          maxLength: 1000000,
          onChanged: (_) => setState(() => output = ''),
          maxLines: 5,
          decoration: InputDecoration(
            labelText: tr(context, 'Input text', 'Văn bản đầu vào'),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      cancellation = CancellationToken();
                      setState(() {
                        progress = 0;
                        output = '';
                      });
                      final value = await execute(
                        recipe(),
                        registry,
                        input.text,
                        cancellation: cancellation,
                        progress: (done, total) {
                          if (mounted) setState(() => progress = done / total);
                        },
                      );
                      if (mounted) setState(() => output = value);
                    }),
              child: Text(tr(context, 'Run workflow', 'Chạy quy trình')),
            ),
            OutlinedButton(
              onPressed: busy ? () => cancellation?.cancel() : null,
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final p = plan(recipe(), registry, 'text/plain');
                      setState(() => message = p.map((s) => s.id).join(' → '));
                    }),
              child: Text(tr(context, 'Preview steps', 'Xem trước bước')),
            ),
            OutlinedButton(
              onPressed: busy ? null : () => run(saveRecipe),
              child: Text(tr(context, 'Save workflow', 'Lưu quy trình')),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await widget.files.exportText(
                        'workflow.json',
                        recipe().export(),
                      );
                    }),
              child: Text(tr(context, 'Export workflow', 'Xuất quy trình')),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      final file = await widget.files.importText();
                      if (file == null) return;
                      final r = Recipe.fromJson(jsonDecode(file.text));
                      plan(r, registry, 'text/plain');
                      setState(() {
                        output = '';
                        name.text = r.name;
                        steps
                          ..clear()
                          ..addAll(r.steps);
                      });
                    }),
              child: Text(tr(context, 'Import workflow', 'Nhập quy trình')),
            ),
          ],
        ),
        if (busy && cancellation != null) ...[
          LinearProgressIndicator(value: progress),
          TextButton(
            key: const Key('workflow-cancel'),
            onPressed: () => cancellation?.cancel(),
            child: Text(tr(context, 'Cancel workflow', 'Hủy quy trình')),
          ),
        ],
        if (message.isNotEmpty) Text(message),
        if (output.isNotEmpty) ...[
          const Divider(),
          SelectableText(output),
          TextButton(
            onPressed: () => run(() async {
              await widget.files.exportText('workflow-result.txt', output);
            }),
            child: Text(tr(context, 'Export result', 'Xuất kết quả')),
          ),
        ],
        for (final r in current.recipes)
          ListTile(
            title: Text(r.name),
            subtitle: Text(r.steps.join(' → ')),
            onTap: busy
                ? null
                : () => setState(() {
                    output = '';
                    name.text = r.name;
                    steps
                      ..clear()
                      ..addAll(r.steps);
                  }),
          ),
      ],
    );
  }
}
