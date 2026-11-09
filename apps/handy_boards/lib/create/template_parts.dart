import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/board_menus.dart' show ProBadge;
import '../board/category_strip.dart';
import '../board/kanban_view.dart';
import '../board/key_dates.dart' show keyDateLine;
import '../board/week_bar.dart';
import '../covers/cover_art.dart';
import '../design/theme.dart';
import 'new_board.dart' show isVi;

String groupName(BuildContext context, TemplateGroup g) => switch (g) {
  TemplateGroup.study => tr(context, 'Study', 'Học tập'),
  TemplateGroup.work => tr(context, 'Work', 'Công việc'),
  TemplateGroup.personal => tr(context, 'Personal & home', 'Cá nhân & nhà'),
  TemplateGroup.creative => tr(context, 'Creative', 'Sáng tạo'),
  TemplateGroup.planning => tr(context, 'Plans & occasions', 'Kế hoạch & dịp'),
};

/// "Not started → In progress → Completed", with optional columns as they
/// start (on).
String columnsLine(BoardTemplate t, bool vi) =>
    t.columns.map((c) => c.name.of(vi)).join(' → ');

/// Whether [t] matches what the person typed, in either language, without
/// minding accents.
bool templateMatches(BoardTemplate t, String query) {
  final q = foldSearch(query.trim());
  if (q.isEmpty) return true;
  final hay = foldSearch(
    [
      t.name.en,
      t.name.vi,
      t.goal.en,
      t.goal.vi,
      t.example.en,
      t.example.vi,
      ...t.tags,
    ].join(' '),
  );
  return q.split(RegExp(r'\s+')).every(hay.contains);
}

/// A template in the gallery: its cover, name, goal, its columns, and Free
/// or Pro in words (never colour alone).
class TemplateTile extends StatelessWidget {
  final BoardTemplate template;
  final VoidCallback onTap;

