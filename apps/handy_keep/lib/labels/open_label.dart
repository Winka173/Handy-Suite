import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_scan/handy_scan.dart';
import 'package:handy_ui/kit.dart';

/// Opens a Keep label by camera (Android, iOS) or by its pasted link. Only a
/// record on this device opens; nothing is fetched from anywhere.
class OpenInventoryLabel extends StatefulWidget {
  final KeepState inventory;
  const OpenInventoryLabel({super.key, required this.inventory});
  @override
  State<OpenInventoryLabel> createState() => _OpenInventoryLabelState();
}

class _OpenInventoryLabelState extends State<OpenInventoryLabel> {
  final input = TextEditingController();
  String error = '';

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void open() {
    try {
      final label = InventoryLabel.parse(input.text);
      label.resolve(widget.inventory);
      Navigator.pop(context, label);
    } on FormatException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> scan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (result == null || !mounted) return;
    input.text = result;
    open();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'Open a Keep label', 'Mở nhãn Keep')),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nativeQrScanningSupported) ...[
            FilledButton.icon(
              key: const Key('keep-label-scan'),
              onPressed: scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(tr(context, 'Scan with camera', 'Quét bằng camera')),
            ),
            const SizedBox(height: HandySpace.l),
          ],
          HandyField(
            label: tr(
              context,
              'Or paste the label link',
              'Hoặc dán liên kết trên nhãn',
            ),
            child: TextField(
              key: const Key('keep-label-input'),
              controller: input,
              maxLength: 300,
              autofocus: !nativeQrScanningSupported,
              decoration: const InputDecoration(
                hintText: 'handy-keep://box/…',
                counterText: '',
              ),
              onSubmitted: (_) => open(),
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: HandySpace.m),
            HandyNotice(error, tone: HandyTone.error),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Cancel', 'Hủy')),
      ),
      FilledButton.tonal(
        key: const Key('keep-label-open'),
        onPressed: open,
        child: Text(tr(context, 'Open', 'Mở')),
      ),
    ],
  );
}
