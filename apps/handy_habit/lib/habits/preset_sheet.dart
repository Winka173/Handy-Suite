import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/capped.dart';
import '../ui/words.dart';
import '../design/palette.dart';
import 'habit_appearance.dart';
import 'template_preview.dart';

/// New habit, the quick way: a sheet with a name field and six common
/// starts. A name or a start opens the editor already filled in; All
/// templates opens the gallery. Two taps to a first habit.
Future<bool> addHabit(BuildContext context, HabitScope scope) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _QuickAdd(),
  );
  if (picked == null || !context.mounted) return false;
  if (picked == 'templates')
    return await Navigator.pushNamed<bool>(context, '/templates?kind=habit') ==
        true;
  return await Navigator.pushNamed<bool>(
        context,
        '/habit/new',
        // A start from the list, or just the name that was typed.
        arguments: picked is MapEntry ? picked.value : picked,
      ) ==
      true;
}

/// The six starts the quick sheet offers, in this order.
const _quickStarts = [
  'water',
  'walk',
  'read',
  'stretch',
  'bed-time',
  'sugary-drinks',
];

class _QuickAdd extends StatefulWidget {
  const _QuickAdd();
  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _named() {
    final title = name.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(context, MapEntry('name', title));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final starts = [
      for (final id in _quickStarts)
        ?habitPresets.where((x) => x.id == id).firstOrNull,
    ];
    if (starts.length < 6)
      starts.addAll(
        habitPresets.where((x) => !starts.contains(x)).take(6 - starts.length),
      );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const Key('quick-add'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'New habit', 'Thói quen mới'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: p.anchor,
              ),
            ),
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            key: const Key('quick-add-name'),
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _named(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr(
                context,
                'What will you do? Read 10 pages…',
                'Bạn sẽ làm gì? Đọc 10 trang…',
              ),
              suffixIcon: name.text.trim().isEmpty
                  ? null
                  : IconButton(
                      key: const Key('quick-add-next'),
                      tooltip: tr(context, 'Next', 'Tiếp'),
                      onPressed: _named,
                      icon: Icon(Icons.arrow_forward, color: p.vermilion),
                    ),
            ),
          ),
          const SizedBox(height: HandySpace.l),
          Text(
            tr(context, 'Or start from one of these', 'Hoặc bắt đầu từ'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final x in starts)
                ActionChip(
                  key: Key('quick-add-${x.id}'),
                  avatar: Icon(
                    habitIcon(x.icon),
                    size: 18,
                    color: Color(x.color),
                  ),
                  label: Text(tr(context, x.en, x.vi)),
                  onPressed: () => Navigator.pop(context, x),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.m),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('quick-add-templates'),
              onPressed: () => Navigator.pop(context, 'templates'),
              icon: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(
                tr(
                  context,
                  'All ${habitPresets.length} templates',
                  'Cả ${habitPresets.length} mẫu',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HabitTemplatesPage extends StatefulWidget {
  final HabitScope scope;
  final String? collection;
  final bool routines;
  const HabitTemplatesPage({
    super.key,
    required this.scope,
    this.collection,
    this.routines = false,
  });
  @override
  State<HabitTemplatesPage> createState() => _HabitTemplatesPageState();
}

class _HabitTemplatesPageState extends State<HabitTemplatesPage> {
  final search = TextEditingController();
  late String? collection = widget.collection;
  late bool routines = widget.routines;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> open(String id) async {
    final habit = habitPresets.where((x) => x.id == id).firstOrNull;
    final saved = habit != null
        ? await Navigator.pushNamed<bool>(
            context,
            '/habit/new',
            arguments: habit,
          )
        : await Navigator.pushNamed<bool>(context, '/templates/$id');
    if (saved == true && mounted) Navigator.pop(context, true);
  }

  Future<void> blank() async {
    final saved = routines
        ? await Navigator.pushNamed<String>(context, '/routine/new') != null
        : await Navigator.pushNamed<bool>(context, '/habit/new') == true;
    if (saved && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final matching = habitPresets
        .where(
          (p) =>
              (collection == null || collection == p.collection) &&
              templateMatches(search.text, [
                p.en,
                p.vi,
                p.descriptionEn,
                p.descriptionVi,
                templateCollections[p.collection]!.en,
                templateCollections[p.collection]!.vi,
              ]),
        )
        .toList();
    final routineMatches = routineTemplateCatalog
        .where(
          (p) =>
              (collection == null || collection == p.collection) &&
              templateMatches(search.text, [
                p.en,
                p.vi,
                templateCollections[p.collection]!.en,
                templateCollections[p.collection]!.vi,
                for (final s in p.steps) '${s.$1} ${s.$2}',
              ]),
        )
        .toList();
    final count = routines ? routineMatches.length : matching.length;
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'Templates', 'Mẫu gợi ý'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HandyContent(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(
                    context,
                    'Something you can come back to.',
                    'Một điều bạn muốn duy trì.',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('templates-habits'),
                      label: Text(tr(context, 'Habits', 'Thói quen')),
                      selected: !routines,
                      onSelected: (_) => setState(() => routines = false),
                    ),
                    ChoiceChip(
                      key: const Key('templates-routines'),
                      label: Text(tr(context, 'Routines', 'Quy trình')),
                      selected: routines,
                      onSelected: (_) => setState(() => routines = true),
                    ),
                    TextButton.icon(
                      key: const Key('preset-blank'),
                      onPressed: blank,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(tr(context, 'Write my own', 'Tự đặt từ đầu')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('template-search'),
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tr(context, 'Search templates', 'Tìm mẫu'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('template-clear'),
                            tooltip: tr(
                              context,
                              'Clear search',
                              'Xóa tìm kiếm',
                            ),
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: const Key('collection-all'),
                          label: Text(tr(context, 'All', 'Tất cả')),
                          selected: collection == null,
                          onSelected: (_) => setState(() => collection = null),
                        ),
                      ),
                      for (final e in templateCollections.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('collection-${e.key}'),
                            label: Text(tr(context, e.value.en, e.value.vi)),
                            selected: collection == e.key,
                            onSelected: (_) =>
                                setState(() => collection = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
                if (search.text.isEmpty && collection == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      tr(context, 'A few to try', 'Vài gợi ý để bắt đầu'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final id
                              in routines
                                  ? ['study', 'recovery', 'weekend']
                                  : ['walk', 'read', 'sugary-drinks'])
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: SizedBox(
                                width: 240,
                                child: Material(
                                  color: HabitPalette.of(context).raised,
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    key: Key('featured-$id'),
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => open(id),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: _featured(context, id),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                HandyLabel(
                  tr(
                    context,
                    '$count ${routines ? (count == 1 ? 'routine' : 'routines') : (count == 1 ? 'habit' : 'habits')} to make your own',
                    '$count ${routines ? 'quy trình' : 'thói quen'} để bạn tùy chỉnh',
                  ),
                ),
                if (count == 0) ...[
                  Text(
                    tr(
                      context,
                      'No match here. Try another word or collection.',
                      'Chưa có mẫu phù hợp. Thử từ khác hoặc nhóm khác.',
                    ),
                  ),
                  TextButton(
                    key: const Key('templates-reset'),
                    onPressed: () => setState(() {
                      collection = null;
                      search.clear();
                    }),
                    child: Text(tr(context, 'Clear filters', 'Xóa bộ lọc')),
                  ),
                ],
                Capped(
                  key: ValueKey('$routines/$collection/${search.text}'),
                  count: count,
                  max: 8,
                  name: 'templates',
                  builder: (context, shown) => Column(
                    children: [
                      if (routines)
                        for (final p in routineMatches.take(shown))
                          ListTile(
                            key: Key('preset-${p.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(habitIcon(p.icon), size: 22),
                            title: Text(tr(context, p.en, p.vi)),
                            subtitle: Text(
                              '${p.steps.length} ${tr(context, 'steps', 'bước')} · ${minutesText(context, p.seconds)} · ${weekdaysText(context, p.weekdays)}',
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => open(p.id),
                          ),
                      if (!routines)
                        for (final p in matching.take(shown))
                          ListTile(
                            key: Key('preset-${p.id}'),
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(habitIcon(p.icon), size: 22),
                            title: Text(tr(context, p.en, p.vi)),
                            subtitle: Text(presetGoal(context, p)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => open(p.id),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featured(BuildContext context, String id) {
    final h = habitPresets.where((p) => p.id == id).firstOrNull;
    final r = routineTemplateCatalog.where((p) => p.id == id).firstOrNull;
    final title = h != null
        ? tr(context, h.en, h.vi)
        : tr(context, r!.en, r.vi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          h != null ? presetGoal(context, h) : minutesText(context, r!.seconds),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
