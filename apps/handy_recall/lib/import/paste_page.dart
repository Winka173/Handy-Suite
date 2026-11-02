import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

Future<void> openPaste(
  BuildContext context,
  RecallScope scope,
  RecallDeck deck,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PastePage(scope: scope, deck: deck),
  ),
);

/// Notes pasted in, read as cards while they are typed: each card is shown
/// before anything is added, and Add puts them all in the deck at once.
class PastePage extends StatefulWidget {
  final RecallScope scope;
  final RecallDeck deck;
  const PastePage({super.key, required this.scope, required this.deck});
  @override
  State<PastePage> createState() => _PastePageState();
}

class _PastePageState extends State<PastePage> {
  final text = TextEditingController();

  /// Null reads the paste's own shape.
  PasteMode? mode;
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  PastedCards? read() {
    if (text.text.trim().isEmpty) return null;
    try {
      return cardsFromPaste(text.text, mode: mode);
    } on FormatException {
      return null;
    }
  }

  Future<void> add(PastedCards r) async {
    setState(() => busy = true);
    final ok = await widget.scope.run(context, () async {
      await widget.scope.store.importCsv(pastedCsv(r.cards), widget.deck.id);
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    showHandyMessage(
      context,
      tr(
        context,
        '${r.cards.length} cards added to ${widget.deck.name}.',
        'Đã thêm ${r.cards.length} thẻ vào ${widget.deck.name}.',
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final r = read();
    final shown = r?.mode ?? mode ?? PasteMode.pairs;
    return HandyPage(
      title: tr(context, 'Paste notes', 'Dán ghi chú'),
      subtitle: widget.deck.name,
      bottom: FilledButton(
        key: const Key('paste-add'),
        onPressed: busy || r == null || r.cards.isEmpty ? null : () => add(r),
        child: Text(
          r == null || r.cards.isEmpty
              ? tr(context, 'Add cards', 'Thêm thẻ')
              : tr(
                  context,
                  'Add ${r.cards.length} cards',
                  'Thêm ${r.cards.length} thẻ',
                ),
        ),
      ),
      children: [
        TextField(
          key: const Key('paste-text'),
          controller: text,
          autofocus: true,
          minLines: 6,
          maxLines: 14,
          enabled: !busy,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: tr(
              context,
              'Paris – France\nWater boils at [100] degrees.',
              'Paris – Pháp\nNước sôi ở [100] độ.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.xs),
          child: Text(
            tr(
              context,
              'One question – answer per line, or mark the words to remember with [brackets] or **bold**.',
              'Mỗi dòng một "câu hỏi – đáp án", hoặc đánh dấu chữ cần nhớ bằng [ngoặc vuông] hay **đậm**.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: HandySpace.l),
        SegmentedButton<PasteMode>(
          key: const Key('paste-mode'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: PasteMode.pairs,
              label: Text(tr(context, 'Question – answer', 'Hỏi – đáp')),
            ),
            ButtonSegment(
              value: PasteMode.cloze,
              label: Text(tr(context, 'Fill the blank', 'Điền khuyết')),
            ),
          ],
          selected: {shown},
          onSelectionChanged: (s) => setState(() => mode = s.first),
        ),
        HandyLabel(
          r == null
              ? tr(context, 'Cards', 'Thẻ')
              : [
                  tr(
                    context,
                    '${r.cards.length} cards',
                    '${r.cards.length} thẻ',
                  ),
                  if (r.skipped > 0)
                    tr(
                      context,
                      '${r.skipped} left out',
                      '${r.skipped} dòng bỏ qua',
                    ),
                ].join(' · '),
        ),
        if (r == null || r.cards.isEmpty)
          Text(
            r == null
                ? tr(
                    context,
                    'Cards appear here as you paste.',
                    'Thẻ hiện ở đây khi bạn dán vào.',
                  )
                : shown == PasteMode.pairs
                ? tr(
                    context,
                    'No line has a question and an answer yet.',
                    'Chưa dòng nào có cả câu hỏi và đáp án.',
                  )
                : tr(
                    context,
                    'No sentence has a marked word yet.',
                    'Chưa câu nào có chữ được đánh dấu.',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          )
        else
          HandyGroup(
            children: [
              for (final card in r.cards.take(50))
                ListTile(
                  title: Text.rich(_blanks(card.$1, c.accent)),
                  subtitle: card.$2.isEmpty ? null : Text(card.$2),
                ),
              if (r.cards.length > 50)
                ListTile(
                  title: Text(
                    tr(
                      context,
                      'and ${r.cards.length - 50} more',
                      'và ${r.cards.length - 50} thẻ nữa',
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A cloze front with its blanks set apart: the word to remember underlined.
TextSpan _blanks(String front, Color accent) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in RegExp(r'\{\{c\d+::(.*?)\}\}').allMatches(front)) {
    spans.add(TextSpan(text: front.substring(at, m.start)));
    spans.add(
      TextSpan(
        text: m[1],
        style: TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: accent,
          decorationThickness: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    at = m.end;
  }
  spans.add(TextSpan(text: front.substring(at)));
  return TextSpan(children: spans);
}
