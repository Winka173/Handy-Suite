import 'dart:typed_data';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart';
import 'attachments.dart';
import 'editor_body.dart';

/// Adds or edits one item. Nothing leaves the form until [onCommit] has
/// written it; a failed write keeps every field for another try.
class AssetEditor extends StatefulWidget {
  final InventoryAsset? asset;
  final List<InventoryBox> boxes;
  final List<String> locations;
  final HandyFiles files;
  final ScanCamera? camera;
  final Map<String, Uint8List> blobs;
  final String initialName, initialBox;
  final Future<void> Function(AssetEdit) onCommit;
  const AssetEditor({
    super.key,
    required this.asset,
    required this.boxes,
    required this.files,
    required this.blobs,
    required this.onCommit,
    this.locations = const [],
    this.camera,
    this.initialName = '',
    this.initialBox = '',
  });
  @override
  State<AssetEditor> createState() => AssetEditorState();
}

class AssetEditorState extends State<AssetEditor> {
  late final Map<String, Uint8List> blobs = {...widget.blobs};
  late final a = widget.asset;
  late final name = TextEditingController(text: a?.name ?? widget.initialName);
  late final location = TextEditingController(text: a?.location ?? '');
  late final serial = TextEditingController(text: a?.serial ?? '');
  late final notes = TextEditingController(text: a?.notes ?? '');
  late final dates = {
    'purchasedOn': a?.purchasedOn ?? '',
    'warrantyUntil': a?.warrantyUntil ?? '',
    'maintenanceDue': a?.maintenanceDue ?? '',
  };
  late String boxId = a?.boxId ?? widget.initialBox;
  late String photo = a?.photoUri ?? '';
  late List<InventoryReceipt> receipts = [...?a?.receipts];
  String error = '';
  bool dirty = false, saving = false, importing = false;
  bool allowPop = false, confirming = false;
  bool get locked => importing || saving;

  @override
  void dispose() {
    for (final c in [name, location, serial, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void touch(VoidCallback change) => setState(() {
    change();
    dirty = true;
  });

  /// Brings in a photo (camera or file) or a receipt; refuses bad files.
  Future<void> attach({bool receipt = false, bool camera = false}) async {
    setState(() {
      importing = true;
      error = '';
    });
    try {
      if (receipt && receipts.length >= 20) {
        throw const FormatException('Up to 20 receipts / Tối đa 20 hóa đơn');
      }
      final file = camera
          ? await widget.camera!.capture()
          : await widget.files.importBytes(
              extensions: receipt
                  ? ['png', 'jpg', 'jpeg', 'pdf']
                  : ['png', 'jpg', 'jpeg'],
              maxBytes: attachmentBytes,
            );
      if (file == null || !mounted) return;
      final uri = acceptAttachment(file.bytes, receipt: receipt);
      touch(() {
        blobs[uri] = file.bytes;
        receipt
            ? receipts = [...receipts, receiptFor(file.name, uri)]
            : photo = uri;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final at = timestamp();
      final values = <String, Object?>{
        'name': name.text,
        'location': location.text,
        'serial': serial.text,
        'notes': notes.text,
        ...dates,
        'boxId': boxId,
        'photoUri': photo,
        'updatedAt': at,
        if (receipts.isNotEmpty || a?.receipts.isNotEmpty == true)
          'receipts': receipts.map((r) => r.toJson()).toList(),
      };
      final next = a == null
          ? createAsset(id: newId(), name: name.text, now: at, fields: values)
          : a!.copyWith(values);
      await widget.onCommit(AssetEdit(next, blobs));
      if (mounted) leave();
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
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

  Future<void> askToLeave() async {
    if (locked || confirming) return;
    if (!dirty) return leave();
    confirming = true;
    final discard = await confirmHandy(
      context,
      title: tr(context, 'Discard changes?', 'Bỏ thay đổi?'),
      message: tr(
        context,
        'What you typed here will be lost.',
        'Những gì vừa nhập sẽ mất.',
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
    canPop: allowPop || (!dirty && !locked),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) askToLeave();
    },
    child: EditorBody(editor: this),
  );
}
