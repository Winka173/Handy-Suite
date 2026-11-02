import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:handy_files/handy_files.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'receipt_logic.dart';

const receiptExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

/// Files from the picker (several where the platform allows) or one photo
/// from the camera. Null when the person backed out.
Future<List<ImportedBytes>?> pickReceiptFiles(
  SpendScope scope, {
  bool camera = false,
}) async {
  if (camera) {
    final shot = await scope.camera.capture();
    return shot == null ? null : [shot];
  }
  final files = scope.files;
  if (files is BatchHandyFiles) {
    final many = await (files as BatchHandyFiles).importManyBytes(
      extensions: receiptExtensions,
      maxFiles: receiptsPerEntry,
      maxEachBytes: receiptFileLimit,
      maxTotalBytes: receiptTotalLimit,
    );
    return many.isEmpty ? null : many;
  }
  final one = await files.importBytes(
    extensions: receiptExtensions,
    maxBytes: receiptFileLimit,
  );
  return one == null ? null : [one];
}

/// A receipt at thumbnail size: the photo itself, or a page mark for a
/// PDF. Its name is the accessible label.
class ReceiptThumb extends StatelessWidget {
  final SpendScope scope;
  final Receipt receipt;
  final Uint8List? bytes;
  final double size;
  final bool dimmed;
  const ReceiptThumb({
    super.key,
    required this.scope,
    required this.receipt,
    this.bytes,
    this.size = 72,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    Widget page() => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.picture_as_pdf_outlined, color: c.muted),
        const SizedBox(height: 2),
        Text('PDF', style: theme.textTheme.labelSmall),
      ],
    );
    Widget picture(Uint8List b) => Image.memory(
      b,
      fit: BoxFit.cover,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) =>
          Icon(Icons.broken_image_outlined, color: c.muted),
    );
    final inside = !receipt.image
        ? page()
        : bytes != null
        ? picture(bytes!)
        : FutureBuilder<Uint8List?>(
            future: scope.controller.receiptBytes(receipt.id),
            builder: (context, snap) => snap.data != null
                ? picture(snap.data!)
                : snap.connectionState == ConnectionState.done
                ? Icon(Icons.broken_image_outlined, color: c.muted)
                : const SizedBox.shrink(),
          );
    return Semantics(
      label: receipt.name,
      image: receipt.image,
      child: Opacity(
        opacity: dimmed ? .35 : 1,
        child: Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(HandyRadius.control),
            border: Border.all(color: c.border),
          ),
          child: inside,
        ),
      ),
    );
  }
}

/// The receipts of the entry being edited: kept ones, ones waiting for
/// Save, ones marked to go on Save (with Keep), and the way to add more.
class ReceiptStrip extends StatelessWidget {
  final SpendScope scope;
  final List<Receipt> kept;
  final List<PendingReceipt> waiting;
  final Set<String> removing;
  final bool enabled;
  final void Function({bool camera}) onAdd;
  final void Function(Receipt r, Uint8List? bytes) onOpen;
  final ValueChanged<String> onRemove, onKeep;
  const ReceiptStrip({
    super.key,
    required this.scope,
    required this.kept,
    required this.waiting,
    required this.removing,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
    required this.onKeep,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final count = kept.length - removing.length + waiting.length;
    final full = count >= receiptsPerEntry;
    final camera = scope.camera.supported;
    Widget tile(Receipt r, Uint8List? bytes) {
      final going = removing.contains(r.id);
      return SizedBox(
        width: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  key: Key('receipt-${r.id}'),
                  borderRadius: BorderRadius.circular(HandyRadius.control),
                  onTap: going ? null : () => onOpen(r, bytes),
                  child: ReceiptThumb(
                    scope: scope,
                    receipt: r,
                    bytes: bytes,
                    dimmed: going,
                  ),
                ),
                Positioned(
                  top: -10,
                  right: 0,
                  child: going
                      ? const SizedBox.shrink()
                      : IconButton(
                          key: Key('receipt-remove-${r.id}'),
                          tooltip: tr(
                            context,
                            'Remove ${r.name}',
                            'Bỏ ${r.name}',
                          ),
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(color: c.border),
                          ),
                          iconSize: 16,
                          onPressed: enabled ? () => onRemove(r.id) : null,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (going)
              TextButton(
                key: Key('receipt-keep-${r.id}'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 32),
                ),
                onPressed: enabled ? () => onKeep(r.id) : null,
                child: Text(tr(context, 'Keep', 'Giữ lại')),
              )
            else
              Text(
                bytes != null
                    ? tr(context, 'New', 'Mới')
                    : fileSize(r.size, vi: vi),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
          ],
        ),
      );
    }

