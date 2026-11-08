import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../design/theme.dart';
import '../design/widget_styles.dart';
import '../platform/home_surface.dart';
import '../pro/pro.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// Settings › Home-screen widgets (Android): what each of the five shows,
/// drawn from the same data the widget gets; the board for Progress; card
/// names on or off; how to add one (the launcher places it, not the app).
class WidgetsPage extends StatefulWidget {
  final BoardsScope scope;
  const WidgetsPage({super.key, required this.scope});
  @override
  State<WidgetsPage> createState() => _WidgetsPageState();
}

class _WidgetsPageState extends State<WidgetsPage> {
  BoardsScope get scope => widget.scope;

  /// A Pro style looked at without Pro: shown in the previews only.
  String? previewing;

  Future<void> _pref(BuildContext context, String key, Object? v) => scope.run(
    context,
    () => scope.controller.change(
      (s) => s.copy(
        preferences: {...s.preferences, key: v}
          ..removeWhere((_, v) => v == null),
      ),
      history: false,
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BoardsPalette.of(context);
      final s = scope.state, now = scope.clock();
      final vi = Localizations.localeOf(context).languageCode == 'vi';
      final pro = hasPro(context);
      final views = boardsWidgetViews(s, now, vi: vi, pro: pro);
      final boards = homeBoards(s);
      final chosen = s.preferences['widgetBoard'] as String?;
      final applied = widgetStyleOf(s, pro: pro);
      final shown = previewing == null ? applied : widgetStyleById(previewing);
      Widget card(
        String key,
        String name,
        HomeWidgetView v, {
        bool isPro = false,
      }) => Padding(
        key: Key('widget-$key'),
        padding: const EdgeInsets.only(top: 12),
        child: Semantics(
          label: tr(
            context,
            'Preview of the $name widget',
            'Xem trước widget $name',
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: shown.ink,
                        ),
                      ),
                    ),
                    if (isPro) const ProBadge(),
                  ],
                ),
                const SizedBox(height: 8),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        v.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: shown.muted ?? p.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  v.value,
                  style: theme.textTheme.titleLarge?.copyWith(color: shown.ink),
                ),
                if (v.detail.isNotEmpty)
                  Text(
                    v.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: shown.muted ?? p.muted,
                    ),
                  ),
                if (v.progress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: v.progress! / 100,
                    minHeight: 6,
                    color: shown.accent,
                    backgroundColor: shown.muted?.withValues(alpha: .35),
                  ),
                ],
                for (final r in v.rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      r.$1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: shown.ink),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(
            tr(context, 'Home-screen widgets', 'Widget màn hình chính'),
          ),
        ),
        body: ListView(
          key: const Key('widgets-page'),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              homeWidgetsSupported
                  ? tr(
                      context,
                      'To add one: touch and hold an empty spot on the home '
                          'screen › Widgets › Handy Boards, then drag it out. '
                          'Widgets refresh when the boards change; the phone '
                          'decides exactly when.',
                      'Thêm widget: giữ một chỗ trống trên màn hình chính › '
                          'Tiện ích (Widget) › Handy Boards, rồi kéo ra. Widget '
                          'cập nhật khi bảng thay đổi; máy quyết định lúc nào.',
                    )
                  : tr(
                      context,
                      'Home-screen widgets are on Android. Here you can see what '
                          'they show.',
                      'Widget màn hình chính có trên Android. Ở đây bạn xem trước '
                          'nội dung của chúng.',
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 12),
            SettingsPanel(
              gap: false,
              rows: [
                SettingsSwitch(
                  key: const Key('widgets-names'),
                  icon: Icons.visibility_outlined,
                  title: tr(context, 'Show card names', 'Hiện tên thẻ'),
                  subtitle: tr(
                    context,
                    'Off: widgets show counts only, nothing anyone can read off '
                        'your home screen.',
                    'Tắt: widget chỉ hiện số đếm, không lộ tên việc ra màn hình chính.',
                  ),
                  value: s.preferences['homeWidget'] == true,
                  onChanged: (v) => _pref(context, 'homeWidget', v),
                ),
                if (boards.isNotEmpty)
                  SettingsChoice<String>(
                    key: const Key('widgets-board'),
                    icon: Icons.view_week_outlined,
                    title: tr(
                      context,
                      'Board for Progress',
                      'Bảng cho widget Tiến độ',
                    ),
                    value: boards.any((b) => b.id == chosen)
                        ? chosen!
                        : boards.first.id,
                    options: [for (final b in boards) (b.id, b.str('title'))],
                    onChanged: (v) => _pref(context, 'widgetBoard', v),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Style', 'Kiểu'),
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: const Key('widget-styles'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in widgetStyles)
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
                      '${tr(context, w.nameEn, w.nameVi)}${w.pro ? ' · Pro' : ''}',
                    ),
                    selected: shown.id == w.id,
                    onSelected: (_) {
                      if (w.pro && !pro) {
                        setState(() => previewing = w.id);
                        return;
                      }
                      setState(() => previewing = null);
                      _pref(
                        context,
                        'widgetStyle',
                        w.id == 'system' ? null : w.id,
                      );
                    },
                  ),
              ],
            ),
            if (previewing != null && !pro) ...[
              const SizedBox(height: 8),
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
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('widget-style-apply'),
                    onPressed: () async {
                      final id = previewing!;
                      if (!await requirePro(context, ProFeature.looks) ||
                          !context.mounted) {
                        return;
                      }
                      setState(() => previewing = null);
                      await _pref(context, 'widgetStyle', id);
                    },
                    child: Text(tr(context, 'Apply with Pro', 'Dùng với Pro')),
                  ),
                ],
              ),
            ],
            card(
              'today',
              tr(context, 'Today', 'Hôm nay'),
              boardsHomeView(s, now, vi: vi),
            ),
            card(
              'progress',
              tr(context, 'Board progress', 'Tiến độ bảng'),
              views['progress_']!,
            ),
            card(
              'upcoming',
              tr(context, 'Left behind & coming up', 'Còn tồn & sắp tới'),
              views['upcoming_']!,
            ),
            card(
              'work',
              tr(context, 'My Work', 'Việc của tôi'),
              views['work_']!,
              isPro: true,
            ),
            card(
              'week',
              tr(context, 'Week', 'Tuần'),
              views['week_']!,
              isPro: true,
            ),
          ],
        ),
      );
    },
  );
}
