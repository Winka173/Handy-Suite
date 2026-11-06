import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../library/deep_matches.dart' show pictureTexts;
import 'entitlements.dart';

/// The most text kept for one picture.
const pictureTextLimit = 20000;

/// Reads the text in [b]'s picture on this device and keeps it with the
/// item on this device (the `ocrText` preference; not in backups, since
/// it can be read again). Uses what was read before when there is one.
/// Throws [OcrUnavailable] where the device cannot read text.
Future<String> readPictureText(SaveController c, Bookmark b) async {
  final known = pictureTexts(c)[b.id];
  if (known != null) return known;
  final m = b.media;
  if (m == null) return '';
  // The engines take PNG and JPEG; a WebP original reads from its preview.
  var bytes = m.mime == 'image/webp' ? null : await c.mediaOriginal(m.id);
  bytes ??= await c.mediaPreview(m.id);
  if (bytes == null) return '';
  final read = (await recognizeText(bytes)).text.trim();
  final text = read.length > pictureTextLimit
      ? read.substring(0, pictureTextLimit)
      : read;
  await c.update(
    (l) => l,
    prefs: {
      ...c.preferences,
      'ocrText': {...pictureTexts(c), b.id: text},
    },
  );
  return text;
}

/// Reads pictures one after another in the background, after they are
/// saved: a save never waits for it, and a picture that cannot be read is
/// skipped (it can be read later from the viewer).
class PictureTextQueue {
  PictureTextQueue._();
  static final _waiting = <String>[];
  static bool _running = false;

  static void add(SaveController c, Iterable<String> ids) {
    final known = pictureTexts(c);
    for (final id in ids) {
      if (!known.containsKey(id) && !_waiting.contains(id)) _waiting.add(id);
    }
    if (!_running) _run(c);
  }

  static Future<void> _run(SaveController c) async {
    _running = true;
    try {
      while (_waiting.isNotEmpty) {
        final id = _waiting.removeAt(0);
        final b = c.library?.bookmarks.where((x) => x.id == id).firstOrNull;
        if (b == null || !b.isImage) continue;
        try {
          await readPictureText(c, b);
        } on OcrUnavailable catch (e) {
          // No engine here (the web, or no language): stop trying.
          if (e.problem == OcrProblem.unsupportedPlatform) {
            _waiting.clear();
          }
        } catch (_) {
          // This picture could not be read; the others still are.
        }
      }
    } finally {
      _running = false;
    }
  }
}

/// The viewer's "Copy text": reads the picture's words on this device
/// (Pro) and shows them to select or copy.
Future<void> showPictureText(
  BuildContext context,
  SaveController c,
  Bookmark b,
) async {
  if (!await requirePro(context, ProFeature.ocrOffline) || !context.mounted)
    return;
  final reading = readPictureText(c, b);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final p = BookmarkPalette.of(sheet);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .8,
        ),
        child: FutureBuilder<String>(
          future: reading,
          builder: (sheet, snap) {
            final Widget body;
            if (snap.connectionState != ConnectionState.done) {
              body = Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          sheet,
                          'Reading the picture on this device…',
                          'Đang đọc ảnh trên máy này…',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            } else if (snap.hasError) {
              final e = snap.error;
              body = Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  e is OcrUnavailable &&
                          e.problem == OcrProblem.unsupportedPlatform
                      ? tr(
                          sheet,
                          'Reading text in pictures works in the Android, iOS and Windows apps.',
                          'Đọc chữ trong ảnh chạy trên app Android, iOS và Windows.',
                        )
                      : e is OcrUnavailable &&
                            e.problem == OcrProblem.languageMissing
                      ? tr(
                          sheet,
                          'Windows has no text-recognition language installed for this. Add one in Settings > Time & language > Language.',
                          'Windows chưa cài ngôn ngữ nhận dạng chữ. Thêm trong Cài đặt > Thời gian & ngôn ngữ > Ngôn ngữ.',
                        )
                      : tr(
                          sheet,
                          'The text could not be read from this picture.',
                          'Chưa đọc được chữ trong ảnh này.',
                        ),
                  key: const Key('picture-text-problem'),
                ),
              );
            } else if (snap.data!.isEmpty) {
              body = Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  tr(
                    sheet,
                    'No text was found in this picture.',
                    'Không thấy chữ nào trong ảnh này.',
                  ),
                  key: const Key('picture-text-none'),
                ),
              );
            } else {
              body = Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SelectableText(
                    snap.data!,
                    key: const Key('picture-text'),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }
            return Column(
              key: const Key('picture-text-sheet'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                sheet,
                                'Text in this picture',
                                'Chữ trong ảnh',
                              ),
                              style: theme.textTheme.titleLarge,
                            ),
                            Text(
                              tr(
                                sheet,
                                'Read on this device; check names and numbers.',
                                'Đọc trên máy này; hãy kiểm tra tên và số.',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (snap.data?.isNotEmpty == true)
                        TextButton.icon(
                          key: const Key('picture-text-copy'),
                          onPressed: () => copyToClipboard(sheet, snap.data!),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(tr(sheet, 'Copy', 'Chép')),
                        ),
                    ],
                  ),
                ),
                body,
              ],
            );
          },
        ),
      );
    },
  );
}