  /// Phones: a row (picture left, words in full on the right).
  final bool row;
  const TemplateTile({
    super.key,
    required this.template,
    required this.onTap,
    this.row = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final t = template, vi = isVi(context);
    if (row)
      return Semantics(
        button: true,
        label:
            '${t.name.of(vi)}, ${t.pro ? 'Pro' : tr(context, 'Free', 'Miễn phí')}. '
            '${t.goal.of(vi)}',
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(BoardsRadii.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('template-${t.id}'),
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 92, child: CoverArt(t.cover)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name.of(vi),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (t.pro) const ProBadge(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.goal.of(vi),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: p.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            columnsLine(t, vi),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: p.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    return Semantics(
      button: true,
      label:
          '${t.name.of(vi)}, ${t.pro ? 'Pro' : tr(context, 'Free', 'Miễn phí')}. '
          '${t.goal.of(vi)}',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(BoardsRadii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('template-${t.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(t.cover),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: t.pro ? const ProBadge() : const _FreeBadge(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  t.name.of(vi),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
                child: Text(
                  t.goal.of(vi),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  columnsLine(t, vi),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeBadge extends StatelessWidget {
  const _FreeBadge();
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(BoardsRadii.chip),
      ),
      child: Text(
        tr(context, 'Free', 'Miễn phí'),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// The id every preview board uses: it only ever lives in a throwaway
/// state, never in the person's library.
const previewBoard = '00000000-0000-4000-8000-00000000b0a2';

/// A board drawn by the real Kanban from a throwaway state that is never
/// saved: what a template, or the answers so far, will make.
class BoardPreview extends StatefulWidget {
  final BoardsState state;
  final DateTime now;

  /// Whether the made board keeps the example cards (null: no examples
  /// shown). Every card shown here is an example, labelled so.
  final bool? keepsExamples;
  const BoardPreview({
    super.key,
    required this.state,
    required this.now,
    this.keepsExamples,
  });
  @override
  State<BoardPreview> createState() => _BoardPreviewState();
}

class _BoardPreviewState extends State<BoardPreview> {
  Set<String> focus = const {};

  /// The period shown when the template lays the board out by time, as
  /// the made board will open on.
  TimeWindow? window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final s = widget.state;
    final b = s.get('boards', previewBoard);
    final milestones = milestonesOf(b);
    final unit = boardTimeline(b);
    if (unit == null) window = null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The key dates as the board says them, under its title.
        if (milestones.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              [
                for (final m in milestones)
                  keyDateLine(context, m.label, m.day, widget.now),
              ].join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
          ),
        if (categoriesOf(s, previewBoard).isNotEmpty) ...[
          CategoryStrip(
            state: s,
            board: previewBoard,
            selected: focus,
            onSelect: (v) => setState(
              () => focus = focus.contains(v)
                  ? ({...focus}..remove(v))
                  : {...focus, v},
            ),
            showHeader: false,
          ),
          const SizedBox(height: 8),
        ],
        // What the cards here are: examples, kept on the made board or not.
        if (topTasks(s, board: previewBoard).isEmpty ||
            widget.keepsExamples != null)
          Padding(
            key: const Key('preview-examples-note'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              topTasks(s, board: previewBoard).isEmpty
                  ? tr(
                      context,
                      'No cards yet: the board starts empty unless you add the examples.',
                      'Chưa có thẻ: bảng bắt đầu trống, trừ khi bạn thêm thẻ ví dụ.',
                    )
                  : widget.keepsExamples!
                  ? tr(
                      context,
                      'Cards marked Example come with the board; delete them any time.',
                      'Thẻ có nhãn Ví dụ sẽ có sẵn trong bảng; xoá lúc nào cũng được.',
                    )
                  : tr(
                      context,
                      'Cards marked Example are only a preview: the board starts empty, as Add example cards is off.',
                      'Thẻ có nhãn Ví dụ chỉ để xem trước: bảng tạo ra sẽ trống vì bạn đã tắt Thêm thẻ ví dụ.',
                    ),
              style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
            ),
          ),
        if (unit != null)
          TimelineBar(
            unit: unit,
            window: window ??= timelineWindow(unit, widget.now),
            now: widget.now,
            onWindow: (w) => setState(() => window = w),
          ),
        Expanded(
          child: KanbanView(
            state: s,
            board: previewBoard,
            now: widget.now,
            actions: KanbanActions(examples: widget.keepsExamples != null),
            filter: KanbanFilter(
              categories: focus,
              window: unit == null ? null : window,
            ),
          ),
        ),
      ],
    );
  }
}

/// A preview page's body: what the board is above, the board below. A tall
/// screen keeps the board in the room left under the header. A short one
/// (a phone on its side, BlueStacks' landscape window, very large text)
/// scrolls the header away and gives the board the whole height, and a
/// column at its top or bottom hands the rest of a swipe to the page.
class PreviewBody extends StatefulWidget {
  final Widget header;
  final Widget board;
  const PreviewBody({super.key, required this.header, required this.board});
  @override
  State<PreviewBody> createState() => _PreviewBodyState();
}

class _PreviewBodyState extends State<PreviewBody> {
  final page = ScrollController();

  @override
  void dispose() {
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A preview holds the template's words, the tiles, the week and the
    // column chips: below 960 pt the words scroll away so the board keeps
    // room for its cards.
    final short =
        MediaQuery.sizeOf(context).height < 960 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (!short) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.header,
          Expanded(child: widget.board),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, box) => NotificationListener<OverscrollNotification>(
        onNotification: (n) {
          if (n.depth == 0 ||
              n.metrics.axis != Axis.vertical ||
              !page.hasClients) {
            return false;
          }
          final p = page.position;
          final to = (p.pixels + n.overscroll).clamp(
            p.minScrollExtent,
            p.maxScrollExtent,
          );
          if (to != p.pixels) p.jumpTo(to);
          return false;
        },
        child: SingleChildScrollView(
          key: const Key('preview-scroll'),
          controller: page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              widget.header,
              SizedBox(
                // Never less than a readable board (its category strip
                // and a few cards): on a tiny screen the page scrolls on.
                // A narrow phone wraps the strip's names, so a little more.
                height: box.maxHeight.clamp(
                  MediaQuery.sizeOf(context).width < 360 ? 744.0 : 720.0,
                  double.infinity,
                ),
                child: widget.board,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
