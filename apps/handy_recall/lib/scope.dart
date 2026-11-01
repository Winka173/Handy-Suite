import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import 'card/card_editor.dart';
import 'study/recall_store.dart';

/// What every Recall screen shares: the store, files, and the actions that
/// open editors, dialogs and the review.
class RecallScope {
  final RecallStore store;
  final HandyFiles files;
  const RecallScope({required this.store, required this.files});

  RecallState get state => store.state!;
  DateTime get now => store.clock();

  Future<void> review(BuildContext context, [String? deckId]) =>
      Navigator.pushNamed(
        context,
        deckId == null ? '/review' : '/review/$deckId',
      );

  Future<void> openDeck(BuildContext context, String id) =>
      Navigator.pushNamed(context, '/deck/$id');

  /// Names a new deck or renames one; the dialog stays until it is saved.
  Future<void> editDeck(BuildContext context, [RecallDeck? deck]) {
    final name = TextEditingController(text: deck?.name ?? '');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => HandyCommitDialog(
        title: deck == null
            ? tr(context, 'New deck', 'Bộ thẻ mới')
            : tr(context, 'Rename deck', 'Đổi tên bộ thẻ'),
        saveLabel: tr(context, 'Save deck', 'Lưu bộ thẻ'),
        saveKey: const Key('deck-save'),
        onCommit: () => store.saveDeckRecord(
          RecallDeck(id: deck?.id ?? newId(), name: name.text),
        ),
        fields: (context, busy) => [
          HandyField(
            label: tr(context, 'Deck name', 'Tên bộ thẻ'),
            child: TextField(
              key: const Key('deck-name'),
              controller: name,
              enabled: !busy,
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
        ],
      ),
    );
  }

  /// Adds a card to [deckId] or edits [card].
  Future<void> editCard(
    BuildContext context,
    String deckId, [
    RecallCard? card,
  ]) => Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: card == null,
      builder: (_) => CardEditor(
        card: card,
        deckId: deckId,
        files: files,
        onCommit: store.saveCardRecord,
        onDelete: card == null ? null : (c) => deleteCard(c, card),
      ),
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

  Future<bool> deleteCard(BuildContext context, RecallCard card) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this card?', 'Xóa thẻ này?'),
      message: card.front,
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return false;
    return run(context, () => store.removeCardRecord(card.id));
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
