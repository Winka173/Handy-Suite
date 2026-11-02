import 'dart:math' as math;
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import '../editor/paint.dart';
import '../editor/studio_page.dart';
import '../profiles/profiles_page.dart';
import '../scope.dart';
import 'new_design.dart';

/// A side drawn small, as it really is: the same painter as the studio.
class CardThumb extends StatelessWidget {
  final CardScope scope;
  final CardDocument doc;
  final double height;
  const CardThumb({
    super.key,
    required this.scope,
    required this.doc,
    this.height = 120,
  });
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.images,
    builder: (context, _) => AspectRatio(
      aspectRatio: doc.width / doc.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: HandyColors.of(context).border),
        ),
        child: ExcludeSemantics(
          child: CustomPaint(
            painter: _ThumbPainter(
              doc,
              PaintContext(
                profile: scope.library.profiles[doc.profileId],
                measurer: _thumbMeasurer,
                image: (id) => scope.images[id],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _thumbMeasurer = FlutterMeasurer();

class _ThumbPainter extends CustomPainter {
  final CardDocument doc;
  final PaintContext ctx;
  _ThumbPainter(this.doc, this.ctx);
  @override
  bool shouldRepaint(_ThumbPainter old) => old.doc != doc;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / doc.width);
    if (doc.pages.first.background == null)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, doc.width, doc.height),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    paintPage(canvas, doc, doc.pages.first, ctx);
  }
}

class HomePage extends StatelessWidget {
  final CardScope scope;
  final VoidCallback openSettings;
  const HomePage({super.key, required this.scope, required this.openSettings});

  Future<void> create(BuildContext context) async {
    final doc = await showNewDesign(context, scope);
    if (doc == null || !context.mounted) return;
    final saved = await scope.library.saveDesign(doc);
    if (context.mounted) await openStudio(context, scope, saved.id);
  }

  Future<void> importProject(BuildContext context) async {
    try {
      final file = await pickProjectFile(scope.files);
      if (file == null || !context.mounted) return;
      final contents = decodeCardProject(file.bytes, scope.library.registry);
      if (!context.mounted) return;
      final ok = await confirmHandy(
        context,
        title: tr(
          context,
          'Add what this file holds?',
          'Thêm nội dung của file?',
        ),
        message: [
          tr(
            context,
            '${contents.designs.length} designs, ${contents.profiles.length} profiles, ${contents.templates.length} templates, ${contents.assets.length} pictures.',
            '${contents.designs.length} thiết kế, ${contents.profiles.length} hồ sơ, ${contents.templates.length} mẫu, ${contents.assets.length} ảnh.',
          ),
          if (contents.missingAssets.isNotEmpty)
            tr(
              context,
              '${contents.missingAssets.length} pictures are missing from the file and will show blank.',
              '${contents.missingAssets.length} ảnh không có trong file và sẽ để trống.',
            ),
          tr(
            context,
            'Nothing here is replaced.',
            'Không có gì ở đây bị thay thế.',
          ),
        ].join(' '),
        confirmLabel: tr(context, 'Add', 'Thêm'),
      );
      if (!ok) return;
      final added = await scope.library.importProject(contents);
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            '${added.designs} designs added.',
            'Đã thêm ${added.designs} thiết kế.',
          ),
        );
    } catch (e) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not added: ${errorText(context, e)}',
            'Chưa thêm: ${errorText(context, e)}',
          ),
        );
    }
  }

  Future<void> designMenu(
    BuildContext context,
    CardDocument d,
    String action,
  ) async {
    final lib = scope.library;
    switch (action) {
      case 'duplicate':
        await lib.duplicateDesign(
          d,
          suffix: tr(context, ' (copy)', ' (bản sao)'),
        );
      case 'delete':
        await lib.deleteDesign(d.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(tr(context, 'Design deleted.', 'Đã xóa thiết kế.')),
              persist: false,
              action: SnackBarAction(
                label: tr(context, 'Undo', 'Hoàn tác'),
                onPressed: () => lib.saveDesign(d, touch: false),
              ),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.library,
    builder: (context, _) {
      final lib = scope.library;
      final theme = Theme.of(context);
      final designs = lib.recent;
      final width = MediaQuery.sizeOf(context).width;
      final columns = math.max(
        1,
        ((math.min(width, HandySpace.contentWide) - 32) / 260).floor(),
      );
      return Scaffold(
        key: const Key('card-home'),
        appBar: HandyTopBar(
          mark: Icons.badge_outlined,
          name: 'Handy Card',
          actions: [
            IconButton(
              key: const Key('home-import'),
              tooltip: tr(context, 'Add from a file', 'Thêm từ file'),
              icon: const Icon(Icons.file_open_outlined),
              onPressed: () => importProject(context),
            ),
          ],
        ),
        floatingActionButton: designs.isEmpty
            ? null
            : FloatingActionButton.extended(
                key: const Key('home-new'),
                onPressed: () => create(context),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'New design', 'Thiết kế mới')),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            96,
          ),
          children: [
            HandyContent(
              maxWidth: HandySpace.contentWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      designs.isEmpty
                          ? tr(context, 'Design a card', 'Thiết kế một tấm thẻ')
                          : tr(context, 'Your designs', 'Thiết kế của bạn'),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (lib.unreadable.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: HandySpace.m),
                      child: HandyNotice(
                        tr(
                          context,
                          '${lib.unreadable.length} saved items could not be read; they are kept untouched.',
                          '${lib.unreadable.length} mục đã lưu không đọc được; chúng được giữ nguyên.',
                        ),
                        tone: HandyTone.warning,
                      ),
                    ),
                  if (designs.isEmpty) ...[
                    const SizedBox(height: HandySpace.s),
                    Text(
                      tr(
                        context,
                        'Business cards, badges, social cards or anything else: start blank or from a layout below. Everything stays on this device.',
                        'Danh thiếp, thẻ sự kiện, thẻ mạng xã hội hay bất cứ gì: bắt đầu từ trang trắng hoặc một mẫu bên dưới. Mọi thứ nằm trên máy này.',
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: HandySpace.l),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FilledButton.icon(
                        key: const Key('home-new-empty'),
                        onPressed: () => create(context),
                        icon: const Icon(Icons.add),
                        label: Text(tr(context, 'New design', 'Thiết kế mới')),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: HandySpace.l),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: HandySpace.l,
                      mainAxisSpacing: HandySpace.l,
                      childAspectRatio: 1.25,
                      children: [
                        for (final d in designs)
                          _DesignTile(
                            scope: scope,
                            doc: d,
                            onMenu: (a) => designMenu(context, d, a),
                          ),
                      ],
                    ),
                  ],
                  HandyLabel(
                    tr(context, 'Start from a layout', 'Bắt đầu từ mẫu'),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final t in cardTemplates)
                          _TemplateTile(
                            scope: scope,
                            doc: t.build(lib.registry, DateTime.utc(2026)),
                            title: tr(context, t.en, t.vi),
                            onTap: () async {
                              final doc = t.build(lib.registry, lib.clock());
                              final saved = await lib.saveDesign(
                                doc.copyWith(name: tr(context, t.en, t.vi)),
                              );
                              if (context.mounted)
                                await openStudio(context, scope, saved.id);
                            },
                          ),
                        for (final t in lib.templates.values)
                          _TemplateTile(
                            scope: scope,
                            doc: t,
                            title: t.name,
                            onTap: () async {
                              final saved = await lib.duplicateDesign(
                                t,
                                suffix: '',
                              );
                              if (context.mounted)
                                await openStudio(context, scope, saved.id);
                            },
                          ),
                      ],
                    ),
                  ),
                  HandyLabel(
                    tr(context, 'Profiles', 'Hồ sơ'),
                    trailing: TextButton(
                      key: const Key('home-profiles'),
                      onPressed: () => openProfiles(context, scope),
                      child: Text(
                        lib.profiles.isEmpty
                            ? tr(context, 'Add one', 'Thêm hồ sơ')
                            : tr(context, 'Manage', 'Quản lý'),
                      ),
                    ),
                  ),
                  if (lib.profiles.isEmpty)
                    Text(
                      tr(
                        context,
                        'A profile holds the name, phone, email and links your cards show. Edit it once and every card that uses it follows.',
                        'Hồ sơ giữ tên, điện thoại, email, liên kết mà thẻ hiển thị. Sửa một lần, mọi thẻ dùng nó đều theo.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HandyColors.of(context).muted,
                      ),
                    )
                  else
                    HandyGroup(
                      children: [
                        for (final p in lib.profiles.values)
                          HandyTile(
                            icon: Icons.person_outline,
                            title: p.displayName.isEmpty
                                ? p.organization
                                : p.displayName,
                            subtitle: [
                              p.role,
                              p.organization,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            navigates: true,
                            onTap: () => editProfile(context, scope, p),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DesignTile extends StatelessWidget {
  final CardScope scope;
  final CardDocument doc;
  final ValueChanged<String> onMenu;
  const _DesignTile({
    required this.scope,
    required this.doc,
    required this.onMenu,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mm =
        '${fromPoints(doc.width, 'mm').toStringAsFixed(0)} × ${fromPoints(doc.height, 'mm').toStringAsFixed(0)} mm';
    return Semantics(
      button: true,
      label:
          '${doc.name.isEmpty ? tr(context, 'Untitled card', 'Thẻ chưa đặt tên') : doc.name}, $mm',
      child: InkWell(
        key: Key('design-${doc.id}'),
        onTap: () => openStudio(context, scope, doc.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: CardThumb(scope: scope, doc: doc),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.name.isEmpty
                            ? tr(context, 'Untitled card', 'Thẻ chưa đặt tên')
                            : doc.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '$mm · ${doc.pages.length} ${tr(context, doc.pages.length == 1 ? 'side' : 'sides', 'mặt')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                HandyMenuButton(
                  items: [
                    HandyMenuItem(
                      Icons.copy_outlined,
                      tr(context, 'Duplicate', 'Nhân bản'),
                      () => onMenu('duplicate'),
                    ),
                    HandyMenuItem(
                      Icons.delete_outline,
                      tr(context, 'Delete', 'Xóa'),
                      () => onMenu('delete'),
                      destructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final CardScope scope;
  final CardDocument doc;
  final String title;
  final VoidCallback onTap;
  const _TemplateTile({
    required this.scope,
    required this.doc,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: HandySpace.m),
    child: Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 150,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: CardThumb(scope: scope, doc: doc),
                ),
              ),
              const SizedBox(height: HandySpace.xs),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
