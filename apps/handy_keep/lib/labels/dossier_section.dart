import 'dart:convert';
import 'package:handy_files/share.dart';
import 'package:handy_ui/kit.dart';

/// The item's record as text. Saving a copy is always there; sharing opens
/// only after the person has read it and ticked that they checked it.
class DossierSection extends StatefulWidget {
  final String text, id;
  final bool busy;
  final VoidCallback onExport;
  const DossierSection({
    super.key,
    required this.text,
    required this.id,
    required this.busy,
    required this.onExport,
  });
  @override
  State<DossierSection> createState() => _DossierSectionState();
}

class _DossierSectionState extends State<DossierSection> {
  bool reading = false, reviewed = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HandyLabel(tr(context, 'Item record', 'Hồ sơ món đồ')),
      HandyGroup(
        children: [
          ListTile(
            key: const Key('keep-dossier-open'),
            title: Text(tr(context, 'Review item record', 'Xem hồ sơ đồ vật')),
            trailing: AnimatedRotation(
              turns: reading ? .5 : 0,
              duration: HandyMotion.of(context, HandyMotion.short),
              child: const Icon(Icons.expand_more),
            ),
            onTap: () => setState(() => reading = !reading),
          ),
          HandyReveal(
            child: !reading
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(HandySpace.l),
                        child: SelectableText(widget.text),
                      ),
                      CheckboxListTile(
                        key: const Key('keep-dossier-review'),
                        value: reviewed,
                        title: Text(
                          tr(
                            context,
                            'I checked the serial, borrower and notes before sharing',
                            'Tôi đã kiểm tra serial, người mượn và ghi chú trước khi chia sẻ',
                          ),
                        ),
                        onChanged: widget.busy
                            ? null
                            : (v) => setState(() => reviewed = v ?? false),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                OutlinedButton(
                  key: const Key('keep-dossier-export'),
                  onPressed: widget.busy ? null : widget.onExport,
                  child: Text(tr(context, 'Save as text', 'Lưu thành văn bản')),
                ),
                if (reviewed)
                  ShareOutputButton(
                    key: const Key('keep-dossier-share'),
                    enabled: !widget.busy,
                    name: 'handy-keep-${widget.id}.txt',
                    mimeType: 'text/plain',
                    bytes: () => utf8.encode(widget.text),
                  ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}
