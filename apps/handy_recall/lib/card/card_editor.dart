import 'dart:convert';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../study/recall_store.dart' show CardDraft, newId;
import 'card_editor_body.dart';

/// Adds or edits one note: its card and, from the same text, its reverse
/// card or one card per cloze. Nothing leaves the form until [onCommit] has
/// written it; a failed write keeps every field. New cards can be saved one
/// after another without leaving.
class CardEditor extends StatefulWidget {
  final RecallCard? card;
  final String deckId;
  final HandyFiles files;
  final Future<void> Function(CardDraft) onCommit;

  /// Whether the note has (or, for a new card, starts with) a reverse card.
  final bool reverse;

  /// Cards made from the same note besides this one.
  final int siblings;

  /// Deletes the card after asking; true when it is gone.
  final Future<bool> Function(BuildContext)? onDelete;

  /// A new card's sides, handed over by another app.
  final String initialFront, initialBack;
  const CardEditor({
    this.initialFront = '',
    this.initialBack = '',
    this.onDelete,
    super.key,
    this.card,
    required this.deckId,
    required this.files,
    required this.onCommit,
    this.reverse = false,
    this.siblings = 0,
  });
  @override
  State<CardEditor> createState() => CardEditorState();
}

class CardEditorState extends State<CardEditor> {
  late final front = TextEditingController(
    text: widget.card?.front ?? widget.initialFront,
  );
  late final back = TextEditingController(
    text: widget.card?.back ?? widget.initialBack,
  );
  final frontFocus = FocusNode();
  late RecallImage? image = widget.card?.image;
  late bool reverse = widget.reverse;
  String error = '';
  int saved = 0;
  bool dirty = false, busy = false, allowPop = false, confirming = false;

  @override
  void dispose() {
    front.dispose();
    back.dispose();
    frontFocus.dispose();
    super.dispose();
  }

  void touch(VoidCallback change) => setState(() {
    change();
    dirty = true;
  });

  /// The cloze numbers the question holds now.
  List<int> get clozes => clozeNumbers(front.text);

  /// A picture with covers cannot also be asked the other way round.
  bool get canReverse =>
      clozes.isEmpty && (image == null || image!.masks.isEmpty);

  /// Turns the selected words of the question into the next cloze (or, with
  /// [same], into another blank of the last one) and keeps typing there.
  void wrapCloze({bool same = false}) {
    if (busy) return;
    final sel = front.selection;
    final start = sel.isValid ? sel.start : front.text.length;
    final end = sel.isValid ? sel.end : front.text.length;
    final r = makeCloze(front.text, start, end, same: same);
    touch(() {
      front.value = TextEditingValue(
        text: r.text,
        selection: TextSelection.collapsed(offset: r.cursor),
      );
    });
    frontFocus.requestFocus();
  }

  void leave() {
    setState(() {
      dirty = false;
      allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> importImage() async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final file = await widget.files.importBytes(
        extensions: ['png', 'jpg', 'jpeg'],
        maxBytes: recallImageMaxBytes,
      );
      if (file == null || !mounted) return;
      final b = file.bytes, png = b.length > 8 && b[0] == 137;
      final next = RecallImage.fromJson({
        'dataUri':
            'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(b)}',
        'masks': [
          {'x': 0.25, 'y': 0.25, 'width': 0.5, 'height': 0.25},
        ],
      });
      touch(() => image = next);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// The card as edited: a new card, or the old one with the same id and
  /// schedule. Its cloze number is one the text still asks.
  RecallCard edited() {
    final numbers = clozes, old = widget.card;
    final cloze = numbers.isEmpty
        ? 0
        : numbers.contains(old?.cloze)
        ? old!.cloze
        : numbers.first;
    if (old == null) {
      return createCard(
        id: newId(),
        deckId: widget.deckId,
        front: front.text,
        back: back.text,
        image: image,
        cloze: cloze,
      );
    }
    return old.copyWith({
      'front': front.text,
      'back': back.text,
      'image': image?.toJson(),
      'cloze': cloze == 0 ? null : cloze,
      'reversed': cloze == 0 && old.reversed,
    });
  }

  /// Writes the card. With [another], stays open and empty for the next one.
  Future<void> save({bool another = false}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.onCommit(
        CardDraft(
          edited(),
          original: widget.card,
          reverse: reverse && canReverse,
        ),
      );
      if (!mounted) return;
      if (!another) return leave();
      setState(() {
        saved++;
        dirty = false;
        front.clear();
        back.clear();
        image = null;
      });
      frontFocus.requestFocus();
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> askToLeave() async {
    if (busy || confirming) return;
    if (!dirty) return leave();
    confirming = true;
    final discard = await confirmHandy(
      context,
      title: tr(context, 'Discard changes?', 'Bỏ thay đổi?'),
      message: tr(
        context,
        'This card has not been saved.',
        'Thẻ này chưa được lưu.',
      ),
      confirmLabel: tr(context, 'Discard', 'Bỏ thay đổi'),
      cancelLabel: tr(context, 'Keep editing', 'Tiếp tục sửa'),
      destructive: true,
    );
    confirming = false;
    if (discard && mounted) leave();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) askToLeave();
    },
    child: CardEditorBody(editor: this),
  );
}
