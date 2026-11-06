import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../services/metadata_types.dart' show readingMaxHtmlBytes;

/// The reader's frame while a text is on its way: flat bars where the
/// title and lines will be. With [host], the page is being read online, so
/// a strip above says from where and offers Cancel.
class ReaderLoading extends StatelessWidget {
  const ReaderLoading({super.key, this.host, this.onCancel});
  final String? host;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(bottom: HandySpace.m),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    final online = host != null;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.xl,
            HandySpace.l,
            HandySpace.xl,
          ),
          children: [
            if (online)
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('reader-fetching'),
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    HandySpace.m,
                    HandySpace.s,
                    HandySpace.m,
                  ),
                  margin: const EdgeInsets.only(bottom: HandySpace.xl),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(BookmarkRadii.item),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr(
                                    context,
                                    'Reading the page online…',
                                    'Đang đọc trang trực tuyến…',
                                  ),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  host!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: HandySpace.s),
                          OutlinedButton(
                            key: const Key('reader-cancel'),
                            onPressed: onCancel,
                            child: Text(tr(context, 'Cancel', 'Hủy')),
                          ),
                        ],
                      ),
                      const SizedBox(height: HandySpace.m),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: p.primary,
                          backgroundColor: p.tint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Semantics(
              label: online
                  ? null
                  : tr(context, 'Opening the copy', 'Đang mở bản đọc'),
              child: LayoutBuilder(
                builder: (context, box) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(box.maxWidth * .8, 28),
                    bar(box.maxWidth * .4, 14),
                    const SizedBox(height: HandySpace.l),
                    for (var i = 0; i < 7; i++)
                      bar(box.maxWidth * (i.isEven ? 1 : .9), 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why there is no text, in plain words, and what can be done instead.
class ReaderNotice extends StatelessWidget {
  const ReaderNotice({
    super.key,
    required this.problem,
    this.address = '',
    this.onOpenOriginal,
    this.onRetry,
  });

  /// See ReaderSession.problem.
  final String problem;

  /// The page's host, to say which page this is about.
  final String address;
  final VoidCallback? onOpenOriginal, onRetry;

  (String, String?) _words(BuildContext context) {
    final mb = readingMaxHtmlBytes ~/ (1024 * 1024);
    final couldNot = tr(
      context,
      'Couldn’t read this page',
      'Chưa đọc được trang này',
    );
    return switch (problem) {
      'deleted' => (
        tr(context, 'This item was deleted.', 'Mục này đã bị xóa.'),
        null,
      ),
      'picture' => (
        tr(
          context,
          'Pictures have no text to read.',
          'Ảnh không có chữ để đọc.',
        ),
        null,
      ),
      'notWeb' => (
        tr(
          context,
          'Only web pages can be read here.',
          'Chỉ đọc được trang web ở đây.',
        ),
        tr(
          context,
          'This address is not an http or https page. Open it in the app it belongs to.',
          'Địa chỉ này không phải trang http hoặc https. Hãy mở nó bằng app tương ứng.',
        ),
      ),
      'browser' => (
        tr(
          context,
          'Reading online isn’t available in the browser',
          'Trình duyệt chưa đọc trực tuyến được',
        ),
        tr(
          context,
          'A browser can’t guarantee which address is really contacted, so this web version fetches nothing. Open the original, or read it in Handy Bookmark on Android, iOS or Windows. Offline copies restored from a backup can be read here.',
          'Trình duyệt không bảo đảm được thật sự kết nối tới địa chỉ nào, nên bản web không tải gì. Hãy mở bản gốc, hoặc đọc bằng Handy Bookmark trên Android, iOS hay Windows. Bản đọc offline khôi phục từ bản sao lưu vẫn đọc được ở đây.',
        ),
      ),
      'cancelled' => (
        tr(context, 'Stopped', 'Đã dừng'),
        tr(context, 'Nothing more was fetched.', 'Không tải thêm gì nữa.'),
      ),
      'noText' => (
        couldNot,
        tr(
          context,
          'This page has no readable text to show (a video, an app page or a sign-in wall).',
          'Trang này không có chữ để hiện (video, trang app hoặc yêu cầu đăng nhập).',
        ),
      ),
      'httpStatus' => (
        couldNot,
        tr(
          context,
          'The site answered with an error instead of the page.',
          'Trang web trả về lỗi thay vì nội dung.',
        ),
      ),
      'unsupportedContentType' => (
        couldNot,
        tr(
          context,
          'This address is not a web page; it may be a file or a picture.',
          'Địa chỉ này không phải trang web; có thể là tệp hoặc ảnh.',
        ),
      ),
      'responseTooLarge' => (
        couldNot,
        tr(
          context,
          'The page is over $mb MB, too large to read here.',
          'Trang lớn hơn $mb MB, quá lớn để đọc ở đây.',
        ),
      ),
      'timeout' => (
        couldNot,
        tr(
          context,
          'The site took too long to answer.',
          'Trang web phản hồi quá lâu.',
        ),
      ),
      'unsafeAddress' || 'unsafeUrl' || 'unsafeRedirect' => (
        couldNot,
        tr(
          context,
          'This address leads to a private or local network, so it is not fetched.',
          'Địa chỉ này dẫn tới mạng riêng hoặc mạng nội bộ nên không được tải.',
        ),
      ),
      'tooManyRedirects' => (
        couldNot,
        tr(
          context,
          'The page redirected too many times.',
          'Trang chuyển hướng quá nhiều lần.',
        ),
      ),
      'busy' || 'rateLimited' => (
        couldNot,
        tr(
          context,
          'Another job is using the network. Try again in a moment.',
          'Một việc khác đang dùng mạng. Hãy thử lại sau giây lát.',
        ),
      ),
      _ => (
        couldNot,
        tr(
          context,
          'The site could not be reached. Check the connection and try again.',
          'Chưa kết nối được trang web. Hãy kiểm tra mạng rồi thử lại.',
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final theme = Theme.of(context);
    final (title, message) = _words(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          key: Key('reader-problem-$problem'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.xxl,
            HandySpace.l,
            HandySpace.xl,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(title, style: bookmarkSerif(context, 26)),
            ),
            if (message != null) ...[
              const SizedBox(height: HandySpace.s),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: p.muted,
                  height: 1.5,
                ),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: HandySpace.s),
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
            if (onOpenOriginal != null || onRetry != null) ...[
              const SizedBox(height: HandySpace.xl),
              Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  if (onOpenOriginal != null)
                    FilledButton.icon(
                      key: const Key('reader-open-original'),
                      onPressed: onOpenOriginal,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(tr(context, 'Open original', 'Mở bản gốc')),
                    ),
                  if (onRetry != null)
                    OutlinedButton(
                      key: const Key('reader-retry'),
                      onPressed: onRetry,
                      child: Text(tr(context, 'Try again', 'Thử lại')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
