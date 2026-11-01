import 'package:handy_ui/kit.dart';
import 'editor_controller.dart';

/// The step's heading and what the reader should do, under its picture.
/// A whole edit is one undo step.
class StepNotes extends StatefulWidget {
  final EditorController c;
  final bool busy;
  const StepNotes({super.key, required this.c, required this.busy});
  @override
  State<StepNotes> createState() => _StepNotesState();
}

class _StepNotesState extends State<StepNotes> {
  late final heading = TextEditingController(text: widget.c.step?.title);
  late final body = TextEditingController(text: widget.c.step?.body);
  bool marked = false;

  @override
  void dispose() {
    heading.dispose();
    body.dispose();
    super.dispose();
  }

  void changed() {
    final c = widget.c, step = c.step;
    if (step == null) return;
    if (!marked) c.checkpoint();
    marked = true;
    c.replaceStep(
      step.copyWith(title: heading.text, body: body.text),
      record: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.c.stepIndex + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('capture-step-title'),
          controller: heading,
          enabled: !widget.busy,
          maxLength: 200,
          onChanged: (_) => changed(),
          style: Theme.of(context).textTheme.titleMedium,
          decoration: InputDecoration(
            labelText: tr(context, 'Step $n', 'Bước $n'),
            counterText: '',
          ),
        ),
        const SizedBox(height: HandySpace.s),
        TextField(
          key: const Key('capture-step-body'),
          controller: body,
          enabled: !widget.busy,
          maxLength: 4000,
          minLines: 2,
          maxLines: 6,
          onChanged: (_) => changed(),
          decoration: InputDecoration(
            labelText: tr(context, 'What to do here', 'Cần làm gì ở bước này'),
            counterText: '',
          ),
        ),
      ],
    );
  }
}
