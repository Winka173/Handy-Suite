import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'fill_controller.dart';
import 'page_canvas.dart';
import 'signature_pad.dart';
import 'signature_store.dart';

/// What can be put on a page: saved signatures (as ink on white), a new
/// one drawn or imported, a line of text, a date.
class FillTools extends StatelessWidget {
  final FillController fill;
  final SignatureStore signatures;
  final HandyFiles files;
  final bool busy;
  final Future<void> Function(Future<void> Function() task) run;

  /// Called after something was placed (a phone closes its sheet).
  final VoidCallback? onPlaced;
  const FillTools({
    super.key,
    required this.fill,
    required this.signatures,
    required this.files,
    required this.busy,
    required this.run,
    this.onPlaced,
  });

  Future<void> _place(Uint8List png) async {
    final picture = await signaturePicture(png);
    fill.addSignature(picture.png, picture.rgba, picture.width, picture.height);
    onPlaced?.call();
  }

  Future<void> _keepAndPlace(Uint8List png) async {
    final picture = await signaturePicture(png, maxEdge: 1200);
    // Kept first, so a full or failing store still lets this page be signed.
    try {
      if (!signatures.full && signatures.loaded) {
        await signatures.add(picture.png);
      }
    } finally {
      fill.addSignature(
        picture.png,
        picture.rgba,
        picture.width,
        picture.height,
      );
      onPlaced?.call();
    }
  }

  Future<void> _draw(BuildContext context) => run(() async {
    final png = await drawSignature(context);
    if (png != null) await _keepAndPlace(png);
  });

  Future<void> _import() => run(() async {
    final file = await files.importBytes(
      extensions: ['png'],
      maxBytes: 4000000,
    );
    if (file != null) await _keepAndPlace(file.bytes);
  });

  Future<void> _text(BuildContext context) async {
    final text = await _askText(context);
    if (text == null || text.trim().isEmpty) return;
    fill.addText(text.trim(), textAspect(text.trim()));
    onPlaced?.call();
  }

  Future<void> _date(BuildContext context) async {
    final iso = await pickHandyDate(context, '');
    if (iso == null || !context.mounted) return;
    final d = DateTime.parse(iso);
    final text = tr(
      context,
      '${d.month}/${d.day}/${d.year}',
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
    );
    fill.addText(text, textAspect(text), kind: MarkKind.date);
    onPlaced?.call();
  }

  Future<void> _delete(BuildContext context, SavedSignature s) => run(() async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete this signature?', 'Xóa chữ ký này?'),
      message: tr(
        context,
        'It is removed from this device. Pages already signed keep it.',
        'Chữ ký bị xóa khỏi máy. Các trang đã ký vẫn giữ.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (ok) await signatures.remove(s.id);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return ListenableBuilder(
      listenable: signatures,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(context, 'Signature', 'Chữ ký'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: HandySpace.s),
          if (signatures.error != null)
            HandyNotice(
              tr(
                context,
                'Saved signatures could not be read. They are kept as they were.',
                'Chưa đọc được chữ ký đã lưu. Dữ liệu vẫn giữ nguyên.',
              ),
              tone: HandyTone.warning,
            )
          else if (signatures.signatures.isEmpty)
            Text(
              tr(
                context,
                'Signatures you draw are kept on this device to sign again.',
                'Chữ ký bạn vẽ được giữ trên máy để ký lần sau.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          for (final s in signatures.signatures)
            Padding(
              padding: const EdgeInsets.only(bottom: HandySpace.s),
              child: _SignatureTile(
                signature: s,
                enabled: !busy,
                onPlace: () => run(() => _place(s.png)),
                onDelete: () => _delete(context, s),
              ),
            ),
          const SizedBox(height: HandySpace.xs),
          _Stack(
            children: [
              OutlinedButton.icon(
                key: const Key('fill-draw'),
                style: _left,
                onPressed: busy ? null : () => _draw(context),
                icon: const Icon(Icons.draw_outlined),
                label: Text(tr(context, 'Sign', 'Ký mới')),
              ),
              OutlinedButton.icon(
                key: const Key('fill-import'),
                style: _left,
                onPressed: busy ? null : _import,
                icon: const Icon(Icons.image_outlined),
                label: Text(tr(context, 'PNG picture', 'Ảnh PNG')),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.xl),
          Text(
            tr(context, 'Fill in', 'Điền'),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: HandySpace.s),
          _Stack(
            children: [
              OutlinedButton.icon(
                key: const Key('fill-text'),
                style: _left,
                onPressed: busy ? null : () => _text(context),
                icon: const Icon(Icons.text_fields),
                label: Text(tr(context, 'Text', 'Ô chữ')),
              ),
              OutlinedButton.icon(
                key: const Key('fill-date'),
                style: _left,
                onPressed: busy ? null : () => _date(context),
                icon: const Icon(Icons.event_outlined),
                label: Text(tr(context, 'Date', 'Ngày')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Only the alignment changes; shape and colours stay the kit's.
final _left = OutlinedButton.styleFrom(alignment: Alignment.centerLeft);

/// Buttons one under another, each as wide as the panel.
class _Stack extends StatelessWidget {
  final List<Widget> children;
  const _Stack({required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, c) in children.indexed) ...[
        if (i > 0) const SizedBox(height: HandySpace.s),
        c,
      ],
    ],
  );
}

class _SignatureTile extends StatelessWidget {
  final SavedSignature signature;
  final bool enabled;
  final VoidCallback onPlace, onDelete;
  const _SignatureTile({
    required this.signature,
    required this.enabled,
    required this.onPlace,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: tr(context, 'Place this signature', 'Đặt chữ ký này'),
            excludeSemantics: true,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: c.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('fill-signature-${signature.id}'),
                onTap: enabled ? onPlace : null,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HandySpace.m,
                      vertical: HandySpace.s,
                    ),
                    child: Image.memory(signature.png, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: Key('fill-signature-delete-${signature.id}'),
          tooltip: tr(context, 'Delete signature', 'Xóa chữ ký'),
          onPressed: enabled ? onDelete : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

Future<String?> _askText(BuildContext context) async {
  final text = TextEditingController();
  try {
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Text on the page', 'Chữ trên trang')),
        content: SizedBox(
          width: 360,
          child: TextField(
            key: const Key('fill-text-field'),
            controller: text,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: tr(context, 'One line', 'Một dòng'),
              hintText: tr(context, 'Name, ID number…', 'Họ tên, số CCCD…'),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('fill-text-apply'),
            onPressed: () => Navigator.pop(context, text.text),
            child: Text(tr(context, 'Place', 'Đặt')),
          ),
        ],
      ),
    );
    final value = await Navigator.of(context).push(route);
    // The field stays on screen until the dialog has faded out.
    await route.completed;
    return value;
  } finally {
    text.dispose();
  }
}
