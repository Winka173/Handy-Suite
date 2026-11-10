import 'package:handy_ui/kit.dart';
import 'help_topics.dart';
import 'how_to_mocks.dart';

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
  final searchAnchor = GlobalKey(), articleAnchor = GlobalKey();
  void select(String? id) {
    setState(() => selected = id);
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
          child: Text(
            tr(context, '${topics.length} topics', '${topics.length} chủ đề'),
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
          ListTile(
            key: Key('help-topic-${t.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${habitHelpTopics.indexOf(t) + 1}. ${t.title(context)}',
            ),
            selected: t.id == selected,
            onTap: () => select(t.id),
          ),
      ],
    );
    final article = topic == null
        ? null
        : Column(
            key: articleAnchor,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                topic.title(context),
                key: Key('help-article-${topic.id}'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < topic.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '${i + 1}. ${tr(context, topic.steps[i].$1, topic.steps[i].$2)}',
                  ),
                ),
              HabitHelpMock(topic: topic.id),
              TextButton(
                onPressed: () => select(null),
                child: Text(tr(context, 'All topics', 'Mọi chủ đề')),
              ),
            ],
          );
    return HandyPage(
      title: tr(context, 'How to use', 'Cách dùng'),
      actions: [
        IconButton(
          key: const Key('help-replay'),
          tooltip: tr(context, 'Replay guide', 'Xem lại hướng dẫn'),
          onPressed: () => Navigator.pushNamed(context, '/welcome'),
          icon: const Icon(Icons.replay),
        ),
      ],
      children: [
        HandyContent(
          maxWidth: 960,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(key: searchAnchor, child: searchField),
                const SizedBox(height: 16),
                wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 300, child: index),
                          const SizedBox(width: 32),
                          Expanded(
                            child:
                                article ??
                                Text(
                                  tr(
                                    context,
                                    'Choose a topic to see its steps.',
                                    'Chọn chủ đề để xem các bước.',
                                  ),
                                ),
                          ),
                        ],
                      )
                    : article ?? index,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
