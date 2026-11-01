import 'package:handy_ui/kit.dart';
import 'image_desk.dart';

/// What the fix made: the first picture, a line per picture of a batch,
/// and saving or sharing it. Nothing is kept until it is saved.
class ImageResult extends StatelessWidget {
  final ImageDesk d;
  final bool busy;
  final VoidCallback onSave;
  const ImageResult({
    super.key,
    required this.d,
    required this.busy,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final done = d.outputs.isNotEmpty || d.status.isNotEmpty;
    return HandyReveal(
      child: !done
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: HandyGroup(
                color: c.select,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(HandySpace.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          d.outputs.length == 1
                              ? tr(context, 'Ready to save', 'Sẵn sàng để lưu')
                              : tr(
                                  context,
                                  '${d.outputs.length} of ${d.sources.length} pictures ready',
                                  '${d.outputs.length}/${d.sources.length} ảnh sẵn sàng',
                                ),
                          key: const Key('media-result-title'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: c.selectInk,
                          ),
                        ),
                        if (d.failed > 0)
                          for (final s in d.status.where(
                            (s) => !s.endsWith(': ok'),
                          ))
                            Text(
                              s,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.selectInk,
                              ),
                            ),
                        if (d.outputs.isNotEmpty) ...[
                          const SizedBox(height: HandySpace.m),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Image.memory(
                              d.outputs.first.bytes,
                              key: const Key('media-output-preview'),
                              fit: BoxFit.contain,
                              cacheWidth: 800,
                              semanticLabel: d.outputs.first.name,
                            ),
                          ),
                          const SizedBox(height: HandySpace.m),
                          Row(
                            children: [
                              FilledButton.icon(
                                key: const Key('media-export'),
                                onPressed: busy ? null : onSave,
                                icon: const Icon(Icons.save_alt),
                                label: Text(
                                  d.outputs.length == 1
                                      ? tr(context, 'Save picture', 'Lưu ảnh')
                                      : tr(
                                          context,
                                          'Save as ZIP',
                                          'Lưu thành ZIP',
                                        ),
                                ),
                              ),
                              const SizedBox(width: HandySpace.s),
                              HandyShareButton(
                                name: d.fileName,
                                mimeType: d.fileMime,
                                bytes: busy ? null : () => d.file().bytes,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
