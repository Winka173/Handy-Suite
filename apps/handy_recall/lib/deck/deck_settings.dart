import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../study/speaker.dart';

/// What the deck dialog edits, held outside it so the save reads it.
class DeckForm {
  final TextEditingController name;
  bool reverse;
  String speakFront, speakBack;
  DeckForm(RecallDeck? deck)
    : name = TextEditingController(text: deck?.name ?? ''),
      reverse = deck?.reverse ?? false,
      speakFront = deck?.speakFront ?? '',
      speakBack = deck?.speakBack ?? '';

  RecallDeck deck(String id) => RecallDeck(
    id: id,
    name: name.text,
    reverse: reverse,
    speakFront: speakFront,
    speakBack: speakBack,
  );
}

const _names = {
  'ar': ('Arabic', 'Tiếng Ả Rập'),
  'de': ('German', 'Tiếng Đức'),
  'en': ('English', 'Tiếng Anh'),
  'es': ('Spanish', 'Tiếng Tây Ban Nha'),
  'fr': ('French', 'Tiếng Pháp'),
  'hi': ('Hindi', 'Tiếng Hindi'),
  'id': ('Indonesian', 'Tiếng Indonesia'),
  'it': ('Italian', 'Tiếng Ý'),
  'ja': ('Japanese', 'Tiếng Nhật'),
  'ko': ('Korean', 'Tiếng Hàn'),
  'pt': ('Portuguese', 'Tiếng Bồ Đào Nha'),
  'ru': ('Russian', 'Tiếng Nga'),
  'th': ('Thai', 'Tiếng Thái'),
  'vi': ('Vietnamese', 'Tiếng Việt'),
  'zh': ('Chinese', 'Tiếng Trung'),
};

/// "Japanese · ja-JP", or the bare tag for a language without a name here.
String languageLabel(BuildContext context, String tag) {
  final n = _names[tag.split(RegExp('[-_]')).first.toLowerCase()];
  return n == null ? tag : '${tr(context, n.$1, n.$2)} · $tag';
}

/// The deck's name and how its cards are made and read: reverse cards by
/// default, and a read-aloud language for each side from the device's own
/// voices.
class DeckSettingsFields extends StatefulWidget {
  final DeckForm form;
  final Speaker speaker;
  final bool busy;
  const DeckSettingsFields({
    super.key,
    required this.form,
    required this.speaker,
    required this.busy,
  });
  @override
  State<DeckSettingsFields> createState() => _DeckSettingsFieldsState();
}

class _DeckSettingsFieldsState extends State<DeckSettingsFields> {
  late final Future<List<String>> voices = widget.speaker.languages();
  DeckForm get f => widget.form;

  Widget _language(
    BuildContext context,
    List<String> voices,
    String key,
    String label,
    String value,
    ValueChanged<String> set,
  ) {
    final items = [
      ...voices,
      if (value.isNotEmpty && matchLanguage(value, voices) == null) value,
    ];
    return HandyField(
      label: label,
      help: value.isNotEmpty && matchLanguage(value, voices) == null
          ? tr(
              context,
              'This device has no voice for $value.',
              'Máy này chưa có giọng đọc $value.',
            )
          : null,
      child: DropdownButtonFormField<String>(
        key: Key(key),
        initialValue: value,
        isExpanded: true,
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(tr(context, 'Not read aloud', 'Không đọc')),
          ),
          for (final v in items)
            DropdownMenuItem(
              value: v,
              child: Text(
                languageLabel(context, v),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: widget.busy ? null : (v) => setState(() => set(v ?? '')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HandyField(
          label: tr(context, 'Deck name', 'Tên bộ thẻ'),
          child: TextField(
            key: const Key('deck-name'),
            controller: f.name,
            enabled: !widget.busy,
            autofocus: true,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: tr(
                context,
                'Spanish verbs, Anatomy…',
                'Từ vựng N3, Giải phẫu…',
              ),
              counterText: '',
            ),
          ),
        ),
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            key: const Key('deck-reverse'),
            contentPadding: EdgeInsets.zero,
            value: f.reverse,
            onChanged: widget.busy
                ? null
                : (v) => setState(() => f.reverse = v),
            title: Text(
              tr(
                context,
                'New cards get a reverse card',
                'Thẻ mới có thêm thẻ đảo chiều',
              ),
            ),
            subtitle: Text(
              tr(
                context,
                'Each card can still turn it off.',
                'Từng thẻ vẫn tắt được.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ),
        ),
        const SizedBox(height: HandySpace.m),
        FutureBuilder<List<String>>(
          future: voices,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: HandySpace.m),
                child: Text(
                  tr(context, 'Looking for voices…', 'Đang tìm giọng đọc…'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
              );
            }
            final list = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isEmpty && f.speakFront.isEmpty && f.speakBack.isEmpty)
                  HandyNotice(
                    tr(
                      context,
                      'This device has no read-aloud voices. Add one in the system text-to-speech settings.',
                      'Máy này chưa có giọng đọc. Hãy thêm trong cài đặt chuyển văn bản thành giọng nói của hệ thống.',
                    ),
                    key: const Key('deck-no-voices'),
                  )
                else ...[
                  _language(
                    context,
                    list,
                    'deck-speak-front',
                    tr(context, 'Read the question in', 'Đọc câu hỏi bằng'),
                    f.speakFront,
                    (v) => f.speakFront = v,
                  ),
                  _language(
                    context,
                    list,
                    'deck-speak-back',
                    tr(context, 'Read the answer in', 'Đọc đáp án bằng'),
                    f.speakBack,
                    (v) => f.speakBack = v,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
