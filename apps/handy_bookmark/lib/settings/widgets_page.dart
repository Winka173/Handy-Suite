import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../platform/home_widgets.dart';
import '../platform/widget_styles.dart';
import '../pro/entitlements.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// Settings › Home-screen widgets: what each of the five shows, drawn from
/// the same data the widget gets; the style (three free, six Pro, which can
/// be looked at before buying); the collection the shelf and the picks use;
/// names on or off. The launcher places widgets, not the app.
class WidgetsPage extends StatefulWidget {
  final SaveScope scope;
  const WidgetsPage({super.key, required this.scope});
  @override
  State<WidgetsPage> createState() => _WidgetsPageState();
}

class _WidgetsPageState extends State<WidgetsPage> {
  SaveScope get scope => widget.scope;

  /// A Pro style looked at without Pro: shown in the previews only.
  String? previewing;

  Future<void> _pref(String key, Object? v) => scope.run(
    context,
    () => scope.c.update(
      (l) => l,
      prefs: {...scope.c.preferences, key: v}..removeWhere((_, v) => v == null),
    ),
  );

  Future<void> _pickCollection(SaveLibrary l) async {
    final id = await showDialog<String>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: Text(tr(dialog, 'Collection', 'Bộ sưu tập')),
        children: [
          for (final c in l.collections.where((c) => c.parentId == null))
            SimpleDialogOption(
              key: Key('widget-collection-${c.id}'),
              onPressed: () => Navigator.pop(dialog, c.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(c.name),
              ),
            ),
        ],
      ),
    );
    if (id != null) await _pref('widgetCollection', id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      final l = scope.library;
      final prefs = scope.c.preferences;
      final vi = Localizations.localeOf(context).languageCode == 'vi';
      final pro = hasPro(context);
      final names = prefs['widgetHideNames'] != true;
      final col = prefs['widgetCollection'] as String?;
      final applied = bookmarkWidgetStyleOf(prefs, pro: pro);
      final shown = previewing == null
          ? applied
          : bookmarkWidgetStyleById(previewing);
      final shelf = widgetCollection(l, col);
      Widget card(
        String key,
        String name,
        HomeWidgetView v, {
        bool isPro = false,
        Widget? body,
      }) => Padding(
        key: Key('widget-$key'),
        padding: const EdgeInsets.only(top: HandySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The widget's name above it; inside, only what it draws.
            Row(
              children: [
                Expanded(child: Text(name, style: theme.textTheme.labelLarge)),
                if (isPro && !pro)
                  Text(
                    'Pro',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: p.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: HandySpace.s),
            Semantics(
              label: tr(context, 'Preview of $name', 'Xem trước $name'),
              child: Container(
                padding: const EdgeInsets.all(HandySpace.l),
                decoration: BoxDecoration(
                  color: shown.bg ?? p.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: shown.accent ?? p.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: HandySpace.s),
                        Expanded(
                          child: Text(
                            v.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: shown.muted ?? p.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (v.value.isNotEmpty)
                      Text(
                        v.value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: shown.ink,
                        ),
                      ),
                    if (v.detail.isNotEmpty)
                      Text(
                        v.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: shown.muted ?? p.muted,
                        ),
                      ),
                    ?body,
                    if (body == null)
                      for (final r in v.rows)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            r.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: shown.ink ?? p.ink),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
      final gallery = [
        for (final b in [
          for (final b in l.bookmarks)
            if (b.deletedAt == null && !b.isArchived) b,
        ]..sort((a, b) => b.savedAt.compareTo(a.savedAt)))
          b,
      ].take(12).toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'Home-screen widgets', 'Widget màn hình chính'),
          ),
        ),
        body: ListView(
          key: const Key('widgets-page'),
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            0,
            HandySpace.l,
            HandySpace.xl,
          ),
          children: [
            Text(
              homeWidgetsSupported
                  ? tr(
                      context,
                      'To add one: touch and hold an empty spot on the home '
                          'screen › Widgets › Handy Bookmark, then drag it '
                          'out. Widgets never send notifications; they show '
                          'what is there when you look.',
                      'Thêm widget: giữ một chỗ trống trên màn hình chính › '
                          'Tiện ích (Widget) › Handy Bookmark, rồi kéo ra. '
                          'Widget không gửi thông báo; chỉ hiện khi bạn nhìn.',
                    )
                  : tr(
                      context,
                      'Home-screen widgets are on Android. Here you can see '
                          'what they show.',
                      'Widget màn hình chính có trên Android. Ở đây bạn xem '
                          'trước nội dung của chúng.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: HandySpace.m),
            SettingsPanel(
              gap: false,
              rows: [
                SettingsSwitch(
                  key: const Key('widget-hide-names'),
                  icon: Icons.visibility_off_outlined,
                  title: tr(
                    context,
                    'Hide names on widgets',
                    'Ẩn tên trên widget',
                  ),
                  subtitle: tr(
                    context,
                    'On: counts only, nothing readable off your home screen.',
                    'Bật: chỉ hiện số đếm, không lộ tên ra màn hình chính.',
                  ),
                  value: !names,
                  onChanged: (v) => _pref('widgetHideNames', v ? true : null),
                ),
                if (l.collections.isNotEmpty)
                  SettingsRow(
                    key: const Key('widget-collection'),
                    icon: Icons.collections_bookmark_outlined,
                    title: tr(
                      context,
                      'Collection for the widgets',
                      'Bộ sưu tập cho widget',
                    ),
                    subtitle:
                        shelf?.name ?? tr(context, 'Not sorted', 'Chưa xếp'),
                    navigates: true,
                    onTap: () => _pickCollection(l),
                  ),
              ],
            ),
            const SizedBox(height: HandySpace.l),
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Style', 'Kiểu'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Wrap(
              key: const Key('widget-styles'),
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final w in bookmarkWidgetStyles)
                  ChoiceChip(
                    key: Key('widget-style-${w.id}'),
                    avatar: CircleAvatar(
                      radius: 9,
                      backgroundColor: w.bg ?? p.surface,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: w.accent ?? p.primary,
                      ),
                    ),
                    label: Text(
                      '${tr(context, w.en, w.vi)}${w.pro ? ' · Pro' : ''}',
                    ),
                    selected: shown.id == w.id,
                    onSelected: (_) {
                      if (w.pro && !pro) {
                        setState(() => previewing = w.id);
                        return;
                      }
                      setState(() => previewing = null);
                      _pref('widgetStyle', w.id == 'system' ? null : w.id);
                    },
                  ),
              ],
            ),
            if (previewing != null && !pro) ...[
              const SizedBox(height: HandySpace.s),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Previewing. Your widgets keep their current style.',
                        'Đang xem trước. Widget của bạn vẫn giữ kiểu hiện tại.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: HandySpace.s),
                  FilledButton(
                    key: const Key('widget-style-apply'),
                    onPressed: () async {
                      final id = previewing!;
                      if (!await requirePro(context, ProFeature.widgets) ||
                          !mounted) {
                        return;
                      }
                      setState(() => previewing = null);
                      await _pref('widgetStyle', id);
                    },
                    child: Text(tr(context, 'Apply with Pro', 'Dùng với Pro')),
                  ),
                ],
              ),
            ],
            card(
              'save',
              tr(context, 'Quick save', 'Lưu nhanh'),
              quickSaveView(vi: vi),
            ),
            card(
              'queue',
              tr(context, 'Reading queue', 'Hàng chờ đọc'),
              queueView(l, vi: vi, names: names),
            ),
            card(
              'shelf',
              tr(context, 'Favourite collection', 'Bộ sưu tập yêu thích'),
              shelfView(l, vi: vi, collection: col, names: names),
            ),
            card(
              'picks',
              tr(context, 'Reading picks', 'Gợi ý đọc'),
              picksView(
                l,
                DateTime.now(),
                vi: vi,
                pro: true,
                collection: col,
                names: names,
              ),
              isPro: true,
            ),
            card(
              'gallery',
              tr(context, 'Gallery', 'Thư viện ảnh'),
              HomeWidgetView(
                title: tr(context, 'Gallery', 'Thư viện ảnh'),
                value: '',
                uri: '',
              ),
              isPro: true,
              body: _GalleryPreview(scope: scope, items: gallery),
            ),
          ],
        ),
      );
    },
  );
}

/// Four recent pictures, as the Gallery widget lays them out.
class _GalleryPreview extends StatelessWidget {
  final SaveScope scope;
  final List<Bookmark> items;
  const _GalleryPreview({required this.scope, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return FutureBuilder<List<(Bookmark, Uint8List)>>(
      future: () async {
        final out = <(Bookmark, Uint8List)>[];
        for (final b in items) {
          if (out.length == 4) break;
          final bytes = await scope.c.thumbnail(b.id);
          if (bytes != null && bytes.isNotEmpty) out.add((b, bytes));
        }
        return out;
      }(),
      builder: (context, snap) {
        final pics = snap.data ?? const [];
        if (snap.hasData && pics.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr(context, 'No pictures yet', 'Chưa có ảnh'),
              style: TextStyle(color: p.muted),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: HandySpace.s),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: [
              for (final (_, bytes) in pics)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
