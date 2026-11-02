import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../platform/media.dart';
import '../../ui/form.dart';
import 'photo_proposal.dart';

class AttachmentSelection {
  bool busy = false;
  final List<String> existing;
  final List<PreparedAsset> added = [];
  AttachmentSelection(Iterable<String> ids) : existing = ids.toList();
  List<String> get ids => [...existing, ...added.map((p) => p.asset.key)];
  TripState apply(TripState s) {
    if (busy) throw StateError('Wait for attachment import to finish');
    for (final p in added) s = addPreparedAsset(s, p);
    return s;
  }
}

class AttachmentChooser extends StatefulWidget {
  final TripScope scope;
  final AttachmentSelection selection;
  final bool imagesOnly;
  final int maxCount;
  const AttachmentChooser({
    super.key,
    required this.scope,
    required this.selection,
    this.imagesOnly = false,
    this.maxCount = 500,
  });
  @override
  State<AttachmentChooser> createState() => _ChooserState();
}

class _ChooserState extends State<AttachmentChooser> {
  bool busy = false;
  String? error;
  bool dragging = false;
  Future<void> add(Future<List<ImportedBytes>> Function() get) async {
    if (busy) return;
    setState(() {
      busy = true;
      widget.selection.busy = true;
      error = null;
    });
    try {
      final files = await get();
      if (widget.selection.ids.length + files.length > widget.maxCount)
        throw const FormatException('Too many attachments');
      final staged = <PreparedAsset>[];
      for (final f in files) {
        final p = await prepareImported(f);
        if (widget.imagesOnly && p.asset.mime == 'application/pdf')
          throw const FormatException('Choose images for this field');
        staged.add(p);
      }
      if (mounted) setState(() => widget.selection.added.addAll(staged));
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Import failed. Use valid JPEG/PNG/WebP up to 16 MP / 12 MB or PDF up to 12 MB. Originals preserved.',
            'Nhập thất bại. Dùng JPEG/PNG/WebP tối đa 16 MP / 12 MB hoặc PDF tối đa 12 MB. Giữ nguyên bản gốc.',
          ),
        );
    } finally {
      widget.selection.busy = false;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragEntered: (_) => setState(() => dragging = true),
    onDragExited: (_) => setState(() => dragging = false),
    onDragDone: (details) => add(() async {
      final result = <ImportedBytes>[];
      var total = 0;
      for (final f in details.files) {
        final file = await widget.scope.camera.read(f);
        total += file.bytes.length;
        if (total > 30000000) throw const FormatException('Drop exceeds 30 MB');
        result.add(file);
      }
      return result;
    }),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            context,
            'Attachments — originals kept; previews resized',
            'Đính kèm — giữ bản gốc; thu nhỏ ảnh xem trước',
          ),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (dragging)
          Text(
            tr(
              context,
              'Drop to import a managed copy',
              'Thả để nhập bản sao do app quản lý',
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => add(() async {
                      final f = await widget.scope.files.importBytes(
                        extensions: widget.imagesOnly
                            ? ['jpg', 'jpeg', 'png', 'webp']
                            : ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                        maxBytes: 12000000,
                      );
                      return f == null ? [] : [f];
                    }),
              icon: const Icon(Icons.attach_file),
              label: Text(
                tr(context, 'Files / drop here', 'Tệp / thả vào đây'),
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => add(widget.scope.camera.gallery),
              child: Text(tr(context, 'Gallery', 'Thư viện ảnh')),
            ),
            if (widget.scope.camera.supported)
              TextButton(
                onPressed: busy
                    ? null
                    : () => add(() async {
                        final f = await widget.scope.camera.capture();
                        return f == null ? [] : [f];
                      }),
                child: Text(tr(context, 'Camera', 'Máy ảnh')),
              ),
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        for (final key in widget.selection.existing.toList())
          Builder(
            builder: (context) {
              final asset = widget.scope.state.assets.firstWhere(
                (a) => a.key == key,
              );
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(asset.text('name')),
                subtitle: Text('${asset.size} bytes'),
                leading: asset.mime.startsWith('image/')
                    ? SizedBox(
                        width: 48,
                        height: 48,
                        child: Image.memory(
                          widget.scope.state.files[asset.data['preview'] ??
                              asset.path]!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                trailing: IconButton(
                  tooltip: tr(
                    context,
                    'Detach managed copy',
                    'Gỡ bản sao trong app',
                  ),
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => widget.selection.existing.remove(key),
                        ),
                  icon: const Icon(Icons.close),
                ),
              );
            },
          ),
        for (final p in widget.selection.added.toList())
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.asset.text('name')),
            subtitle: Text(
              tr(
                context,
                'Staged until Save; cancel keeps gallery untouched',
                'Chỉ lưu khi bấm Lưu; hủy không đổi thư viện',
              ),
            ),
            trailing: IconButton(
              tooltip: tr(context, 'Remove staged file', 'Gỡ tệp đang chọn'),
              onPressed: busy
                  ? null
                  : () => setState(() => widget.selection.added.remove(p)),
              icon: const Icon(Icons.close),
            ),
          ),
      ],
    ),
  );
}

