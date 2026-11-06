import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'entitlements.dart';

/// A Pro way to draw the Focus card. It changes only how the card looks;
/// swipes, buttons, Undo and what Read, Later and Archive do stay as they
/// are.
class FocusSkin {
  final String id, en, vi, tagEn, tagVi;
  final Widget Function(BuildContext, SaveScope, Bookmark, Uint8List?) build;
  const FocusSkin({
    required this.id,
    required this.en,
    required this.vi,
    required this.tagEn,
    required this.tagVi,
    required this.build,
  });
}

final focusSkins = <FocusSkin>[
  FocusSkin(
    id: 'minimal',
    en: 'Minimal',
    vi: 'Tối giản',
    tagEn: 'The title large, the picture small, nothing else',
    tagVi: 'Tiêu đề lớn, ảnh nhỏ, không gì thêm',
    build: (c, s, b, pic) => _Minimal(scope: s, b: b, picture: pic),
  ),
  FocusSkin(
    id: 'film',
    en: 'Film',
    vi: 'Phim',
    tagEn: 'A frame of film on a dark strip',
    tagVi: 'Một khung phim trên dải tối',
    build: (c, s, b, pic) => _Film(scope: s, b: b, picture: pic),
  ),
  FocusSkin(
    id: 'editorial',
    en: 'Editorial',
    vi: 'Báo chí',
    tagEn: 'A headline, a rule, the picture and a standfirst',
    tagVi: 'Tít, đường kẻ, ảnh và câu dẫn',
    build: (c, s, b, pic) => _Editorial(scope: s, b: b, picture: pic),
  ),
  FocusSkin(
    id: 'nocturne',
    en: 'Nocturne',
    vi: 'Đêm sâu',
    tagEn: 'The picture full bleed at night, words in warm light',
    tagVi: 'Ảnh tràn nền đêm, chữ ánh ấm',
    build: (c, s, b, pic) => _Nocturne(scope: s, b: b, picture: pic),
  ),
];

FocusSkin? focusSkinById(Object? id) =>
    focusSkins.where((s) => s.id == id).firstOrNull;

String _title(BuildContext context, Bookmark b) => b.title.isNotEmpty
    ? b.title
    : b.isImage
    ? tr(context, 'Picture', 'Ảnh')
    : b.sourceDomain;

String _meta(BuildContext context, Bookmark b) =>
    '${b.isImage ? tr(context, 'Picture', 'Ảnh') : sourceLine(b)} · ${ago(context, b.savedAt)}';

Widget _picture(Bookmark b, Uint8List? bytes, {double radius = 0}) => ClipRRect(
  borderRadius: BorderRadius.circular(radius),
  child: bytes == null
      ? SourceFace(b)
      : Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
);

Widget _openText(
  BuildContext context,
  SaveScope scope,
  Bookmark b,
  Color ink,
) => TextButton.icon(
  key: const Key('focus-open'),
  style: TextButton.styleFrom(foregroundColor: ink, padding: EdgeInsets.zero),
  onPressed: () => scope.open(context, b),
  icon: Icon(b.hasUrl ? Icons.open_in_new : Icons.fullscreen, size: 18),
  label: Text(
    b.hasUrl
        ? tr(context, 'Open original', 'Mở bản gốc')
        : tr(context, 'View picture', 'Xem ảnh'),
  ),
);

class _Minimal extends StatelessWidget {
  final SaveScope scope;
  final Bookmark b;
  final Uint8List? picture;
  const _Minimal({required this.scope, required this.b, this.picture});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    return ColoredBox(
      color: p.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: _picture(b, picture, radius: 14),
            ),
            const SizedBox(height: 40),
            Semantics(
              header: true,
              child: Text(
                _title(context, b),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  height: 1.18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_meta(context, b), style: theme.textTheme.bodySmall),
            const SizedBox(height: 20),
            _openText(context, scope, b, p.primary),
          ],
        ),
      ),
    );
  }
}

