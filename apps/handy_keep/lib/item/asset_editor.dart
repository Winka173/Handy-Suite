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

  /// From a purchase handed over by Handy Spend: shown, never saved unseen.
  final String initialPrice, initialPurchasedOn;

  /// The currency a new price starts in.
  final String currency;

  /// The person's collections, and the ones a new item starts in.
  final List<InventoryCollection> collections;
  final List<String> initialCollections;

  /// owned, ordered or wanted for a new item.
  final String initialStatus;
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
    this.initialPrice = '',
    this.initialPurchasedOn = '',
    this.currency = 'VND',
    this.collections = const [],
    this.initialCollections = const [],
    this.initialStatus = 'owned',
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
  late final price = TextEditingController(
    text: a?.price ?? widget.initialPrice,
  );
  late String currency = a?.currency.isNotEmpty == true
      ? a!.currency
      : widget.currency;
  late final dates = {
    'purchasedOn': a?.purchasedOn ?? widget.initialPurchasedOn,
    'warrantyUntil': a?.warrantyUntil ?? '',
    'maintenanceDue': a?.maintenanceDue ?? '',
  };
  late String boxId = a?.boxId ?? widget.initialBox;
  late String photo = a?.photoUri ?? '';
  late List<InventoryReceipt> receipts = [...?a?.receipts];
  late final Set<String> collectionIds = {
    ...?a?.collections,
    if (a == null) ...widget.initialCollections,
  };
  late String status = a?.status ?? widget.initialStatus;
  late String priority = a?.priority ?? '';
  late final collector = {
    for (final k in keepCollectorFields)
      k: TextEditingController(text: (a?.toJson()[k] as String?) ?? ''),
  };
  late final link = TextEditingController(text: a?.link ?? '');
  late final budget = TextEditingController(text: a?.budget ?? '');

  /// Own fields, including those a profile change hides: they are kept.
  late final own = <String, TextEditingController>{
    for (final e in (a?.fields ?? const <String, String>{}).entries)
      e.key: TextEditingController(text: e.value),
  };

  /// The rarer collector fields stay folded until asked for or filled.
  late bool moreCollector =
      [
        'variant',
        'edition',
        'condition',
      ].any((k) => collector[k]!.text.isNotEmpty) ||
      own.isNotEmpty;
  TextEditingController ownField(String key) =>
      own.putIfAbsent(key, TextEditingController.new);
  String error = '';
  bool dirty = false, saving = false, importing = false;
  bool allowPop = false, confirming = false;
  bool get locked => importing || saving;

  @override
  void dispose() {
    for (final c in [
      name,
      location,
      serial,
      notes,
      price,
      link,
      budget,
      ...collector.values,
      ...own.values,
    ]) {
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
      final paid = parsePrice(price.text, currency);
      final values = <String, Object?>{
        'price': paid,
        'currency': paid.isEmpty ? '' : currency,
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
        ...collectorValues(),
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

  /// The version-4 fields, written only when used or already there, so a
  /// household item saves exactly as before.
  Map<String, Object?> collectorValues() {
    final had = a?.toJson() ?? const <String, dynamic>{};
    final wish = status != 'owned';
    final spend = wish ? parsePrice(budget.text, currency) : '';
    final ownValues = {
      for (final e in own.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    return {
      if (collectionIds.isNotEmpty || had.containsKey('collections'))
        'collections': collectionIds.toList(),
      if (collectionIds.isNotEmpty && !had.containsKey('profile'))
        'profile': 'collectible',
      if (wish || had.containsKey('status')) 'status': status,
      if (wish || had.containsKey('priority')) 'priority': wish ? priority : '',
      if (wish || had.containsKey('link')) 'link': wish ? link.text : '',
      if (spend.isNotEmpty || had.containsKey('budget')) ...{
        'budget': spend,
        'budgetCurrency': spend.isEmpty ? '' : currency,
      },
      for (final e in collector.entries)
        if (e.value.text.trim().isNotEmpty || had.containsKey(e.key))
          e.key: e.value.text,
      if (ownValues.isNotEmpty || had.containsKey('fields'))
        'fields': ownValues,
    };
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
