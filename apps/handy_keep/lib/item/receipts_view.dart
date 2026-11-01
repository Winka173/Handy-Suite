import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_pdf/preview.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

/// The item's receipts: open to look, save a copy for a warranty claim.
class ReceiptsView extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset item;
  const ReceiptsView({super.key, required this.scope, required this.item});

  void open(BuildContext context, InventoryReceipt r) {
    final bytes = scope.store.library!.blobs[r.uri];
    if (bytes == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => r.mime == 'application/pdf'
            ? LocalPdfPreview(bytes: bytes, title: r.name)
            : Scaffold(
                appBar: AppBar(title: Text(r.name)),
                body: InteractiveViewer(
                  child: Center(
                    child: Image.memory(bytes, semanticLabel: r.name),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> save(BuildContext context, InventoryReceipt r) async {
    final bytes = scope.store.library!.blobs[r.uri];
    if (bytes == null) return;
    try {
      final uri = await scope.files.exportBytes(
        r.name,
        bytes,
        mimeType: r.mime,
      );
      if (uri != null && context.mounted) {
        showHandyMessage(
          context,
          tr(context, 'Copy saved.', 'Đã lưu một bản.'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        showHandyMessage(
          context,
          tr(context, 'Could not save the copy.', 'Chưa lưu được bản sao.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Receipts', 'Hóa đơn')),
        HandyGroup(
          children: [
            for (final r in item.receipts)
              ListTile(
                key: Key('receipt-open-${r.id}'),
                leading: Icon(
                  r.mime == 'application/pdf'
                      ? Icons.picture_as_pdf_outlined
                      : Icons.receipt_long_outlined,
                  color: c.muted,
                ),
                title: Text(
                  r.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => open(context, r),
                trailing: IconButton(
                  tooltip: tr(context, 'Save a copy', 'Lưu một bản'),
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () => save(context, r),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
