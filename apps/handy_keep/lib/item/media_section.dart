import 'package:handy_ui/kit.dart';
import 'asset_editor.dart';

/// The item's photo (camera on phones, a file everywhere) and its receipts.
class MediaSection extends StatelessWidget {
  final AssetEditorState editor;
  const MediaSection({super.key, required this.editor});

  @override
  Widget build(BuildContext context) {
    final e = editor;
    final camera = e.widget.camera?.supported ?? false;
    final c = HandyColors.of(context);
    final hasPhoto = e.photo.isNotEmpty && e.blobs[e.photo] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(tr(context, 'Photo and receipts', 'Ảnh và hóa đơn')),
        HandyGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Row(
                children: [
                  if (hasPhoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(HandyRadius.control),
                      child: Image.memory(
                        e.blobs[e.photo]!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        cacheWidth: 216,
                        semanticLabel: tr(context, 'Item photo', 'Ảnh món đồ'),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: c.select,
                        borderRadius: BorderRadius.circular(
                          HandyRadius.control,
                        ),
                      ),
                      child: Icon(Icons.photo_outlined, color: c.selectInk),
                    ),
                  const SizedBox(width: HandySpace.l),
                  Expanded(
                    child: Wrap(
                      spacing: HandySpace.s,
                      runSpacing: HandySpace.s,
                      children: [
                        if (camera)
                          OutlinedButton.icon(
                            key: const Key('photo-camera'),
                            onPressed: e.locked
                                ? null
                                : () => e.attach(camera: true),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(tr(context, 'Take photo', 'Chụp ảnh')),
                          ),
                        OutlinedButton.icon(
                          key: const Key('photo-file'),
                          onPressed: e.locked ? null : () => e.attach(),
                          icon: const Icon(Icons.image_outlined),
                          label: Text(
                            camera
                                ? tr(context, 'From files', 'Chọn từ máy')
                                : tr(context, 'Choose photo', 'Chọn ảnh'),
                          ),
                        ),
                        if (e.photo.isNotEmpty)
                          TextButton(
                            key: const Key('photo-remove'),
                            onPressed: e.locked
                                ? null
                                : () => e.touch(() => e.photo = ''),
                            child: Text(tr(context, 'Remove', 'Bỏ ảnh')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final r in e.receipts)
              ListTile(
                key: Key('receipt-${r.id}'),
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
                trailing: IconButton(
                  tooltip: tr(context, 'Remove ${r.name}', 'Bỏ ${r.name}'),
                  icon: const Icon(Icons.close),
                  onPressed: e.locked
                      ? null
                      : () => e.touch(
                          () => e.receipts = [
                            for (final x in e.receipts)
                              if (x.id != r.id) x,
                          ],
                        ),
                ),
              ),
            ListTile(
              key: const Key('receipt-add'),
              enabled: !e.locked,
              leading: const Icon(Icons.attach_file),
              title: Text(tr(context, 'Attach a receipt', 'Đính kèm hóa đơn')),
              subtitle: Text(
                tr(
                  context,
                  'PNG, JPEG or PDF, up to 4 MB',
                  'PNG, JPEG hoặc PDF, tối đa 4 MB',
                ),
              ),
              onTap: () => e.attach(receipt: true),
            ),
          ],
        ),
        if (e.importing) ...[
          const SizedBox(height: HandySpace.m),
          Text(
            tr(context, 'Waiting for the file…', 'Đang chờ tệp…'),
            style: TextStyle(color: c.muted),
          ),
        ],
      ],
    );
  }
}
