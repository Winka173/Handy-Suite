import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge, askText;
import '../board/category_strip.dart';
import '../board/kanban_view.dart';
import '../covers/cover_art.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';

bool isVi(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'vi';

/// Starts a new board: blank in two taps, or from a template.
Future<void> newBoard(BuildContext context, BoardsScope scope) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        final p = BoardsPalette.of(sheet);
        Widget option(
          Key key,
          IconData icon,
          String title,
          String line,
          VoidCallback onTap,
        ) => Material(
          color: p.raised,
          borderRadius: BorderRadius.circular(BoardsRadii.tile),
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(BoardsRadii.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: p.ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.muted),
                ],
              ),
            ),
          ),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    tr(sheet, 'New board', 'Bảng mới'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                option(
                  const Key('new-blank'),
                  Icons.view_week_outlined,
                  tr(sheet, 'Blank board', 'Bảng trống'),
                  tr(
                    sheet,
                    'To Do, Doing, Done. Change anything later.',
                    'Cần làm, Đang làm, Xong. Đổi được mọi thứ sau.',
                  ),
                  () async {
                    Navigator.pop(sheet);
                    await createBlank(context, scope);
                  },
                ),
                const SizedBox(height: 10),
                option(
                  const Key('new-template'),
                  Icons.dashboard_customize_outlined,
                  tr(sheet, 'From a template', 'Từ mẫu có sẵn'),
                  tr(
                    sheet,
                    'Study, projects, shopping and more, ready to edit.',
                    'Học tập, dự án, mua sắm và hơn thế, sửa được ngay.',
                  ),
                  () {
                    Navigator.pop(sheet);
                    Navigator.pushNamed(context, '/templates');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

Future<void> createBlank(BuildContext context, BoardsScope scope) async {
  final name = await askText(
    context,
    title: tr(context, 'Name the board', 'Đặt tên bảng'),
    hint: tr(context, 'e.g. This week', 'VD: Tuần này'),
    action: tr(context, 'Create', 'Tạo'),
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  await createFrom(context, scope, null, name);
}

/// Creates the board and opens it.
Future<void> createFrom(
  BuildContext context,
  BoardsScope scope,
  TemplatePreset? preset,
  String name,
) async {
  final id = newId();
  final vi = isVi(context);
  await scope.run(
    context,
    () => scope.controller.change(
      (s) => createKanbanBoard(
        s,
        title: name,
        preset: preset,
        vi: vi,
        now: scope.clock(),
        boardId: id,
      ),
    ),
  );
  if (!context.mounted || scope.controller.state?.maybe('boards', id) == null)
    return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await Navigator.pushNamed(context, '/board/$id');
}

/// Which shelf of the gallery a template sits on.
String templateShelf(String id) => switch (id) {
  'study' => 'study',
  'project' || 'content' => 'work',
  'personal' || 'goals' => 'personal',
  'shopping' || 'renovation' => 'home',
  _ => 'events',
};

class TemplateGallery extends StatefulWidget {
  final BoardsScope scope;
  const TemplateGallery({super.key, required this.scope});
  @override
  State<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends State<TemplateGallery> {
  String shelf = 'all';
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shelves = <(String, String)>[
      ('all', tr(context, 'All', 'Tất cả')),
      ('study', tr(context, 'Study', 'Học tập')),
      ('work', tr(context, 'Work', 'Công việc')),
      ('personal', tr(context, 'Personal', 'Cá nhân')),
      ('home', tr(context, 'Home & shopping', 'Nhà & mua sắm')),
      ('events', tr(context, 'Events & ideas', 'Sự kiện & ý tưởng')),
    ];
    final list = templatePresets
        .where(
          (t) =>
              t.id != 'blank' &&
              (shelf == 'all' || templateShelf(t.id) == shelf),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Templates', 'Mẫu bảng'))),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final s in shelves)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Center(
                      child: ChoiceChip(
                        key: Key('shelf-${s.$1}'),
                        label: Text(s.$2),
                        selected: shelf == s.$1,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => shelf = s.$1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 250,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final t = list[i];
                final vi = isVi(context);
                return Semantics(
                  button: true,
                  label:
                      '${vi ? t.nameVi : t.nameEn}${t.pro ? ', Pro' : ''}. ${vi ? t.blurbVi : t.blurbEn}',
                  excludeSemantics: true,
                  child: Material(
                    color: BoardsPalette.of(context).surface,
                    borderRadius: BorderRadius.circular(BoardsRadii.tile),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('template-${t.id}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TemplatePreview(scope: widget.scope, preset: t),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 140,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CoverArt(t.cover),
                                if (t.pro)
                                  const Positioned(
                                    top: 10,
                                    right: 10,
                                    child: ProBadge(),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                            child: Text(
                              vi ? t.nameVi : t.nameEn,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                            child: Text(
                              vi ? t.blurbVi : t.blurbEn,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: BoardsPalette.of(context).muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole board a template makes, drawn by the real Kanban from a
/// throwaway copy that is never saved. Use it, or Unlock Pro for a Pro one.
class TemplatePreview extends StatefulWidget {
  final BoardsScope scope;
  final TemplatePreset preset;
  const TemplatePreview({super.key, required this.scope, required this.preset});
  @override
  State<TemplatePreview> createState() => _TemplatePreviewState();
}

class _TemplatePreviewState extends State<TemplatePreview> {
  BoardsState? sample;
  String? category;
  static const _board = '00000000-0000-4000-8000-00000000b0a2';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sample ??= createKanbanBoard(
      BoardsState(),
      title: isVi(context) ? widget.preset.nameVi : widget.preset.nameEn,
      preset: widget.preset,
      vi: isVi(context),
      now: widget.scope.clock(),
      boardId: _board,
    );
  }

  Future<void> _use() async {
    final t = widget.preset;
    if (t.pro && !await requirePro(context, ProFeature.templates)) return;
    if (!mounted) return;
    final name = await askText(
      context,
      title: tr(context, 'Name the board', 'Đặt tên bảng'),
      value: isVi(context) ? t.nameVi : t.nameEn,
      action: tr(context, 'Create', 'Tạo'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await createFrom(context, widget.scope, t, name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final t = widget.preset, s = sample!;
    final vi = isVi(context);
    final locked = t.pro && !hasPro(context);
    return Scaffold(
      appBar: AppBar(title: Text(vi ? t.nameVi : t.nameEn)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              vi ? t.blurbVi : t.blurbEn,
              style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
            ),
          ),
          CategoryStrip(
            state: s,
            board: _board,
            selected: category,
            onSelect: (v) => setState(() => category = v),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: KanbanView(
              state: s,
              board: _board,
              now: widget.scope.clock(),
              filter: KanbanFilter(
                category: category == CategoryStrip.uncategorisedKey
                    ? null
                    : category,
                uncategorised: category == CategoryStrip.uncategorisedKey,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr(
                  context,
                  'Sample cards are yours to change or delete.',
                  'Thẻ mẫu là của bạn: sửa hay xoá tuỳ ý.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('template-use'),
                onPressed: _use,
                child: Text(
                  locked
                      ? tr(context, 'Unlock with Pro', 'Mở khoá với Pro')
                      : tr(context, 'Use this template', 'Dùng mẫu này'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
