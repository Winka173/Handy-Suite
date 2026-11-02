import 'package:handy_recall/anki.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../home/forecast_strip.dart';
import '../study/anki_import.dart';
import '../study/schedule.dart';

/// "What will come in, and what will not?": the card count and when they
/// come due first, then the choice about Anki's schedule, the new decks,
/// the kinds of card, what is left out and why, and the first cards.
class AnkiPreview extends StatelessWidget {
  final AnkiImportController controller;
  final bool busy;
  const AnkiPreview({super.key, required this.controller, required this.busy});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.preview!;
    final theme = Theme.of(context);
    final colors = HandyColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: colors.muted);
    final ahead = c.ahead;
    final trial = c.trial;
    final now = c.store.clock();
    final left = <String>[
      if (p.skipped > 0)
        tr(
          context,
          '${p.skipped} cards that are empty once cleaned, use an unknown note type, or are Anki image occlusions',
          '${p.skipped} thẻ trống sau khi làm sạch, dùng kiểu ghi chú không đọc được, hoặc là che ảnh của Anki',
        ),
      if (p.imagesDropped > 0)
        tr(
          context,
          '${p.imagesDropped} pictures: not PNG or JPEG, over 500 KB, missing, damaged, or past the import limit',
          '${p.imagesDropped} ảnh: không phải PNG/JPEG, quá 500 KB, bị thiếu, bị hỏng hoặc vượt giới hạn',
        ),
      if (p.sounds > 0)
        tr(
          context,
          '${p.sounds} sounds and videos: Recall reads text aloud but plays no recordings',
          '${p.sounds} âm thanh và video: Recall đọc chữ nhưng không phát bản ghi',
        ),
    ];
    Widget row(String label, int value, {Key? key, int? hue}) => ListTile(
      key: key,
      leading: hue == null ? null : HandyDot(hue, size: 12),
      minLeadingWidth: 12,
      title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatFigure(context, '$value'),
        style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabular),
      ),
    );
    // The answer and the one choice; then what comes in, in detail.
    final first = <Widget>[
      HandyGroup(
        color: colors.lead,
        children: [
          Padding(
            padding: const EdgeInsets.all(HandySpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c.fileName,
                  style: muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text.rich(
                  key: const Key('anki-count'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatFigure(context, '${p.cards.length}'),
                        style: theme.textTheme.headlineMedium,
                      ),
                      TextSpan(
                        text: tr(
                          context,
                          '  cards from ${p.notes} notes',
                          '  thẻ từ ${p.notes} ghi chú',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (ahead.isNotEmpty) ...[
                  const SizedBox(height: HandySpace.l),
                  Text(
                    tr(
                      context,
                      '${ahead.first} due today, ${ahead.skip(1).fold(0, (a, b) => a + b)} more in the next two weeks',
                      '${ahead.first} thẻ đến hạn hôm nay, thêm ${ahead.skip(1).fold(0, (a, b) => a + b)} thẻ trong hai tuần tới',
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: HandySpace.m),
                  ForecastStrip(days: ahead, today: now),
                ],
              ],
            ),
          ),
        ],
      ),
      if (c.blocked != null) ...[
        const SizedBox(height: HandySpace.l),
        HandyNotice(
          tr(
            context,
            '${errorText(context, c.blocked!)}. Your library has room for ${recallCardLimit - c.store.state!.cards.length} more cards and ${recallDeckLimit - c.store.state!.decks.length} more decks.',
            '${errorText(context, c.blocked!)}. Thư viện còn chỗ cho ${recallCardLimit - c.store.state!.cards.length} thẻ và ${recallDeckLimit - c.store.state!.decks.length} bộ thẻ.',
          ),
          key: const Key('anki-blocked'),
          tone: HandyTone.error,
        ),
      ],
      HandyLabel(tr(context, 'Schedule', 'Lịch ôn')),
      HandyGroup(
        children: [
          if (p.withHistory > 0)
            SwitchListTile(
              key: const Key('anki-keep-schedule'),
              value: c.keepSchedule,
              onChanged: busy || c.blocked != null ? null : c.setKeepSchedule,
              title: Text(
                tr(context, "Keep Anki's schedule", 'Giữ lịch ôn của Anki'),
              ),
              subtitle: Text(
                c.keepSchedule
                    ? tr(
                        context,
                        '${p.withHistory} reviewed cards keep their interval, ease and due day.${p.learning > 0 ? ' The ${p.learning} still in learning steps are due today.' : ''}',
                        '${p.withHistory} thẻ đã ôn giữ khoảng cách, độ dễ và ngày đến hạn.${p.learning > 0 ? ' ${p.learning} thẻ đang học dở đến hạn hôm nay.' : ''}',
                      )
                    : tr(
                        context,
                        'Every card starts new and is due today.',
                        'Mọi thẻ bắt đầu lại từ đầu và đến hạn hôm nay.',
                      ),
              ),
            )
          else
            ListTile(
              title: Text(
                tr(
                  context,
                  'No review history in this file: every card starts new.',
                  'File không có lịch sử ôn: mọi thẻ bắt đầu từ đầu.',
                ),
              ),
            ),
          if (p.suspended > 0)
            ListTile(
              title: Text(
                tr(
                  context,
                  '${p.suspended} cards suspended in Anki come in as ordinary cards.',
                  '${p.suspended} thẻ bị tạm dừng trong Anki được thêm như thẻ thường.',
                ),
                style: muted,
              ),
            ),
        ],
      ),
    ];
    final second = <Widget>[
      HandyLabel(
        p.decks.length == 1
            ? tr(context, 'New deck', 'Bộ thẻ mới')
            : tr(
                context,
                '${p.decks.length} new decks',
                '${p.decks.length} bộ thẻ mới',
              ),
      ),
      HandyGroup(
        children: [
          for (final (i, d) in p.decks.take(12).indexed)
            row(
              d.name,
              d.cards,
              key: Key('anki-deck-$i'),
              hue: trial == null ? null : deckHue(trial.decks, c.trialDeck(i)),
            ),
          if (p.decks.length > 12)
            ListTile(
              title: Text(
                tr(
                  context,
                  'and ${p.decks.length - 12} more',
                  'và ${p.decks.length - 12} bộ nữa',
                ),
                style: muted,
              ),
            ),
        ],
      ),
      HandyLabel(tr(context, 'What comes in', 'Những gì được thêm')),
      HandyGroup(
        children: [
          row(
            tr(context, 'Basic cards', 'Thẻ thường'),
            p.count(AnkiKind.basic),
          ),
          row(
            tr(context, 'Reverse cards', 'Thẻ đảo chiều'),
            p.count(AnkiKind.reversed),
          ),
          row(
            tr(context, 'Cloze cards', 'Thẻ điền khuyết'),
            p.count(AnkiKind.cloze),
          ),
          row(tr(context, 'Pictures', 'Ảnh'), p.imagesKept),
        ],
      ),
      if (left.isNotEmpty) ...[
        HandyLabel(tr(context, 'Left out', 'Không được thêm')),
        HandyNotice(
          left.join('\n'),
          key: const Key('anki-left-out'),
          tone: HandyTone.warning,
        ),
      ],
      HandyLabel(tr(context, 'First cards', 'Vài thẻ đầu')),
      HandyGroup(
        children: [
          for (final card in p.cards.take(3))
            ListTile(
              title: Text(
                card.cloze > 0
                    ? clozeText(card.front, card.cloze, revealed: false)
                    : card.reversed
                    ? card.back
                    : card.front,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                card.cloze > 0
                    ? clozeText(card.front, card.cloze, revealed: true)
                    : card.reversed
                    ? card.front
                    : card.back,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.muted),
              ),
              trailing: card.image == null
                  ? null
                  : Icon(Icons.image_outlined, color: colors.muted),
            ),
        ],
      ),
    ];
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    // Wide screens: the answer and its choice on the left, as Today does,
    // the detail beside it, so all of it is on the first screen.
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 900
          ? column([...first, ...second])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 440, child: column(first)),
                const SizedBox(width: HandySpace.xl),
                Expanded(child: column(second)),
              ],
            ),
    );
  }
}
