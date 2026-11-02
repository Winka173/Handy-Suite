import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'notebook_page.dart';
import 'package:handy_workflow/handy_workflow.dart';
import '../draw_page.dart';
import '../password_page.dart';
import '../qr_page.dart';
import '../specs.dart';
import '../subtitles/subtitle_panel.dart';
import 'catalog.dart';
import 'free_bench.dart';
import 'shelf.dart';
import 'tape.dart';
import 'tape_view.dart';
import 'tool_panel.dart';

/// Everything the bench needs from the app, shared by every bench route.
class BenchScope {
  final HandyPreferences Function() read;
  final Future<void> Function(HandyPreferences) save;
  final HandyFiles files;
  final DocumentRepository? qrHistoryDocuments;
  final ExportHistory? exportHistory;
  final TapeController tape;
  const BenchScope({
    required this.read,
    required this.save,
    required this.files,
    required this.tape,
    this.qrHistoryDocuments,
    this.exportHistory,
  });

  Future<void> togglePin(String id) {
    final pins = [...read().favorites];
    pins.contains(id) ? pins.remove(id) : pins.add(id);
    return save(read().copyWith(favorites: pins));
  }

  Future<void> saveChain(Recipe recipe) {
    final current = read();
    if (current.recipes.length >= 30) {
      throw const FormatException('Up to 30 chains / Tối đa 30 chuỗi');
    }
    return save(current.copyWith(recipes: [...current.recipes, recipe]));
  }
}

/// The one screen of Handy Tools. Free entry when [toolId] is null, otherwise
/// that tool's form in the same place. The tape sits beside it on wide
/// screens and under it on phones.
class BenchPage extends StatefulWidget {
  final BenchScope scope;
  final String? toolId;
  final Map<String, String> initial;
  const BenchPage({
    super.key,
    required this.scope,
    this.toolId,
    this.initial = const {},
  });
  @override
  State<BenchPage> createState() => _BenchPageState();
}

class _BenchPageState extends State<BenchPage> {
  final focus = FocusNode();
  final input = TextEditingController();
  final free = GlobalKey<FreeBenchState>();
  late bool pinned = widget.scope.read().favorites.contains(widget.toolId);
  BenchScope get scope => widget.scope;

  @override
  void dispose() {
    focus.dispose();
    input.dispose();
    super.dispose();
  }

  void openTool(String id, [Map<String, String> values = const {}]) =>
      Navigator.pushNamed(context, '/tool/$id', arguments: values);

  Future<void> catalog() async {
    final id = await showToolCatalog(
      context,
      pinned: scope.read().favorites.toSet(),
      onTogglePin: scope.togglePin,
    );
    if (id != null && mounted) {
      setState(() {});
      openTool(id);
    }
  }

  void reuse(TapeEntry e) {
    if (e.free && widget.toolId == null) {
      free.currentState?.fill(e.input);
    } else if (e.free) {
      Navigator.popUntil(context, (r) => r.isFirst);
    } else {
      openTool(e.toolId, e.values);
    }
  }

  Future<void> togglePin() async {
    try {
      await scope.togglePin(widget.toolId!);
      if (mounted) setState(() => pinned = !pinned);
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

  Widget header(BuildContext context, List<Widget> actions) {
    final id = widget.toolId!;
    final hint = specById[id]?.hint(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('tool-close'),
                tooltip: tr(context, 'Back to free entry', 'Về ô nhập tự do'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: HandySpace.xs),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    toolTitle(context, id),
                    style: theme.textTheme.headlineSmall,
                    maxLines: 2,
                  ),
                ),
              ),
              if (specById.containsKey(id))
                IconButton(
                  key: const Key('pin'),
                  tooltip: pinned
                      ? tr(context, 'Unpin', 'Bỏ ghim')
                      : tr(context, 'Pin', 'Ghim'),
                  icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: togglePin,
                ),
              ...actions,
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: HandySpace.xs),
              child: Text(
                hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HandyColors.of(context).muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget bench(BuildContext context) {
    final id = widget.toolId;
    final p = scope.read();
    return switch (id) {
      null => FreeBench(
        key: free,
        tape: scope.tape,
        files: scope.files,
        chains: p.recipes,
        pinned: p.favorites,
        focus: focus,
        input: input,
        onOpenTool: openTool,
        onSaveChain: (r) async {
          await scope.saveChain(r);
          if (mounted) setState(() {});
        },
        onOpenCatalog: catalog,
      ),
      'qr' => QrPage(
        files: scope.files,
        historyDocuments: scope.qrHistoryDocuments,
        initialText: widget.initial['text'] ?? '',
        header: header,
      ),
      'password' => PasswordPage(header: header),
      'draw' => DrawPage(header: header),
      'subtitles' => SubtitlePanel(
        files: scope.files,
        history: scope.exportHistory,
        header: header,
      ),
      _ => ToolPanel(
        spec: specById[id]!,
        files: scope.files,
        tape: scope.tape,
        history: scope.exportHistory,
        initial: widget.initial,
        draft: p.drafts[id] ?? '',
        header: header,
        onSaveDraft: (d) => scope.save(
          scope.read().copyWith(drafts: {...scope.read().drafts, id: d}),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tape = TapeView(
      tape: scope.tape,
      onReuse: reuse,
      onNotebook: () => openNotebook(context, scope),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): catalog,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): catalog,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            focus.requestFocus(),
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          shift: true,
        ): () =>
            free.currentState?.copy(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (widget.toolId != null) Navigator.maybePop(context);
        },
      },
      child: Focus(
        autofocus: widget.toolId != null,
        child: Scaffold(
          appBar: HandyTopBar(
            mark: Icons.handyman,
            name: 'Handy Tools',
            onFind: catalog,
            findLabel: tr(context, 'Find a tool', 'Tìm công cụ'),
            nameIsTitle: widget.toolId == null,
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, size) {
                final wide = size.maxWidth >= 900;
                const pad = EdgeInsets.fromLTRB(
                  HandySpace.l,
                  HandySpace.l,
                  HandySpace.l,
                  HandySpace.xxl,
                );
                if (!wide) {
                  return ListView(
                    padding: pad,
                    children: [
                      bench(context),
                      const SizedBox(height: HandySpace.xxl),
                      tape,
                      // Tablets have the room: every tool stays one tap away
                      // instead of leaving the lower half empty.
                      if (widget.toolId == null && size.maxWidth >= 600) ...[
                        const SizedBox(height: HandySpace.xxl * 1.5),
                        ToolShelf(onOpen: openTool),
                      ],
                    ],
                  );
                }
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView(
                            padding: pad,
                            children: [
                              bench(context),
                              if (widget.toolId == null) ...[
                                const SizedBox(height: HandySpace.xxl * 1.5),
                                ToolShelf(onOpen: openTool),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: HandySpace.l),
                        SizedBox(
                          width: 380,
                          child: ListView(padding: pad, children: [tape]),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
