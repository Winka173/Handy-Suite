import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show AssetEdit;
import '../item/attachments.dart' show attachmentBytes;
import '../item/fields.dart';
import 'batch_draft.dart';

/// Several things at once: a photo each, a name typed under each photo, one
/// place or box for all of them, then one save. Closing keeps nothing.
class BatchAddPage extends StatefulWidget {
  final List<InventoryBox> boxes;
  final List<String> locations;
  final HandyFiles files;
  final ScanCamera? camera;
  final String initialBox;

  /// Writes every item in one go; throws to keep the page as it is.
  final Future<void> Function(List<AssetEdit>) onCommit;
  const BatchAddPage({
    super.key,
    required this.boxes,
    required this.files,
    required this.onCommit,
    this.locations = const [],
    this.camera,
    this.initialBox = '',
  });
  @override
  State<BatchAddPage> createState() => _BatchAddPageState();
}

class _BatchAddPageState extends State<BatchAddPage> {
  late final draft = BatchDraft(box: widget.initialBox)
    ..addListener(() => setState(() {}));
  String error = '';
  bool importing = false, saving = false, allowPop = false, confirming = false;
  bool get locked => importing || saving;
  bool get camera => widget.camera?.supported ?? false;

  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  Future<void> _bring(Future<void> Function() task) async {
    setState(() {
      importing = true;
      error = '';
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  /// Photos from files: several at once where the platform allows it.
  Future<void> choose() => _bring(() async {
    final files = widget.files;
    final picked = files is BatchHandyFiles
        ? await (files as BatchHandyFiles).importManyBytes(
            extensions: ['png', 'jpg', 'jpeg'],
            maxFiles: 100,
            maxEachBytes: 12000000,
          )
        : [
            ?await files.importBytes(
              extensions: ['png', 'jpg', 'jpeg'],
              maxBytes: attachmentBytes,
            ),
          ];
    if (mounted) draft.add(picked);
  });

  /// One photo after another until the camera is closed or the batch is full.
  Future<void> shoot() => _bring(() async {
    while (mounted && !draft.full) {
      final shot = await widget.camera!.capture();
      if (shot == null || !mounted) break;
      draft.add([shot]);
    }
  });

  Future<void> save() async {
    setState(() {
      saving = true;
      error = '';
    });
    try {
      final edits = draft.build();
      await widget.onCommit(edits);
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, edits.length);
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> askToLeave() async {
    if (locked || confirming) return;
    if (draft.isEmpty) return _leave();
    confirming = true;
    final n = draft.drafts.length;
    final discard = await confirmHandy(
      context,
      title: tr(
        context,
        n == 1 ? 'Discard this photo?' : 'Discard $n photos?',
        'Bỏ $n ảnh này?',
      ),
      message: tr(
        context,
        'Nothing has been saved yet.',
        'Chưa có món nào được lưu.',
      ),
      confirmLabel: tr(context, 'Discard', 'Bỏ'),
      cancelLabel: tr(context, 'Keep going', 'Tiếp tục'),
      destructive: true,
    );
    confirming = false;
    if (discard && mounted) _leave();
  }

  void _leave() {
    setState(() => allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = draft.drafts.length;
    final feedback = <Widget>[
      if (importing) ...[
        const SizedBox(height: HandySpace.m),
        Text(
          tr(context, 'Waiting for photos…', 'Đang chờ ảnh…'),
          style: TextStyle(color: HandyColors.of(context).muted),
        ),
      ],
      if (draft.rejected.isNotEmpty) ...[
        const SizedBox(height: HandySpace.l),
        HandyNotice(
          key: const Key('batch-rejected'),
          [
            tr(
              context,
              'Left out ${draft.rejected.length}:',
              'Đã bỏ qua ${draft.rejected.length} ảnh:',
            ),
            for (final r in draft.rejected)
              '${r.file}: ${errorText(context, r.error)}',
          ].join('\n'),
          tone: HandyTone.warning,
          action: IconButton(
            tooltip: tr(context, 'Dismiss', 'Ẩn'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: draft.dismissRejected,
          ),
        ),
      ],
      HandyReveal(
        child: error.isEmpty
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: HandySpace.l),
                child: HandyNotice(
                  error,
                  key: const Key('batch-error'),
                  tone: HandyTone.error,
                ),
              ),
      ),
    ];
    return PopScope(
      canPop: allowPop || (draft.isEmpty && !locked),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) askToLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('batch-close'),
            tooltip: tr(context, 'Close', 'Đóng'),
            icon: const Icon(Icons.close),
            onPressed: locked ? null : askToLeave,
          ),
          title: Text(tr(context, 'Add from photos', 'Thêm từ ảnh')),
        ),
        bottomNavigationBar: HandyBottomBar(
          child: FilledButton(
            key: const Key('batch-save'),
            onPressed: locked || n == 0 ? null : save,
            child: Text(
              n == 0
                  ? tr(context, 'Save items', 'Lưu các món')
                  : tr(
                      context,
                      n == 1 ? 'Save 1 item' : 'Save $n items',
                      'Lưu $n món',
                    ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(HandySpace.l),
          children: [
            HandyContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (saving) const LinearProgressIndicator(),
                  if (n == 0) ...[
                    _Start(camera: camera, locked: locked, state: this),
                    ...feedback,
                  ] else ...[
                    HandyLabel(
                      tr(context, n == 1 ? '1 photo' : '$n photos', '$n ảnh'),
                    ),
                    HandyGroup(
                      children: [
                        for (final (i, d) in draft.drafts.indexed)
                          _DraftRow(
                            key: ValueKey(d.uri),
                            index: i,
                            draft: d,
                            missing: draft.unnamed.contains(d),
                            enabled: !locked,
                            onRemove: () => draft.remove(d),
                          ),
                      ],
                    ),
                    const SizedBox(height: HandySpace.m),
                    _Bring(camera: camera, locked: locked, state: this),
                    // What was left out, and why a save failed, stay beside
                    // the photos instead of under the fold.
                    ...feedback,
                    // Naming is the job; where they all go comes after.
                    HandyLabel(
                      tr(context, 'For all of them', 'Chung cho tất cả'),
                    ),
                    _Shared(state: this),
                  ],
                  const SizedBox(height: HandySpace.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Before the first photo: what happens, and the two ways in.
class _Start extends StatelessWidget {
  final bool camera, locked;
  final _BatchAddPageState state;
  const _Start({
    required this.camera,
    required this.locked,
    required this.state,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: HandySpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'One photo per thing', 'Mỗi món một tấm ảnh'),
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'Each photo becomes an item. Name them, pick one place or box for all, and save them together. Up to ${BatchDraft.limit} at a time.',
              'Mỗi ảnh thành một món. Đặt tên, chọn chung một chỗ hoặc một thùng, rồi lưu tất cả một lần. Tối đa ${BatchDraft.limit} ảnh mỗi lần.',
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'PNG or JPEG, up to 4 MB each',
              'PNG hoặc JPEG, mỗi ảnh tối đa 4 MB',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.xl),
          _Bring(camera: camera, locked: locked, state: state, first: true),
        ],
      ),
    );
  }
}

/// The camera (phones) and the file picker (everywhere).
class _Bring extends StatelessWidget {
  final bool camera, locked, first;
  final _BatchAddPageState state;
  const _Bring({
    required this.camera,
    required this.locked,
    required this.state,
    this.first = false,
  });
  @override
  Widget build(BuildContext context) {
    final full = state.draft.full;
    if (full) {
      return Text(
        tr(
          context,
          'That is ${BatchDraft.limit}, the most for one batch. Save these first.',
          'Đã đủ ${BatchDraft.limit} ảnh cho một lần. Hãy lưu trước.',
        ),
        style: TextStyle(color: HandyColors.of(context).muted),
      );
    }
    return Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: [
        if (camera)
          OutlinedButton.icon(
            key: const Key('batch-camera'),
            onPressed: locked ? null : state.shoot,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(
              first
                  ? tr(context, 'Take photos', 'Chụp ảnh')
                  : tr(context, 'Take more', 'Chụp thêm'),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('batch-files'),
          onPressed: locked ? null : state.choose,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(
            first
                ? tr(context, 'Choose photos', 'Chọn ảnh')
                : tr(context, 'Choose more', 'Chọn thêm'),
          ),
        ),
      ],
    );
  }
}

/// One place or box for every item in the batch; both are optional.
class _Shared extends StatelessWidget {
  final _BatchAddPageState state;
  const _Shared({required this.state});
  @override
  Widget build(BuildContext context) {
    final d = state.draft;
    final w = state.widget;
    final locked = state.locked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyField(
          label: tr(context, 'All kept at', 'Tất cả cất ở'),
          child: LocationField(
            controller: d.location,
            known: w.locations,
            enabled: !locked,
            onChanged: () {},
          ),
        ),
        if (w.boxes.isNotEmpty)
          HandyField(
            label: tr(context, 'All packed in', 'Tất cả đóng trong'),
            child: DropdownButtonFormField<String>(
              key: const Key('batch-box'),
              initialValue: d.box,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(tr(context, 'No box', 'Không trong thùng')),
                ),
                for (final b in w.boxes)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
              onChanged: locked ? null : (v) => d.setBox(v ?? ''),
            ),
          ),
      ],
    );
  }
}

/// A photo and the name under which it will be saved.
class _DraftRow extends StatelessWidget {
  final int index;
  final DraftPhoto draft;
  final bool missing, enabled;
  final VoidCallback onRemove;
  const _DraftRow({
    super.key,
    required this.index,
    required this.draft,
    required this.missing,
    required this.enabled,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(HandySpace.m),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(HandyRadius.control),
          child: Image.memory(
            draft.bytes,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            cacheWidth: 192,
            errorBuilder: (_, _, _) => const SizedBox.square(
              dimension: 64,
              child: Icon(Icons.broken_image_outlined),
            ),
            semanticLabel: tr(
              context,
              'Photo ${index + 1}',
              'Ảnh ${index + 1}',
            ),
          ),
        ),
        const SizedBox(width: HandySpace.m),
        Expanded(
          child: TextField(
            key: Key('batch-name-$index'),
            controller: draft.name,
            enabled: enabled,
            autofocus: index == 0,
            maxLength: 200,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: tr(context, 'What is it?', 'Món gì?'),
              counterText: '',
              errorMaxLines: 2,
              errorText: missing
                  ? tr(context, 'Name it or remove it', 'Đặt tên hoặc bỏ ảnh')
                  : null,
            ),
          ),
        ),
        IconButton(
          key: Key('batch-remove-$index'),
          tooltip: tr(
            context,
            'Remove photo ${index + 1}',
            'Bỏ ảnh ${index + 1}',
          ),
          icon: const Icon(Icons.close),
          onPressed: enabled ? onRemove : null,
        ),
      ],
    ),
  );
}
