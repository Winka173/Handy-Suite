import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'home_page.dart' show CardThumb;
import '../editor/studio_page.dart';
import '../scope.dart';

/// Occasions the gallery filters by, in the order people look for them.
const templateKinds = [
  ('business', 'Business cards', 'Danh thiếp'),
  ('social', 'Social and profile', 'Mạng xã hội'),
  ('invitation', 'Invitations', 'Thiệp mời'),
  ('event', 'Events and flyers', 'Sự kiện, tờ rơi'),
  ('brand', 'Shop and tags', 'Cửa hàng, thẻ giá'),
  ('document', 'CV', 'CV'),
  ('portfolio', 'Portfolio', 'Portfolio'),
];

/// One template of each occasion, for the home screen's short row.
List<CardTemplate> featuredTemplates() => [
  for (final (kind, _, _) in templateKinds)
    ?cardTemplates.where((t) => t.kind == kind).firstOrNull,
];

/// A new design from [t], straight into the studio.
Future<void> startFromTemplate(
  BuildContext context,
  CardScope scope,
  CardTemplate t,
) async {
  final lib = scope.library;
  final doc = t.build(lib.registry, lib.clock());
  final saved = await lib.saveDesign(
    doc.copyWith(name: tr(context, t.en, t.vi)),
  );
  if (context.mounted) await openStudio(context, scope, saved.id);
}

/// Every template, filtered by occasion. Previews are built only as they
/// scroll into view.
class TemplateGalleryPage extends StatefulWidget {
  final CardScope scope;
  const TemplateGalleryPage({super.key, required this.scope});
  @override
  State<TemplateGalleryPage> createState() => _TemplateGalleryPageState();
}

class _TemplateGalleryPageState extends State<TemplateGalleryPage> {
  String? kind;
  final _docs = <String, CardDocument>{};

  CardDocument doc(CardTemplate t) => _docs.putIfAbsent(
    t.id,
    () => t.build(widget.scope.library.registry, DateTime.utc(2026)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = cardTemplates
        .where((t) => t.id != 'blank' && (kind == null || t.kind == kind))
        .toList();
    return HandyPage(
      title: tr(context, 'Templates', 'Mẫu thiết kế'),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.s,
              HandySpace.l,
              HandySpace.m,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      '${shown.length} templates · every text, colour and picture can be changed',
                      '${shown.length} mẫu · đổi được mọi chữ, màu và ảnh',
                    ),
                    key: const Key('gallery-count'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: HandySpace.m),
                  Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      ChoiceChip(
                        key: const Key('gallery-kind-all'),
                        label: Text(tr(context, 'All', 'Tất cả')),
                        selected: kind == null,
                        onSelected: (_) => setState(() => kind = null),
                      ),
                      for (final (id, en, vi) in templateKinds)
                        ChoiceChip(
                          key: Key('gallery-kind-$id'),
                          label: Text(tr(context, en, vi)),
                          selected: kind == id,
                          onSelected: (_) => setState(() => kind = id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              0,
              HandySpace.l,
              HandySpace.xxl,
            ),
            sliver: SliverLayoutBuilder(
              builder: (context, box) => SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (box.crossAxisExtent / 190).floor().clamp(
                    2,
                    6,
                  ),
                  mainAxisSpacing: HandySpace.l,
                  crossAxisSpacing: HandySpace.l,
                  childAspectRatio: .95,
                ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final t = shown[i];
                  return Semantics(
                    button: true,
                    label: tr(context, t.en, t.vi),
                    child: InkWell(
                      key: Key('gallery-${t.id}'),
                      onTap: () => startFromTemplate(context, widget.scope, t),
                      borderRadius: BorderRadius.circular(HandyRadius.control),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: CardThumb(
                                scope: widget.scope,
                                doc: doc(t),
                              ),
                            ),
                          ),
                          const SizedBox(height: HandySpace.xs),
                          Text(
                            tr(context, t.en, t.vi),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