class _Film extends StatelessWidget {
  final SaveScope scope;
  final Bookmark b;
  final Uint8List? picture;
  const _Film({required this.scope, required this.b, this.picture});
  @override
  Widget build(BuildContext context) {
    const film = Color(0xFF151210),
        light = Color(0xFFF3ECE0),
        dim = Color(0xFFBDB3A6);
    Widget holes() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < 9; i++)
          Container(
            width: 12,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE6DA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
    return ColoredBox(
      color: film,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          holes(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: _picture(b, picture, radius: 3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _title(context, b),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: light,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              _meta(context, b),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: dim, fontSize: 12.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _openText(context, scope, b, light),
            ),
          ),
          holes(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Editorial extends StatelessWidget {
  final SaveScope scope;
  final Bookmark b;
  final Uint8List? picture;
  const _Editorial({required this.scope, required this.b, this.picture});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final stand = (b.description ?? b.note).trim();
    return ColoredBox(
      color: p.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (b.isImage ? tr(context, 'Picture', 'Ảnh') : sourceLine(b))
                  .toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: p.muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(
                _title(context, b),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: bookmarkSerif(context, 28),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: p.ink, thickness: 1.5, height: 1.5),
            const SizedBox(height: 12),
            Expanded(child: _picture(b, picture, radius: 2)),
            if (stand.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                stand,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: bookmarkSerif(
                  context,
                  16,
                ).copyWith(color: p.muted, height: 1.35),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ago(context, b.savedAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                _openText(context, scope, b, p.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Nocturne extends StatelessWidget {
  final SaveScope scope;
  final Bookmark b;
  final Uint8List? picture;
  const _Nocturne({required this.scope, required this.b, this.picture});
  @override
  Widget build(BuildContext context) {
    const night = Color(0xFF0E1220),
        gold = Color(0xFFF0D59A),
        dim = Color(0xFFB9B6AE);
    return ColoredBox(
      color: night,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: .85, child: _picture(b, picture)),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x660E1220)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: const Color(0xD90E1220),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _title(context, b),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: bookmarkSerif(context, 26).copyWith(color: gold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _meta(context, b),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: dim, fontSize: 12.5),
                  ),
                  _openText(context, scope, b, gold),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card styles, each drawing the save now at the top of Focus; free
/// "Standard" applies at once, a Pro one with verified Pro.
Future<void> showFocusSkins(
  BuildContext context,
  SaveScope scope,
  Bookmark? sample,
  Future<Uint8List?>? picture,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) {
    final theme = Theme.of(sheet);
    final current = scope.c.preferences['focusSkin'];
    Future<void> set(String? id) async {
      if (id != null && !await requirePro(sheet, ProFeature.focusSkins)) return;
      final prefs = {...scope.c.preferences}..remove('focusSkin');
      await scope.c.update((l) => l, prefs: {...prefs, 'focusSkin': ?id});
      if (sheet.mounted) Navigator.pop(sheet);
    }

    final pro = hasPro(sheet);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * .8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              tr(sheet, 'Card style', 'Kiểu thẻ'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              tr(
                sheet,
                'Only how the card looks changes; swipes and buttons stay the same.',
                'Chỉ đổi cách thẻ trông; vuốt và các nút giữ nguyên.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            ListTile(
              key: const Key('skin-standard'),
              contentPadding: EdgeInsets.zero,
              title: Text(tr(sheet, 'Standard', 'Chuẩn')),
              subtitle: Text(tr(sheet, 'Free', 'Miễn phí')),
              trailing: focusSkinById(current) == null || !pro
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => set(null),
            ),
            if (sample != null)
              SizedBox(
                height: 330,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: focusSkins.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final s = focusSkins[i];
                    final on = s.id == current && pro;
                    return SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                BookmarkRadii.focus,
                              ),
                              child: IgnorePointer(
                                child: FittedBox(
                                  child: SizedBox(
                                    width: 330,
                                    height: 450,
                                    child: MediaQuery(
                                      data: MediaQuery.of(context).copyWith(
                                        textScaler: TextScaler.noScaling,
                                      ),
                                      child: FutureBuilder<Uint8List?>(
                                        future: picture,
                                        builder: (context, snap) => s.build(
                                          context,
                                          scope,
                                          sample,
                                          snap.data,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FilledButton.tonal(
                            key: Key('skin-${s.id}'),
                            onPressed: on ? null : () => set(s.id),
                            child: Text(
                              on
                                  ? tr(context, 'In use', 'Đang dùng')
                                  : '${tr(context, s.en, s.vi)}${pro ? '' : ' · Pro'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  },
);
