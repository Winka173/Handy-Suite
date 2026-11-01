import 'dart:convert';
import 'package:handy_files/handy_files.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../study/recall_store.dart' show newId;
import 'card_editor_body.dart';

/// Adds or edits one card. Nothing leaves the form until [onCommit] has
/// written it; a failed write keeps every field. New cards can be saved one
/// after another without leaving.
class CardEditor extends StatefulWidget {
  final RecallCard? card;
  final String deckId;
  final HandyFiles files;
  final Future<void> Function(RecallCard) onCommit;

  /// Deletes the card after asking; true when it is gone.
  final Future<bool> Function(BuildContext)? onDelete;
  const CardEditor({
    this.onDelete,
    super.key,
    this.card,
    required this.deckId,
    required this.files,
    required this.onCommit,
  });
  @override
  State<CardEditor> createState() => CardEditorState();
}

class CardEditorState extends State<CardEditor> {
  late final front = TextEditingController(text: widget.card?.front ?? '');
  late final back = TextEditingController(text: widget.card?.back ?? '');
  final frontFocus = FocusNode();
  late RecallImage? image = widget.card?.image;
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

  /// Writes the card. With [another], stays open and empty for the next one.
  Future<void> save({bool another = false}) async {
    setState(() {
      busy = true;
      error = '';
    });
    try {
      final card = widget.card == null
          ? createCard(
              id: newId(),
              deckId: widget.deckId,
              front: front.text,
              back: back.text,
              image: image,
            )
          : widget.card!.copyWith({
              'front': front.text,
              'back': back.text,
              'image': image?.toJson(),
            });
      await widget.onCommit(card);
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
