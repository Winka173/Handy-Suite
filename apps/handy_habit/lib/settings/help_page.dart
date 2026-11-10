import 'package:handy_ui/kit.dart';
import 'help_topics.dart';
import 'how_to_mocks.dart';
import '../design/palette.dart';

class HabitHelpPage extends StatefulWidget {
  final String? topic;
  final String query;
  const HabitHelpPage({super.key, this.topic, this.query = ''});
  @override
  State<HabitHelpPage> createState() => _HabitHelpPageState();
}

class _HabitHelpPageState extends State<HabitHelpPage> {
  late final search = TextEditingController(text: widget.query);
  late String? selected = widget.topic;
  final searchAnchor = GlobalKey();
  var articleAnchor = GlobalKey();
  void back() {
    if (selected != null && widget.topic == null) {
      select(null);
    } else {
      Navigator.maybePop(context);
    }
  }

  void select(String? id) {
    setState(() {
      selected = id;
      // Outgoing articles remain mounted during HandySwap's transition.
      articleAnchor = GlobalKey();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = (id == null ? searchAnchor : articleAnchor).currentContext;
      if (mounted && target != null)
        Scrollable.ensureVisible(target, duration: Duration.zero);
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = foldHabitHelp(search.text);
    final topics = habitHelpTopics
        .where((t) => foldHabitHelp(t.searchText()).contains(query))
        .toList();
    final topic = habitHelpTopics.where((t) => t.id == selected).firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final searchField = TextField(
      key: const Key('help-search'),
      controller: search,
      onChanged: (_) => setState(() => selected = null),
      decoration: InputDecoration(
        labelText: tr(context, 'Search How to use', 'Tìm cách dùng'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: search.text.isEmpty
            ? null
            : IconButton(
                key: const Key('help-clear'),
                tooltip: tr(context, 'Clear search', 'Xóa tìm kiếm'),
                onPressed: () {
                  search.clear();
                  setState(() => selected = null);
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
    final index = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          header: query.isEmpty,
          child: Text(
            tr(
              context,
              query.isEmpty
                  ? 'Topics'
                  : topics.length == 1
                  ? '1 topic'
                  : '${topics.length} topics',
              query.isEmpty ? 'Chủ đề' : '${topics.length} chủ đề',
            ),
            style: query.isEmpty
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (topics.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              tr(
                context,
                'No topics match. Try habit, reminder or backup, or clear the search.',
                'Không có chủ đề phù hợp. Thử thói quen, nhắc, sao lưu hoặc xóa tìm kiếm.',
              ),
              key: const Key('help-no-match'),
            ),
          ),
        for (final t in topics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              key: Key('help-topic-${t.id}'),
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 12,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HabitPalette.of(context).raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t.icon, size: 22),
              ),
              title: Text(t.title(context)),
              subtitle: Text(t.summary(context)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              selected: t.id == selected,
              onTap: () => select(t.id),
            ),
          ),
      ],
    );
    final article = topic == null
        ? null
        : Column(
            key: articleAnchor,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  topic.title(context),
                  key: Key('help-article-${topic.id}'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < topic.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${i + 1}. ${tr(context, topic.steps[i].$1, topic.steps[i].$2)}',
                      ),
                      const SizedBox(height: 12),
                      HabitHelpMock(topic: topic.id, step: i),
                    ],
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (habitHelpTopics.indexOf(topic) > 0)
                    TextButton.icon(
                      key: const Key('help-previous'),
                      onPressed: () => select(
                        habitHelpTopics[habitHelpTopics.indexOf(topic) - 1].id,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(tr(context, 'Previous', 'Trước')),
                    ),
                  if (habitHelpTopics.indexOf(topic) <
                      habitHelpTopics.length - 1)
                    TextButton.icon(
                      key: const Key('help-next'),
                      onPressed: () => select(
                        habitHelpTopics[habitHelpTopics.indexOf(topic) + 1].id,
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(tr(context, 'Next', 'Tiếp')),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => select(null),
                child: Text(tr(context, 'All topics', 'Mọi chủ đề')),
              ),
            ],
          );
    return PopScope(
      canPop: selected == null || widget.topic != null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) select(null);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: back),
          title: MediaQuery.sizeOf(context).width >= 840
              ? null
              : Text(tr(context, 'How to use', 'Cách dùng')),
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
            ),
            children: [
              HandyContent(
                maxWidth: topic == null ? 720 : 960,
                child: _content(context, wide, searchField, index, article),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    bool wide,
    Widget searchField,
    Widget index,
    Widget? article,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.sizeOf(context).width >= 840)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Semantics(
              header: true,
              child: Text(
                tr(context, 'How to use', 'Cách dùng'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
        if (selected == null) ...[
          Material(
            color: HabitPalette.of(context).tint,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              key: const Key('help-replay'),
              contentPadding: const EdgeInsets.all(16),
              leading: const Icon(Icons.play_circle_outline, size: 28),
              title: Text(
                tr(
                  context,
                  'Replay the introduction',
                  'Xem lại phần giới thiệu',
                ),
              ),
              subtitle: Text(
                tr(
                  context,
                  'Practise checking in and running a routine. Nothing is saved.',
                  'Tập ghi nhận và chạy quy trình. Không lưu gì thật.',
                ),
              ),
              onTap: () => Navigator.pushNamed(context, '/welcome'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        KeyedSubtree(key: searchAnchor, child: searchField),
        const SizedBox(height: 16),
        wide && article != null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: index),
                  const SizedBox(width: 24),
                  Expanded(
                    child: HandySwap(
                      child: KeyedSubtree(
                        key: ValueKey(selected),
                        child: article,
                      ),
                    ),
                  ),
                ],
              )
            : HandySwap(
                child: KeyedSubtree(
                  key: ValueKey(selected),
                  child: article ?? index,
                ),
              ),
      ],
    ),
  );
}