Future<void> showAsset(
  BuildContext context,
  TripScope scope,
  String key, {
  List<String>? album,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => _AssetView(scope, key, album ?? [key]),
  ),
);

class _AssetView extends StatefulWidget {
  final TripScope scope;
  final String keyId;
  final List<String> album;
  const _AssetView(this.scope, this.keyId, this.album);
  @override
  State<_AssetView> createState() => _AssetState();
}

class _AssetState extends State<_AssetView> {
  bool original = false;
  late String current = widget.keyId;
  @override
  Widget build(BuildContext context) {
    final a = widget.scope.state.assets.firstWhere((a) => a.key == current),
        bytes = widget
            .scope
            .state
            .files[original ? a.path : a.data['preview'] ?? a.path]!;
    final available = {
      for (final a in widget.scope.state.assets)
        if (a.mime.startsWith('image/')) a.key: a,
    };
    final images = [
      for (final id in widget.album.toSet())
        if (available[id] != null) available[id]!,
    ];
    final index = images.indexWhere((v) => v.key == current);
    void move(int step) => setState(() {
      current = images[index + step].key;
      original = false;
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(a.text('name')),
        actions: [
          if (a.mime.startsWith('image/'))
            IconButton(
              tooltip: tr(
                context,
                'Review photo metadata suggestions',
                'Kiểm tra gợi ý metadata ảnh',
              ),
              icon: const Icon(Icons.photo_camera_back_outlined),
              onPressed: () => widget.scope.run(
                context,
                () => showPhotoProposal(context, widget.scope, a.key),
              ),
            ),
          IconButton(
            tooltip: tr(context, 'Edit caption', 'Sửa chú thích'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => widget.scope.run(context, () async {
              await tripForm(
                context,
                tr(context, 'Photo caption', 'Chú thích ảnh'),
                [
                  const TripField(
                    'caption',
                    'Private caption',
                    'Chú thích riêng tư',
                    kind: 'note',
                    optional: true,
                  ),
                ],
                {'caption': a.text('caption')},
                (v) async {
                  await widget.scope.controller.change(
                    (s) => s.put('assets', a.copy({'caption': v['caption']})),
                  );
                },
              );
              if (mounted) setState(() {});
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (index >= 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: tr(context, 'Previous photo', 'Ảnh trước'),
                  onPressed: index > 0 ? () => move(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${index + 1} / ${images.length}'),
                IconButton(
                  tooltip: tr(context, 'Next photo', 'Ảnh sau'),
                  onPressed: index + 1 < images.length ? () => move(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          if (a.text('caption').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(a.text('caption')),
            ),
          if (a.mime.startsWith('image/'))
            SwitchListTile(
              title: Text(
                tr(
                  context,
                  'Show original (may contain EXIF/GPS)',
                  'Xem bản gốc (có thể chứa EXIF/GPS)',
                ),
              ),
              value: original,
              onChanged: (v) => setState(() => original = v),
            ),
          Expanded(
            child: a.mime.startsWith('image/')
                ? InteractiveViewer(
                    child: Center(
                      child: Image.memory(
                        bytes,
                        errorBuilder: (_, e, st) => Text(
                          tr(
                            context,
                            'Image cannot be decoded; original remains saved',
                            'Không đọc được ảnh; bản gốc vẫn được giữ',
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      tr(
                        context,
                        'PDF attachment. Save a private copy to view in your PDF reader.',
                        'Tệp PDF đính kèm. Lưu bản sao riêng tư để xem bằng trình đọc PDF.',
                      ),
                    ),
                  ),
          ),
          TextButton(
            onPressed: () => widget.scope.run(context, () async {
              await widget.scope.files.exportBytes(
                a.text('name'),
                Uint8List.fromList(widget.scope.state.files[a.path]!),
                mimeType: a.mime,
              );
            }),
            child: Text(
              tr(context, 'Save original private copy', 'Lưu bản gốc riêng tư'),
            ),
          ),
        ],
      ),
    );
  }
}
