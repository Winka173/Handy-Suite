import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../welcome/motion.dart';
import 'link_capture.dart';

/// The one Save button's sheet: type or paste a link, paste from the
/// clipboard, add several links at once, or add a picture. On phones it
/// also points to saving from other apps, which needs no sheet at all.
Future<void> showSaveSheet(
  BuildContext context,
  SaveScope scope, {
  required Future<void> Function({bool clipboard}) onAdd,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (sheet) {
    void close() => Navigator.of(sheet).pop();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        HandySpace.l,
        0,
        HandySpace.l,
        HandySpace.l + MediaQuery.viewInsetsOf(sheet).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('save-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinkCapture(
              scope: scope,
              onSaved: (_, saved) {
                close();
                Navigator.of(context).pushNamed('/bookmark/${saved.id}');
              },
            ),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                OutlinedButton.icon(
                  key: const Key('save-paste'),
                  onPressed: () {
                    close();
                    onAdd(clipboard: true);
                  },
                  icon: const Icon(Icons.content_paste),
                  label: Text(tr(sheet, 'Paste a link', 'Dán link')),
                ),
                OutlinedButton.icon(
                  key: const Key('save-add'),
                  onPressed: () {
                    close();
                    onAdd();
                  },
                  icon: const Icon(Icons.add_link),
                  label: Text(tr(sheet, 'Several links', 'Nhiều link')),
                ),
                OutlinedButton.icon(
                  key: const Key('save-photo'),
                  onPressed: () {
                    close();
                    scope.addPhoto(context);
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(tr(sheet, 'A picture', 'Ảnh')),
                ),
              ],
            ),
            if (canReceiveShares) ...[
              const SizedBox(height: HandySpace.l),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('save-how'),
                  onPressed: () {
                    close();
                    Navigator.of(context).pushNamed('/welcome');
                  },
                  child: Text(
                    tr(
                      sheet,
                      'Save from other apps with Share',
                      'Lưu từ app khác bằng nút Chia sẻ',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
);

/// The Save button that opens [showSaveSheet].
class SaveButton extends StatelessWidget {
  final SaveScope scope;
  final Future<void> Function({bool clipboard}) onAdd;
  final bool expand;
  const SaveButton({
    super.key,
    required this.scope,
    required this.onAdd,
    this.expand = false,
  });
  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      key: const Key('save-new'),
      onPressed: () => showSaveSheet(context, scope, onAdd: onAdd),
      icon: const Icon(Icons.add),
      label: Text(tr(context, 'Save', 'Lưu')),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
