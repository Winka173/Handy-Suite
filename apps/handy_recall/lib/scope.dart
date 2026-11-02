import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import 'card_link.dart';
import 'card/card_editor.dart';
import 'deck/deck_settings.dart';
import 'study/recall_store.dart';
import 'study/speaker.dart';

/// What every Recall screen shares: the store, files, and the actions that
/// open editors, dialogs and the review.
class RecallScope {
  final RecallStore store;
  final HandyFiles files;
  final Speaker speaker;

  /// Automatic backups to a folder; null in tests that do not need them.
  final HandyAutoBackup? autoBackup;
  const RecallScope({
    required this.store,
    required this.files,
    required this.speaker,
    this.autoBackup,
  });

  RecallState get state => store.state!;
  DateTime get now => store.clock();

  Future<void> review(BuildContext context, [String? deckId]) =>
      Navigator.pushNamed(
        context,
        deckId == null ? '/review' : '/review/$deckId',
      );

  Future<void> openDeck(BuildContext context, String id) =>
      Navigator.pushNamed(context, '/deck/$id');

  /// Picks an Anki package and previews it; nothing is added until the
  /// preview's Import.
  Future<void> importAnki(BuildContext context) =>
      Navigator.pushNamed(context, '/import', arguments: true);

  /// Names a new deck or changes one: its name, whether new cards get a
  /// reverse card, and the read-aloud language of each side. The dialog
  /// stays until it is saved.
  Future<void> editDeck(BuildContext context, [RecallDeck? deck]) {
    final form = DeckForm(deck);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HandyCommitDialog(
        title: deck == null
            ? tr(context, 'New deck', 'Bộ thẻ mới')
            : tr(context, 'Deck settings', 'Cài đặt bộ thẻ'),
        saveLabel: tr(context, 'Save deck', 'Lưu bộ thẻ'),
        saveKey: const Key('deck-save'),
        onCommit: () => store.saveDeckRecord(form.deck(deck?.id ?? newId())),
        fields: (context, busy) => [
          DeckSettingsFields(form: form, speaker: speaker, busy: busy),
        ],
      ),
    );
  }

  /// A card handed over by another app: pick its deck (or start one),
  /// then the editor opens pre-filled.
  Future<void> addFromLink(BuildContext context, CardLink link) async {
    const fresh = '';
    final deckId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr(context, 'Add to which deck?', 'Thêm vào bộ nào?')),
        children: [
          for (final d in state.decks)
            SimpleDialogOption(
              key: Key('link-deck-${d.id}'),
              onPressed: () => Navigator.pop(context, d.id),
              child: Text(d.name),
            ),
          SimpleDialogOption(
            key: const Key('link-deck-new'),
            onPressed: () => Navigator.pop(context, fresh),
            child: Text(tr(context, 'A new deck: Saved', 'Bộ mới: Đã lưu')),
          ),
        ],
      ),
    );
    if (deckId == null || !context.mounted) return;
    var id = deckId;
    if (id == fresh) {
      id = newId();
      await store.saveDeckRecord(
        RecallDeck(id: id, name: tr(context, 'Saved', 'Đã lưu')),
      );
      if (!context.mounted) return;
    }
    await editCard(context, id, null, link);
  }

  /// Adds a card to [deckId] or edits [card].
  Future<void> editCard(
    BuildContext context,
    String deckId, [
    RecallCard? card,
    CardLink? link,
  ]) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: card == null,
      builder: (_) {
        final siblings = card == null
            ? const <RecallCard>[]
            : siblingsOf(state, card).where((c) => c.id != card.id).toList();
        final deck = state.decks.where((d) => d.id == deckId).firstOrNull;
        return CardEditor(
          card: card,
          deckId: deckId,
          initialFront: link?.front ?? '',
          initialBack: link?.back ?? '',
          files: files,
          reverse: card == null
              ? deck?.reverse ?? false
              : card.reversed || siblings.any((c) => c.reversed),
          siblings: siblings.length,
          onCommit: store.saveDraft,
          onDelete: card == null ? null : (c) => deleteCard(c, card),
        );
      },
    ),
  );

  Future<bool> deleteDeck(BuildContext context, RecallDeck deck) async {
    final count = state.cards.where((c) => c.deckId == deck.id).length;
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${deck.name}?', 'Xóa ${deck.name}?'),
      message: tr(
        context,
        '$count cards and their review history go with it.',
        '$count thẻ cùng lịch sử ôn sẽ bị xóa theo.',
      ),
      confirmLabel: tr(context, 'Delete deck', 'Xóa bộ thẻ'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return run(context, () => store.removeDeckRecord(deck.id));
  }

  /// Deletes a card, and with it every card made from the same note.
  Future<bool> deleteCard(BuildContext context, RecallCard card) async {
    final others = siblingsOf(state, card).length - 1;
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this card?', 'Xóa thẻ này?'),
      message: others == 0
          ? (card.front.isEmpty ? card.back : card.front)
          : tr(
              context,
              '${card.front}\n\nIts $others linked cards (reverse or other clozes) go too.',
              '${card.front}\n\n$others thẻ liên quan (thẻ đảo chiều hoặc ô điền khuyết khác) cũng bị xóa.',
            ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return run(context, () => store.removeNoteRecord(card));
  }

  Future<void> importCsv(BuildContext context, String deckId) =>
      run(context, () async {
        final file = await files.importText(maxBytes: 16000000);
        if (file == null) return;
        final n = await store.importCsv(file.text, deckId);
        if (context.mounted) {
          showHandyMessage(
            context,
            tr(context, '$n cards added.', 'Đã thêm $n thẻ.'),
          );
        }
      });

  Future<void> exportCsv(BuildContext context, RecallDeck deck) => run(
    context,
    () async {
      final uri = await files.exportText(
        '${deck.name}.csv',
        exportCardsCsv(state.cards.where((c) => c.deckId == deck.id).toList()),
      );
      if (uri != null && context.mounted) {
        showHandyMessage(
          context,
          tr(context, 'Cards saved as CSV.', 'Đã lưu thẻ thành CSV.'),
        );
      }
    },
  );

  /// Runs a write; on failure says why and that nothing changed.
  Future<bool> run(BuildContext context, Future<void> Function() task) async {
    try {
      await task();
      return true;
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            '${errorText(context, e)}. Nothing changed.',
            '${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
      }
      return false;
    }
  }
}
