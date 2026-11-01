import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../capture_draft.dart';
import 'editor_actions.dart';
import 'editor_bar.dart';
import 'editor_body.dart';
import 'editor_controller.dart';

/// Writing one guide: the steps as film, the picture to mark up, and the
/// chosen note's settings. Nothing reaches the library until Save; the
/// draft copy keeps every change meanwhile.
class CaptureEditor extends StatefulWidget {
  final PortableCapture initial;
  final HandyFiles files;
  final ScanCamera? camera;
  final CaptureDraft? draft;
  final bool restoredDraft;

  /// Opens the picture picker at once, for a guide just started.
  final bool pickFirst;
  final Future<void> Function(PortableCapture bundle) onCommit;
  const CaptureEditor({
    super.key,
    required this.initial,
    required this.files,
    this.camera,
    this.draft,
    this.restoredDraft = false,
    this.pickFirst = false,
    required this.onCommit,
  });
  @override
  State<CaptureEditor> createState() => CaptureEditorState();
}

class CaptureEditorState extends State<CaptureEditor> {
  late final c = EditorController(
    widget.initial,
    draft: widget.draft,
    restored: widget.restoredDraft,
  );
  late final ScanCamera camera = widget.camera ?? SystemScanCamera();
  bool busy = false, closing = false;
  CancellationToken? token;
  String progress = '';

  @override
  void initState() {
    super.initState();
    if (widget.pickFirst && c.project.steps.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) addFiles();
      });
    }
  }

  @override
  void dispose() {
    token?.cancel();
    c.dispose();
    super.dispose();
  }

  /// One thing at a time; a failure says so and changes nothing.
  Future<void> run(Future<void> Function() task) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
    } on Cancelled {
      if (mounted) say(tr(context, 'Export canceled', 'Đã hủy xuất'));
    } catch (e) {
      if (mounted) {
        say(
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'The editor draft was preserved.', 'Bản nháp vẫn được giữ.')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          token = null;
          progress = '';
        });
      }
    }
  }

  /// A cancel button for the work about to start.
  CancellationToken track() {
    final t = CancellationToken();
    setState(() => token = t);
    return t;
  }

  void showProgress(String text) => setState(() => progress = text);

  void say(String message) => showHandyMessage(context, message);

  void close() {
    setState(() => closing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || busy) return KeyEventResult.ignored;
    // Typing belongs to the text field.
    final typing =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null;
    final k = HardwareKeyboard.instance;
    final mod = k.isControlPressed || k.isMetaPressed;
    final key = e.logicalKey;
    if (mod && key == LogicalKeyboardKey.keyS) {
      save();
    } else if (typing) {
      return KeyEventResult.ignored;
    } else if (mod && key == LogicalKeyboardKey.keyZ) {
      c.history(!k.isShiftPressed);
    } else if (mod && key == LogicalKeyboardKey.keyY) {
      c.history(false);
    } else if (key == LogicalKeyboardKey.delete && c.layer != null) {
      c.removeLayer();
    } else if (key == LogicalKeyboardKey.escape && c.tool != null) {
      c.pick(null);
    } else if (key == LogicalKeyboardKey.escape && c.layer != null) {
      c.select(null);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([c, c.zoom]),
    builder: (context, _) => PopScope(
      canPop: closing,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) leave();
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _key,
        child: Scaffold(
          appBar: EditorBar(state: this),
          bottomNavigationBar: token == null
              ? null
              : HandyBottomBar(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(progress),
                            const SizedBox(height: HandySpace.xs),
                            const LinearProgressIndicator(),
                          ],
                        ),
                      ),
                      const SizedBox(width: HandySpace.m),
                      TextButton(
                        key: const Key('guide-export-cancel'),
                        onPressed: token?.cancel,
                        child: Text(tr(context, 'Cancel', 'Hủy')),
                      ),
                    ],
                  ),
                ),
          body: EditorBody(state: this),
        ),
      ),
    ),
  );
}
