import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'new_board.dart';
import 'setup_page.dart';
import 'template_parts.dart';

/// The template gallery: search, groups, Free/Pro, the featured six first,
/// and the blank board one tap away. Opening a template shows its board
/// before anything is asked.
class TemplateGallery extends StatefulWidget {
  final BoardsScope scope;

  /// Pre-selected group (from onboarding's suggestions).
  final TemplateGroup? group;
  const TemplateGallery({super.key, required this.scope, this.group});
  @override
  State<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends State<TemplateGallery> {
  final query = TextEditingController();
  late TemplateGroup? group = widget.group;
  String tier = 'all';

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  List<BoardTemplate> get _shown => [
    for (final t in boardTemplates)
      if ((group == null || t.group == group) &&
          (tier == 'all' || (tier == 'pro') == t.pro) &&
          templateMatches(t, query.text))
        t,
  ];

  /// From the purpose picked in the guide or in Settings (suggestions
  /// only; every template stays in the list).
  List<String>? get _suggested =>
      switch (widget.scope.controller.state?.preferences['purpose']) {
        'study' => const ['semester', 'group-assignment', 'exam-revision'],
        'work' => const ['project', 'weekly', 'ideas'],
        _ => null,
      };

  void _open(BoardTemplate t) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => TemplatePreviewPage(scope: widget.scope, template: t),
    ),
  );

  /// Phones list the templates as rows with every word showing; wider
  /// screens lay them out as cards. Both are built lazily.
  Widget _grid(List<BoardTemplate> list) {
    if (MediaQuery.sizeOf(context).width < 600)
      return SliverList.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => TemplateTile(
          template: list[i],
          row: true,
          onTap: () => _open(list[i]),
        ),
      );
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 232,
      ),
      itemCount: list.length,
      itemBuilder: (context, i) =>
          TemplateTile(template: list[i], onTap: () => _open(list[i])),
    );
  }

  Widget _heading(String text) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final shown = _shown;
    final browsing =
        query.text.trim().isEmpty && group == null && tier == 'all';
    final featured = [
      for (final t in boardTemplates)
        if (t.featured != null) t,
    ]..sort((a, b) => a.featured!.compareTo(b.featured!));
    Widget chip(String key, String label, bool on, VoidCallback tap) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: Key(key),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => tap(),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Templates', 'Mẫu bảng'))),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('gallery-search'),
                    controller: query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr(
                        context,
                        'Search templates',
                        'Tìm mẫu (VD: học, dự án, chuyển nhà)',
                      ),
                      suffixIcon: query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: tr(context, 'Clear', 'Xoá'),
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(query.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        chip(
                          'group-all',
                          tr(context, 'All', 'Tất cả'),
                          group == null,
                          () => setState(() => group = null),
                        ),
                        for (final g in TemplateGroup.values)
                          chip(
                            'group-${g.name}',
                            groupName(context, g),
                            group == g,
                            () => setState(() => group = group == g ? null : g),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Wraps on a narrow phone or with large text.
                  Wrap(
                    runSpacing: 6,
                    children: [
                      chip(
                        'tier-all',
                        tr(context, 'Free and Pro', 'Free và Pro'),
                        tier == 'all',
                        () => setState(() => tier = 'all'),
                      ),
                      chip(
                        'tier-free',
                        tr(context, 'Free', 'Miễn phí'),
                        tier == 'free',
                        () => setState(() => tier = 'free'),
                      ),
                      chip(
                        'tier-pro',
                        'Pro',
                        tier == 'pro',
                        () => setState(() => tier = 'pro'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // The blank board stays one tap away from anywhere here.
                  Material(
                    color: p.raised,
                    borderRadius: BorderRadius.circular(BoardsRadii.tile),
                    child: ListTile(
                      key: const Key('gallery-blank'),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BoardsRadii.tile),
                      ),
                      leading: const Icon(Icons.view_week_outlined),
                      title: Text(tr(context, 'Blank board', 'Bảng trống')),
                      subtitle: Text(
                        tr(
                          context,
                          'To Do → Doing → Done, nothing else.',
                          'Cần làm → Đang làm → Xong, không thêm gì.',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => createBlank(context, widget.scope),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverMainAxisGroup(
              slivers: [
                if (browsing) ...[
                  if (_suggested case final ids?) ...[
                    _heading(tr(context, 'Suggested for you', 'Gợi ý cho bạn')),
                    _grid([
                      for (final id in ids)
                        if (templateById(id) case final t?) t,
                    ]),
                  ],
                  _heading(tr(context, 'Featured', 'Nổi bật')),
                  _grid(featured),
                  for (final g in TemplateGroup.values) ...[
                    _heading(groupName(context, g)),
                    _grid([
                      for (final t in boardTemplates)
                        if (t.group == g) t,
                    ]),
                  ],
                ] else if (shown.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Text(
                            tr(
                              context,
                              'No template matches.',
                              'Không có mẫu nào khớp.',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton(
                            key: const Key('gallery-reset'),
                            onPressed: () => setState(() {
                              query.clear();
                              group = null;
                              tier = 'all';
                            }),
                            child: Text(
                              tr(context, 'Show all', 'Xem tất cả mẫu'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  _grid(shown),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
