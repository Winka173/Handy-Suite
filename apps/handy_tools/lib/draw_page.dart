import 'package:flutter/services.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';

enum DrawMode { pick, teams, coin, dice }

/// Chance, shown as it fell: a pick from a list, teams, a coin or dice. The
/// result is the largest thing on the panel; earlier draws stay listed while
/// the panel is open, so a draw is never quietly redone. Nothing is stored.
class DrawPage extends StatefulWidget {
  /// Builds the bench header around this panel's own actions.
  final Widget Function(BuildContext, List<Widget>)? header;
  const DrawPage({super.key, this.header});
  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final list = TextEditingController(),
      dice = TextEditingController(text: '2d6');
  DrawMode mode = DrawMode.pick;
  int count = 1, teams = 2;

  /// The latest result first; each is the text that was shown.
  final results = <(DrawMode, String)>[];
  String error = '';

  List<String> get entries {
    try {
      return drawEntries(list.text);
    } on FormatException {
      return const [];
    }
  }

  @override
  void dispose() {
    list.dispose();
    dice.dispose();
    super.dispose();
  }

  bool ready(List<String> e) => switch (mode) {
    DrawMode.pick => e.isNotEmpty && count <= e.length,
    DrawMode.teams => e.length >= 2 && teams <= e.length,
    _ => true,
  };

  void draw() {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    try {
      final e = drawEntries(list.text);
      final text = switch (mode) {
        DrawMode.pick => drawLots(e, count).join('\n'),
        DrawMode.teams => [
          for (final (i, t) in drawTeams(e, teams).indexed)
            '${vi ? 'Đội' : 'Team'} ${i + 1}: ${t.join(', ')}',
        ].join('\n'),
        DrawMode.coin =>
          flipCoin() ? (vi ? 'Ngửa' : 'Heads') : (vi ? 'Sấp' : 'Tails'),
        DrawMode.dice => () {
          final rolls = rollDice(dice.text);
          final total = rolls.fold(0, (a, b) => a + b);
          return rolls.length == 1 ? '$total' : '${rolls.join(' + ')} = $total';
        }(),
      };
      setState(() {
        error = '';
        results.insert(0, (mode, text));
        if (results.length > 20) results.removeLast();
      });
      HapticFeedback.selectionClick();
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final e = entries, latest = results.firstOrNull;
    final canDraw = ready(e);
    Widget stepper(
      String label,
      int value,
      int max,
      void Function(int) set,
    ) => Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
        IconButton(
          tooltip: tr(context, 'Fewer', 'Bớt'),
          onPressed: value > 1 ? () => setState(() => set(value - 1)) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
          ),
        ),
        IconButton(
          tooltip: tr(context, 'More', 'Thêm'),
          onPressed: value < max ? () => setState(() => set(value + 1)) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (canDraw) draw();
        },
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) widget.header!(context, const []),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final (m, en, vi) in [
                (DrawMode.pick, 'Pick', 'Chọn'),
                (DrawMode.teams, 'Teams', 'Chia đội'),
                (DrawMode.coin, 'Coin', 'Tung xu'),
                (DrawMode.dice, 'Dice', 'Xúc xắc'),
              ])
                ChoiceChip(
                  key: Key('draw-mode-${m.name}'),
                  label: Text(tr(context, en, vi)),
                  selected: mode == m,
                  onSelected: (_) => setState(() {
                    mode = m;
                    error = '';
                  }),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.l),
          Card(
            color: c.lead,
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: SelectionArea(
                      child: Text(
                        latest != null && latest.$1 == mode
                            ? latest.$2
                            : tr(context, 'Not drawn yet', 'Chưa bốc'),
                        key: const Key('draw-result'),
                        // Long teams read better a size down than wrapped
                        // across the whole phone screen.
                        style:
                            ((latest?.$2.length ?? 0) > 60
                                    ? theme.textTheme.titleLarge
                                    : theme.textTheme.headlineMedium)
                                ?.copyWith(
                                  color: latest != null && latest.$1 == mode
                                      ? theme.colorScheme.onSurface
                                      : c.muted,
                                  fontFeatures: tabular,
                                  height: 1.3,
                                ),
                      ),
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: HandySpace.s),
                    Text(
                      error,
                      key: const Key('draw-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: c.negative,
                      ),
                    ),
                  ],
                  const SizedBox(height: HandySpace.l),
                  Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      FilledButton.icon(
                        key: const Key('draw-go'),
                        onPressed: canDraw ? draw : null,
                        icon: const Icon(Icons.casino_outlined, size: 18),
                        label: Text(
                          results.isEmpty
                              ? tr(context, 'Draw', 'Bốc')
                              : tr(context, 'Draw again', 'Bốc lại'),
                        ),
                      ),
                      if (latest != null && latest.$1 == mode)
                        OutlinedButton.icon(
                          key: const Key('draw-copy'),
                          onPressed: () => copyToClipboard(context, latest.$2),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(tr(context, 'Copy', 'Sao chép')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (mode == DrawMode.pick || mode == DrawMode.teams) ...[
            HandyLabel(
              tr(context, 'Names or things', 'Tên hoặc món'),
              trailing: Text(
                tr(context, '${e.length} entries', '${e.length} mục'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ),
            TextField(
              key: const Key('draw-list'),
              controller: list,
              minLines: 4,
              maxLines: 10,
              onChanged: (_) => setState(() {
                final n = entries.length;
                if (count > n && n > 0) count = n;
                if (teams > n && n >= 2) teams = n;
              }),
              decoration: InputDecoration(
                hintText: tr(
                  context,
                  'One per line: An, Bình, Chi…',
                  'Mỗi dòng một mục: An, Bình, Chi…',
                ),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            if (mode == DrawMode.pick)
              stepper(
                tr(context, 'How many to pick', 'Chọn bao nhiêu'),
                count,
                e.isEmpty ? 1 : e.length,
                (v) => count = v,
              )
            else
              stepper(
                tr(context, 'Number of teams', 'Số đội'),
                teams,
                e.length < 2 ? 2 : e.length,
                (v) => teams = v < 2 ? 2 : v,
              ),
            if (!canDraw)
              Text(
                mode == DrawMode.pick
                    ? tr(
                        context,
                        'Add at least one entry.',
                        'Thêm ít nhất một mục.',
                      )
                    : tr(
                        context,
                        'Teams need at least as many entries as teams.',
                        'Cần số mục ít nhất bằng số đội.',
                      ),
                key: const Key('draw-needs'),
                style: theme.textTheme.bodySmall,
              ),
          ],
          if (mode == DrawMode.dice) ...[
            HandyLabel(tr(context, 'Dice', 'Xúc xắc')),
            TextField(
              key: const Key('draw-dice'),
              controller: dice,
              decoration: InputDecoration(
                helperText: tr(
                  context,
                  'Like 2d6: 1-20 dice, 2-100 sides',
                  'Dạng 2d6: 1-20 viên, 2-100 mặt',
                ),
              ),
              onSubmitted: (_) => draw(),
            ),
          ],
          if (results.length > 1) ...[
            HandyLabel(tr(context, 'Earlier draws', 'Lần bốc trước')),
            HandyGroup(
              children: [
                for (final r in results.skip(1).take(8))
                  ListTile(
                    dense: true,
                    title: Text(
                      r.$2.replaceAll('\n', ' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'Drawn on this device with a secure random source. Not saved.',
              'Bốc trên thiết bị bằng nguồn ngẫu nhiên an toàn. Không được lưu.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
