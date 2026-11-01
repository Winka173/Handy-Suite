import 'package:handy_files/handy_files.dart';
import 'package:handy_files/share.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui/words.dart';

import 'labels/dossier_section.dart';
import 'labels/label_card.dart';

export 'labels/open_label.dart';

/// The label as it will look on the box or the item, the QR file to print,
/// and (for an item) its record, shared only after it has been read.
class InventoryLabelPage extends StatefulWidget {
  final InventoryLabel label;
  final KeepState inventory;
  final HandyFiles files;
  const InventoryLabelPage({
    super.key,
    required this.label,
    required this.inventory,
    required this.files,
  });
  @override
  State<InventoryLabelPage> createState() => _InventoryLabelPageState();
}

class _InventoryLabelPageState extends State<InventoryLabelPage> {
  late final record = widget.label.resolve(widget.inventory);
  late final png = qrPng(widget.label.url);
  final card = GlobalKey();
  bool busy = false;
  String error = '', notice = '';

  InventoryAsset? get item =>
      record is InventoryAsset ? record as InventoryAsset : null;
  String get dossier => itemDossier(item!, widget.inventory);

  Future<void> export(bool record, {bool printable = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = notice = '';
    });
    try {
      final uri = record
          ? await widget.files.exportText(
              'handy-keep-${widget.label.id}.txt',
              dossier,
            )
          : await widget.files.exportBytes(
              'handy-keep-${widget.label.kind}-${widget.label.id}${printable ? '-label' : ''}.png',
              printable ? await renderLabel(card) : png,
              mimeType: 'image/png',
            );
      if (mounted) {
        setState(
          () => notice = uri == null
              ? tr(context, 'Export canceled', 'Đã hủy xuất')
              : tr(context, 'File exported', 'Đã xuất file'),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = tr(
            context,
            'Export failed. The record was preserved.',
            'Xuất thất bại. Hồ sơ được giữ nguyên.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = record is InventoryBox ? record as InventoryBox : null;
    final name = item?.name ?? box!.name;
    final detail = box != null
        ? [
            if (box.location.isNotEmpty) box.location,
            itemCount(context, assetsInBox(widget.inventory, box.id).length),
          ].join(' · ')
        : whereNow(context, item!, widget.inventory);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(context, 'QR label', 'Nhãn QR'))),
        body: ListView(
          padding: const EdgeInsets.all(HandySpace.l),
          children: [
            HandyContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RepaintBoundary(
                    key: card,
                    child: LabelCard(
                      png: png,
                      kind: box != null
                          ? tr(context, 'Box', 'Thùng')
                          : tr(context, 'Item', 'Đồ dùng'),
                      name: name,
                      detail: detail,
                    ),
                  ),
                  const SizedBox(height: HandySpace.l),
                  Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        key: const Key('keep-label-export'),
                        onPressed: busy ? null : () => export(false),
                        icon: const Icon(Icons.download_outlined),
                        label: Text(
                          tr(context, 'Save QR image', 'Lưu ảnh mã QR'),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('keep-label-card-export'),
                        onPressed: busy
                            ? null
                            : () => export(false, printable: true),
                        icon: const Icon(Icons.print_outlined),
                        label: Text(
                          tr(context, 'Save label to print', 'Lưu nhãn để in'),
                        ),
                      ),
                      ShareOutputButton(
                        enabled: !busy,
                        name: 'handy-keep-label.png',
                        mimeType: 'image/png',
                        bytes: () => png,
                      ),
                    ],
                  ),
                  HandyReveal(
                    child: notice.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: HandySpace.m),
                            child: HandySwap(
                              child: HandyNotice(notice, key: ValueKey(notice)),
                            ),
                          ),
                  ),
                  HandyReveal(
                    child: error.isEmpty
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: HandySpace.m),
                            child: HandySwap(
                              child: HandyNotice(
                                error,
                                tone: HandyTone.error,
                                key: ValueKey(error),
                              ),
                            ),
                          ),
                  ),
                  if (item != null)
                    DossierSection(
                      text: dossier,
                      id: widget.label.id,
                      busy: busy,
                      onExport: () => export(true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