    final add = full
        ? null
        : camera
        ? PopupMenuButton<bool>(
            key: const Key('receipt-add'),
            enabled: enabled,
            tooltip: tr(context, 'Add a receipt', 'Thêm hóa đơn'),
            position: PopupMenuPosition.under,
            onSelected: (camera) => onAdd(camera: camera),
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('receipt-camera'),
                value: true,
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.photo_camera_outlined, size: 18, color: c.muted),
                    const SizedBox(width: HandySpace.m),
                    Text(tr(context, 'Take a photo', 'Chụp ảnh')),
                  ],
                ),
              ),
              PopupMenuItem(
                key: const Key('receipt-file'),
                value: false,
                height: 44,
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 18, color: c.muted),
                    const SizedBox(width: HandySpace.m),
                    Text(tr(context, 'Choose a file', 'Chọn file')),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HandySpace.m,
                vertical: HandySpace.s,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.attach_file,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: HandySpace.xs),
                  Text(
                    tr(context, 'Add', 'Thêm'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? tr(context, 'Receipts', 'Hóa đơn')
                    : tr(context, 'Receipts · $count', 'Hóa đơn · $count'),
                style: theme.textTheme.labelLarge,
              ),
            ),
            if (add != null)
              add
            else if (!full)
              TextButton.icon(
                key: const Key('receipt-add'),
                onPressed: enabled ? () => onAdd() : null,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(tr(context, 'Add', 'Thêm')),
              ),
          ],
        ),
        if (count > 0 || removing.isNotEmpty) ...[
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final r in kept) tile(r, null),
              for (final p in waiting) tile(p.receipt, p.bytes),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.xs),
          child: Text(
            full
                ? tr(
                    context,
                    'Ten receipts is the most one entry keeps.',
                    'Mỗi giao dịch giữ tối đa 10 hóa đơn.',
                  )
                : tr(
                    context,
                    'Photo or PDF, up to 10 MB each. Kept on this device and in ZIP backups.',
                    'Ảnh hoặc PDF, tối đa 10 MB mỗi file. Lưu trên máy này và trong bản sao lưu ZIP.',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ),
      ],
    );
  }
}

/// Opens a kept receipt full screen (`/receipt/<id>`), or previews one
/// that is not saved yet from [bytes].
Future<void> openReceipt(
  BuildContext context,
  SpendScope scope,
  Receipt r, {
  Uint8List? bytes,
}) => bytes == null
    ? Navigator.pushNamed(context, '/receipt/${r.id}')
    : Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              ReceiptPage(scope: scope, id: r.id, pending: (r, bytes)),
        ),
      );

/// One receipt as large as the screen allows: pinch to zoom a photo; a PDF
/// opens in another app through the share sheet or is saved as a copy.
/// Delete takes it off its entry at once, with Undo.
class ReceiptPage extends StatelessWidget {
  final SpendScope scope;
  final String id;
  final (Receipt, Uint8List)? pending;
  const ReceiptPage({
    super.key,
    required this.scope,
    required this.id,
    this.pending,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final r =
          pending?.$1 ??
          scope.state.receipts.where((r) => r.id == id).firstOrNull;
      if (r == null) {
        return HandyPage(
          title: tr(context, 'Receipt', 'Hóa đơn'),
          children: [
            HandyEmpty(
              title: tr(
                context,
                'This receipt is no longer kept',
                'Hóa đơn này không còn',
              ),
            ),
          ],
        );
      }
      return FutureBuilder<Uint8List?>(
        future: pending != null
            ? Future.value(pending!.$2)
            : scope.controller.receiptBytes(r.id),
        builder: (context, snap) => _ReceiptBody(
          scope: scope,
          receipt: r,
          snap: snap,
          saved: pending == null,
        ),
      );
    },
  );
}

