import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../covers/cover_art.dart';
import '../design/theme.dart';
import '../pro/pro.dart';
import '../scope.dart';

/// What the person chose in the cover picker.
class CoverPick {
  final String? art;
  final int? color;

  /// Choose a photo of their own (the caller imports it).
  final bool photo;

  /// Take the cover off.
  final bool none;
  const CoverPick({
    this.art,
    this.color,
    this.photo = false,
    this.none = false,
  });
}

/// The one cover picker: Suggested, All, each family, colours and the
/// person's own photo. A tap previews the cover at once on [preview] (the
/// real card or board); nothing is kept until Apply, and Cancel leaves the
/// old cover. Pro covers can be tried; applying one needs Pro.
Future<CoverPick?> pickCover(
  BuildContext context,
  BoardsScope scope, {
  required String? current,
  required Widget Function(Widget? cover) preview,
  bool artOnly = false,

  /// Offer "Your photo" even when [artOnly] (a board: drawn covers or a
  /// photo, no plain colours).
  bool photo = false,
  List<String> suggested = const [],
}) => showModalBottomSheet<CoverPick>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _Picker(
    current: current,
    preview: preview,
    artOnly: artOnly,
    photo: photo || !artOnly,
    suggested: suggested,
  ),
);

class _Picker extends StatefulWidget {
  final String? current;
  final Widget Function(Widget? cover) preview;
  final bool artOnly, photo;
  final List<String> suggested;
  const _Picker({
    required this.current,
    required this.preview,
    required this.artOnly,
    required this.photo,
    required this.suggested,
  });
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  CoverPick? pick;
  // 'suggested', 'all', a family name, or 'color'.
  String tab = 'suggested';

  List<CoverDef> get _suggested {
    final ids = widget.suggested.toSet();
    final first = [for (final id in ids) ?coverById(id)];
    final rest = [
      for (final f in CoverFamily.values)
        ...coversIn(f).where((c) => !c.pro).take(2),
    ].where((c) => !ids.contains(c.id));
    return [...first, ...rest];
  }

  Widget? _candidate(BuildContext context) {
    final p = pick;
    if (p == null) return null;
    if (p.art != null) return CoverArt(p.art!);
    if (p.color != null)
      return ColoredBox(color: HandyPalette.of(context, p.color!).mark);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final tabs = <(String, String)>[
      ('suggested', tr(context, 'Suggested', 'Gợi ý')),
      ('all', tr(context, 'All', 'Tất cả')),
      for (final f in CoverFamily.values)
        (f.name, tr(context, familyNameEn(f), familyNameVi(f))),
      if (!widget.artOnly) ('color', tr(context, 'Colour', 'Màu')),
    ];
    final covers = switch (tab) {
      'suggested' => _suggested,
      'all' => coverCatalog,
      'color' => const <CoverDef>[],
      _ => coversIn(CoverFamily.values.byName(tab)).toList(),
    };
    final chosen = pick?.art == null ? null : coverById(pick!.art);
    final locked = chosen?.pro == true && !hasPro(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      minChildSize: .5,
      maxChildSize: .95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              tr(context, 'Cover', 'Ảnh bìa'),
              style: theme.textTheme.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BoardsRadii.card),
              child: KeyedSubtree(
                key: const Key('cover-preview'),
                child: widget.preview(_candidate(context)),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                for (final t in tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('cover-tab-${t.$1}'),
                      label: Text(t.$2),
                      selected: tab == t.$1,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => tab = t.$1),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: tab == 'color'
                ? GridView.count(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.5,
                    children: [
                      for (var i = 0; i < HandyPalette.count; i++)
                        _Swatch(
                          key: Key('cover-color-$i'),
                          selected: pick?.color == i,
                          label: tr(context, 'Colour ${i + 1}', 'Màu ${i + 1}'),
                          onTap: () =>
                              setState(() => pick = CoverPick(color: i)),
                          child: ColoredBox(
                            color: HandyPalette.of(context, i).mark,
                          ),
                        ),
                    ],
                  )
                : GridView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                    itemCount:
                        covers.length +
                        (!widget.photo || tab != 'suggested' ? 0 : 1),
                    itemBuilder: (context, i) {
                      if (i == covers.length) {
                        return _Swatch(
                          key: const Key('cover-photo'),
                          selected: false,
                          label: tr(context, 'Your photo', 'Ảnh của bạn'),
                          onTap: () => Navigator.pop(
                            context,
                            const CoverPick(photo: true),
                          ),
                          child: ColoredBox(
                            color: p.raised,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: p.muted,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tr(context, 'Your photo', 'Ảnh của bạn'),
                                  style: theme.textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final c = covers[i];
                      return _Swatch(
                        key: Key('cover-${c.id}'),
                        selected:
                            pick?.art == c.id ||
                            (pick == null && widget.current == c.id),
                        label: tr(context, c.nameEn, c.nameVi),
                        pro: c.pro,
                        onTap: () =>
                            setState(() => pick = CoverPick(art: c.id)),
                        child: CoverArt(c.id),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  if (widget.current != null)
                    TextButton(
                      key: const Key('cover-remove'),
                      onPressed: () =>
                          Navigator.pop(context, const CoverPick(none: true)),
                      child: Text(tr(context, 'Remove cover', 'Bỏ ảnh bìa')),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const Key('cover-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr(context, 'Cancel', 'Huỷ')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('cover-apply'),
                    onPressed: pick == null
                        ? null
                        : () => Navigator.pop(context, pick),
                    child: Text(
                      locked
                          ? tr(context, 'Apply with Pro', 'Dùng với Pro')
                          : tr(context, 'Apply', 'Áp dụng'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final bool selected, pro;
  final String label;
  final VoidCallback onTap;
  final Widget child;
  const _Swatch({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
    this.pro = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: pro ? '$label, Pro' : label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BoardsRadii.control),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BoardsRadii.control),
            border: Border.all(
              color: selected ? p.primary : Colors.transparent,
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(BoardsRadii.control - 3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (pro) const Positioned(top: 6, right: 6, child: ProBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
