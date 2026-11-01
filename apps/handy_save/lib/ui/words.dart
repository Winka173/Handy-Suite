import 'dart:typed_data';
import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';

/// A source's name in words, never its logo.
String sourceName(String platform) => switch (platform) {
  'youtube' => 'YouTube',
  'tiktok' => 'TikTok',
  'facebook' => 'Facebook',
  'instagram' => 'Instagram',
  'threads' => 'Threads',
  'x' => 'X',
  'reddit' => 'Reddit',
  'linkedin' => 'LinkedIn',
  'pinterest' => 'Pinterest',
  'github' => 'GitHub',
  'stackoverflow' => 'Stack Overflow',
  'spotify' => 'Spotify',
  'soundcloud' => 'SoundCloud',
  'podcast' => 'Podcast',
  'vimeo' => 'Vimeo',
  'maps' => 'Maps',
  _ => '',
};

String kindName(BuildContext c, String type) => switch (type) {
  'video' => tr(c, 'Video', 'Video'),
  'post' => tr(c, 'Post', 'Bài đăng'),
  'image' => tr(c, 'Image', 'Ảnh'),
  'audio' => tr(c, 'Audio', 'Âm thanh'),
  'playlist' => tr(c, 'Playlist', 'Danh sách phát'),
  'shopping' => tr(c, 'Product', 'Sản phẩm'),
  'place' => tr(c, 'Place', 'Địa điểm'),
  'document' => tr(c, 'Document', 'Tài liệu'),
  'repository' => tr(c, 'Repository', 'Kho mã'),
  'question' => tr(c, 'Question', 'Câu hỏi'),
  'profile' => tr(c, 'Profile', 'Trang cá nhân'),
  'issue' => tr(c, 'Issue', 'Issue'),
  _ => tr(c, 'Link', 'Link'),
};

/// "YouTube · youtube.com", or just the domain for the open web.
String sourceLine(Bookmark b) {
  final name = sourceName(b.platform);
  final domain = b.sourceDomain.replaceFirst(RegExp(r'^www\.'), '');
  return name.isEmpty || name.toLowerCase() == domain.split('.').first
      ? (domain.isEmpty ? name : domain)
      : '$name · $domain';
}

/// How long ago, in a few words: "10 min", "3 h", "2 days", or the date.
String ago(BuildContext c, String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return tr(c, 'just now', 'vừa xong');
  if (d.inMinutes < 60)
    return tr(c, '${d.inMinutes} min ago', '${d.inMinutes} phút trước');
  if (d.inHours < 24)
    return tr(c, '${d.inHours} h ago', '${d.inHours} giờ trước');
  if (d.inDays < 7)
    return tr(c, '${d.inDays} days ago', '${d.inDays} ngày trước');
  return formatDay(c, iso.substring(0, 10));
}

/// The link's own picture when one was fetched or chosen; otherwise its
/// source's first letter on the app's pale tint.
class LinkThumb extends StatelessWidget {
  final SaveController controller;
  final Bookmark bookmark;
  final double size;
  final double? height;
  const LinkThumb(
    this.controller,
    this.bookmark, {
    super.key,
    this.size = 48,
    this.height,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final radius = BorderRadius.circular(HandyRadius.control);
    final h = height ?? size;
    final letter =
        (sourceName(bookmark.platform).isNotEmpty
                ? sourceName(bookmark.platform)
                : bookmark.title.isNotEmpty
                ? bookmark.title
                : bookmark.sourceDomain)
            .characters
            .first
            .toUpperCase();
    final fallback = Container(
      width: size,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.select, borderRadius: radius),
      child: ExcludeSemantics(
        child: Text(
          letter,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: c.selectInk,
            fontSize: (h < size ? h : size) * .42,
          ),
        ),
      ),
    );
    return FutureBuilder<Uint8List?>(
      future: controller.thumbnail(bookmark.id),
      builder: (context, snap) => snap.data == null
          ? fallback
          : ClipRRect(
              borderRadius: radius,
              child: Image.memory(
                snap.data!,
                width: size,
                height: h,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