class _ReceiptBody extends StatelessWidget {
  final SpendScope scope;
  final Receipt receipt;
  final AsyncSnapshot<Uint8List?> snap;
  final bool saved;
  const _ReceiptBody({
    required this.scope,
    required this.receipt,
    required this.snap,
    required this.saved,
  });

  Future<void> _copy(BuildContext context, Uint8List bytes) async {
    try {
      final done = await scope.files.exportBytes(
        receipt.name,
        bytes,
        mimeType: receipt.mime,
      );
      if (done != null && context.mounted)
        showHandyMessage(
          context,
          kIsWeb
              ? tr(
                  context,
                  'Download requested; check the saved file.',
                  'Đã yêu cầu tải; hãy kiểm tra file đã lưu.',
                )
              : tr(context, 'Copy saved.', 'Đã lưu một bản.'),
        );
    } catch (e) {
      if (context.mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Not saved: ${errorText(context, e)}. The receipt is unchanged.',
            'Chưa lưu: ${errorText(context, e)}. Hóa đơn giữ nguyên.',
          ),
        );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await scope.write(
      context,
      () => scope.controller.change(
        (s) => s.copy({
          'receipts': [
            for (final r in s.receipts)
              if (r.id != receipt.id) r.toJson(),
          ],
        }),
        'delete_receipt',
      ),
      done: (c) => tr(c, 'Receipt removed.', 'Đã bỏ hóa đơn.'),
    );
    if (ok) navigator.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final entry = scope.state.entries
        .where((e) => e.id == receipt.entry)
        .firstOrNull;
    final bytes = snap.data;
    // Checked against its listed size, checksum and type before showing.
    final ready = bytes != null && receipt.matches(bytes);
    final about = [
      receipt.image ? tr(context, 'Photo', 'Ảnh') : 'PDF',
      fileSize(receipt.size, vi: vi),
      if (entry != null) ...[
        entryTitle(context, scope, entry),
        dayLabel(context, scope, reportDay(entry.when, scope.state.zone)),
      ],
    ].join(' · ');
    final Widget body;
    if (snap.connectionState != ConnectionState.done) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!ready) {
      body = Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: HandyNotice(
          tr(
            context,
            'The file for this receipt is missing or damaged. Restore a backup that has it.',
            'File của hóa đơn này bị thiếu hoặc hỏng. Hãy khôi phục bản sao lưu có nó.',
          ),
          tone: HandyTone.error,
        ),
      );
    } else if (receipt.image) {
      body = InteractiveViewer(
        key: const Key('receipt-zoom'),
        maxScale: 6,
        child: Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            semanticLabel: receipt.name,
            errorBuilder: (context, _, _) => Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: HandyNotice(
                tr(
                  context,
                  'This photo cannot be drawn here. Save a copy or share it to open it elsewhere.',
                  'Không hiển thị được ảnh này. Hãy lưu một bản hoặc chia sẻ để mở ở nơi khác.',
                ),
                tone: HandyTone.warning,
              ),
            ),
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(HandySpace.l),
        children: [
          HandyContent(
            child: HandyEmpty(
              title: receipt.name,
              message: tr(
                context,
                'PDF receipts open in another app: use Share to pick one, or save a copy.',
                'Hóa đơn PDF mở bằng ứng dụng khác: chọn Chia sẻ để mở, hoặc lưu một bản.',
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(receipt.name, overflow: TextOverflow.ellipsis),
            Text(
              about,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
        actions: [
          if (saved)
            IconButton(
              key: const Key('receipt-delete'),
              tooltip: tr(context, 'Remove receipt', 'Bỏ hóa đơn'),
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
            ),
          const SizedBox(width: HandySpace.xs),
        ],
      ),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: !ready
          ? null
          : HandyBottomBar(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('receipt-save-copy'),
                      onPressed: () => _copy(context, bytes),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(tr(context, 'Save a copy', 'Lưu một bản')),
                    ),
                  ),
                  if (localShareSupported) ...[
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      child: Builder(
                        builder: (context) => FilledButton.icon(
                          key: const Key('receipt-share'),
                          onPressed: () => shareFile(
                            context,
                            name: receipt.name,
                            mimeType: receipt.mime,
                            bytes: bytes,
                          ),
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: Text(
                            receipt.image
                                ? tr(context, 'Share', 'Chia sẻ')
                                : tr(context, 'Open with…', 'Mở bằng…'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
