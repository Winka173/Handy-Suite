import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
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

/// A link check's result in a word or two.
String linkStatusWords(BuildContext c, LinkCheck k) => switch (k.status) {
  'ok' => tr(c, 'Works', 'Mở được'),
  'moved' =>
    k.reason == 'home'
        ? tr(c, 'Moved to the home page', 'Chuyển về trang chủ')
        : tr(c, 'Moved', 'Đã chuyển'),
  'gone' => tr(c, 'Gone', 'Không còn'),
  _ => tr(c, 'Could not tell', 'Không xác định'),
};

/// Why a check could not tell, when there is a plain reason.
String linkReasonWords(BuildContext c, LinkCheck k) {
  final code = k.httpStatus;
  if (k.status == 'gone') {
    return tr(
      c,
      'The site says this page no longer exists.',
      'Trang web báo trang này không còn.',
    );
  }
  if (k.status == 'moved') {
    return k.reason == 'home'
        ? tr(
            c,
            'It now sends you to the site\'s home page; the page was probably removed.',
            'Giờ nó đưa về trang chủ; có lẽ trang đã bị gỡ.',
          )
        : tr(
            c,
            'The site moved it permanently to a new address.',
            'Trang web đã chuyển hẳn sang địa chỉ mới.',
          );
  }
  if (k.status == 'ok')
    return tr(c, 'The page answered normally.', 'Trang trả lời bình thường.');
  return switch (k.reason) {
    'timeout' => tr(
      c,
      'No answer in time. Try again later.',
      'Không trả lời kịp. Thử lại sau.',
    ),
    'unsafeUrl' || 'unsafeAddress' || 'unsafeRedirect' => tr(
      c,
      'It points to a private or unsafe address, so it was not opened.',
      'Nó trỏ tới địa chỉ riêng hoặc không an toàn nên không được mở.',
    ),
    'tooManyRedirects' => tr(
      c,
      'It redirects too many times.',
      'Nó chuyển hướng quá nhiều lần.',
    ),
    'networkUnavailable' => tr(
      c,
      'No connection, or the site could not be found.',
      'Không có mạng, hoặc không tìm thấy trang web.',
    ),
    'http' when code == 401 || code == 403 => tr(
      c,
      'The site refused or needs you to sign in. It may still work in the app.',
      'Trang web từ chối hoặc cần đăng nhập. Có thể vẫn mở được trong app.',
    ),
    'http' when code == 429 => tr(
      c,
      'The site asked to slow down. Try again later.',
      'Trang web yêu cầu chậm lại. Thử lại sau.',
    ),
    'http' when code != null && code >= 500 => tr(
      c,
      'The site had an error. Try again later.',
      'Trang web đang lỗi. Thử lại sau.',
    ),
    _ => tr(
      c,
      'The site gave an unusual answer.',
      'Trang web trả lời bất thường.',
    ),
  };
}

/// "Gone · 404 · 2 Nov" for a row's second line.
String linkCheckLine(BuildContext c, LinkCheck k) => [
  linkStatusWords(c, k),
  if (k.httpStatus != null && (k.status == 'gone' || k.status == 'unreachable'))
    '${k.httpStatus}',
  formatDay(
    c,
    DateTime.parse(k.checkedAt).toLocal().toIso8601String().substring(0, 10),
  ),
].join(' · ');
