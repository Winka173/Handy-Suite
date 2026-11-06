import 'dart:math' as math;
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// A library with nothing in it: the guide's three photos, loosely
/// stacked as if just dropped here, one line on how saving works, one
/// button, and the guide again for whoever skipped it.
class EmptyLibrary extends StatelessWidget {
  /// Saving a picture; a link goes in the Quick Save row above.
  final VoidCallback onPicture;
  const EmptyLibrary({super.key, required this.onPicture});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    Widget photo(String name, double turn, Offset at) => Positioned(
      left: at.dx,
      top: at.dy,
      child: Transform.rotate(
        angle: turn * math.pi / 180,
        child: Container(
          width: 112,
          height: 92,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A1C2627),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/welcome/$name.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(BookmarkRadii.collection),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 260,
              height: 128,
              child: Stack(
                children: [
                  photo('hoi-an', -8, const Offset(6, 18)),
                  photo('guitars', 7, const Offset(142, 14)),
                  photo('bun-cha', -2, const Offset(74, 26)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(
                context,
                'Save something worth keeping',
                'Lưu lại điều bạn thích',
              ),
              textAlign: TextAlign.center,
              style: bookmarkSerif(context, 26),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'Paste a link above. In TikTok, Facebook, YouTube or your browser: Share, then Handy Bookmark (under More if it is not listed).',
                'Dán link vào ô phía trên. Trong TikTok, Facebook, YouTube hay trình duyệt: bấm Chia sẻ rồi chọn Handy Bookmark (không thấy thì bấm Khác).',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 14),
            // Quiet ways only: the one Save is the row above.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const Key('empty-save'),
                  onPressed: onPicture,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(tr(context, 'Save a picture', 'Lưu một ảnh')),
                ),
                TextButton(
                  key: const Key('empty-guide'),
                  onPressed: () => Navigator.pushNamed(context, '/welcome'),
                  child: Text(
                    tr(context, 'See how saving works', 'Xem cách lưu'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
