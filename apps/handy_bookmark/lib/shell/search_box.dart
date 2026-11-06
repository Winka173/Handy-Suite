import 'package:handy_ui/kit.dart';
import '../view/library_view.dart';

/// All / Links / Pictures, with how many of each, once the library holds
/// both kinds (until then the choice means nothing).
class KindChips extends StatelessWidget {
  final LibraryView view;
  const KindChips({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final items = [
      for (final b in view.c.library?.bookmarks ?? const [])
        if (!b.isArchived) b,
    ];
    final pictures = items.where((b) => b.isImage).length;
    final links = items.length - pictures;
    if (pictures == 0 || links == 0) return const SizedBox.shrink();
    final now = view.filters.kind;
    Widget chip(String? kind, String label, int n) => ChoiceChip(
      key: Key('kind-${kind ?? 'all'}'),
      label: Text('$label $n'),
      selected: now == kind,
      onSelected: (_) => view.filter(view.filters.withKind(kind)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.s),
      child: Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          chip(null, tr(context, 'All', 'Tất cả'), items.length),
          chip('link', tr(context, 'Links', 'Link'), links),
          chip('image', tr(context, 'Pictures', 'Ảnh'), pictures),
        ],
      ),
    );
  }
}

/// Finds links by title, description, note, address, website, source, tag
/// or collection. Typing narrows the current list as you go.
class SearchBox extends StatefulWidget {
  final LibraryView view;
  final FocusNode? focus;
  const SearchBox({super.key, required this.view, this.focus});
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final input = TextEditingController(text: widget.view.text);

  @override
  void initState() {
    super.initState();
    widget.view.addListener(_follow);
  }

  /// A saved search sets the words from outside; show them.
  void _follow() {
    if (input.text != widget.view.text && mounted) {
      input.text = widget.view.text;
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.view.removeListener(_follow);
    input.dispose();
    super.dispose();
  }

  void use(String term) {
    input.text = term;
    widget.view.search(term);
    setState(() {});
  }

  /// Remembers a search when the person has turned history on (Settings).
  void remember(String term) {
    final c = widget.view.c;
    final t = term.trim();
    if (t.isEmpty || c.preferences['recentSearchesEnabled'] != true) return;
    final recent = [
      t,
      ...(c.preferences['recentSearches'] as List? ?? [])
          .whereType<String>()
          .where((x) => x != t),
    ].take(20).toList();
    c
        .update((l) => l, prefs: {...c.preferences, 'recentSearches': recent})
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.view.c;
    final recent = c.preferences['recentSearchesEnabled'] == true
        ? (c.preferences['recentSearches'] as List? ?? [])
              .whereType<String>()
              .take(5)
              .toList()
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(context),
        KindChips(view: widget.view),
        HandyReveal(
          child: input.text.isNotEmpty || recent.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: HandySpace.s),
                  child: Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      for (final r in recent)
                        ActionChip(
                          key: Key('recent-$r'),
                          avatar: const Icon(Icons.history, size: 16),
                          label: Text(r),
                          onPressed: () => use(r),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _field(BuildContext context) => TextField(
    onSubmitted: remember,
    key: const Key('save-search'),
    controller: input,
    focusNode: widget.focus,
    maxLength: 500,
    textInputAction: TextInputAction.search,
    onChanged: (s) {
      widget.view.search(s);
      setState(() {});
    },
    decoration: InputDecoration(
      counterText: '',
      prefixIcon: const Padding(
        padding: EdgeInsetsDirectional.only(start: 6),
        child: Icon(Icons.search),
      ),
      hintText: tr(context, 'Search your library', 'Tìm trong thư viện'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: _pill(context),
      enabledBorder: _pill(context),
      focusedBorder: _pill(context, focused: true),
      suffixIcon: input.text.isEmpty
          ? null
          : IconButton(
              tooltip: tr(context, 'Clear search', 'Xóa tìm kiếm'),
              icon: const Icon(Icons.close),
              onPressed: () {
                input.clear();
                widget.view.search('');
                setState(() {});
              },
            ),
    ),
  );

  OutlineInputBorder _pill(BuildContext context, {bool focused = false}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: focused
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              )
            : BorderSide.none,
      );
}
