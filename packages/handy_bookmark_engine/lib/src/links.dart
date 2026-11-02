import 'models.dart';
import 'urls.dart';

/// What the network said about one address, before it is judged. Filled by
/// the app's safe fetcher (HEAD, then GET when HEAD is refused).
class LinkProbe {
  /// Final HTTP status, or null when no answer came back.
  final int? status;

  /// The address reached by following only permanent redirects (301/308)
  /// from the start, when there was at least one.
  final String? permanentUrl;

  /// Short failure code (`timeout`, `unsafeAddress`, `networkUnavailable`…)
  /// when there is no status.
  final String? error;
  const LinkProbe({this.status, this.permanentUrl, this.error});
}

String _comparable(String url) {
  final u = Uri.parse(UrlTools.normalize(url).canonicalUrl);
  final host = u.host.replaceFirst(RegExp(r'^www\.'), '');
  final path = u.path.endsWith('/')
      ? u.path.substring(0, u.path.length - 1)
      : u.path;
  return '$host$path?${u.query}';
}

/// Judges a probe conservatively: only 404/410 are `gone`; sign-in walls,
/// rate limits, server errors and network failures are `unreachable`
/// ("could not tell"); a permanent redirect to a really different address is
/// `moved`. Changes of scheme, `www.` or a trailing slash alone stay `ok`.
LinkCheck classifyLinkProbe(String url, LinkProbe probe, String checkedAt) {
  final status = probe.status;
  if (status == null) {
    return LinkCheck(
      status: 'unreachable',
      checkedAt: checkedAt,
      reason: probe.error ?? 'networkUnavailable',
    );
  }
  if (status == 404 || status == 410) {
    return LinkCheck(status: 'gone', checkedAt: checkedAt, httpStatus: status);
  }
  if (status < 200 || status > 299) {
    return LinkCheck(
      status: 'unreachable',
      checkedAt: checkedAt,
      httpStatus: status,
      reason: 'http',
    );
  }
  final moved = probe.permanentUrl;
  if (moved != null) {
    try {
      if (_comparable(moved) != _comparable(url)) {
        final from = Uri.parse(url), to = Uri.parse(moved);
        final home =
            from.path.replaceAll('/', '').isNotEmpty &&
            to.path.replaceAll('/', '').isEmpty;
        return LinkCheck(
          status: 'moved',
          checkedAt: checkedAt,
          movedTo: UrlTools.normalize(moved).originalUrl,
          httpStatus: status,
          // A deep link that now lands on the home page was probably removed.
          reason: home ? 'home' : null,
        );
      }
    } on FormatException {
      // An odd redirect target is not worth offering; the page still works.
    }
  }
  return LinkCheck(status: 'ok', checkedAt: checkedAt, httpStatus: status);
}

/// The bookmark pointing at the address its check found it moved to. Title,
/// notes, tags and place stay; the check now reads `ok`.
Bookmark adoptMovedUrl(Bookmark b, String now) {
  final check = b.linkCheck;
  if (check == null || check.status != 'moved')
    throw StateError('This link has no new address');
  final u = UrlTools.normalize(check.movedTo!);
  return b.copyWith(
    originalUrl: u.originalUrl,
    normalizedUrl: u.normalizedUrl,
    canonicalUrl: u.canonicalUrl,
    platform: u.platform,
    contentType: u.contentType,
    sourceDomain: u.sourceDomain,
    updatedAt: now,
    linkCheck: LinkCheck(
      status: 'ok',
      checkedAt: check.checkedAt,
      httpStatus: check.httpStatus,
    ),
  );
}

/// The whole manual order after the person drags or steps one link within
/// [visible] (what the list shows, in order) from [from] to [to] (its index
/// once moved). Links outside the list keep their places.
List<String> moveInManualOrder(
  SaveLibrary library,
  List<String> visible,
  int from,
  int to,
) {
  if (from < 0 || from >= visible.length || to < 0 || to >= visible.length)
    throw RangeError('Move outside the list');
  final full = library.fullManualOrder();
  if (from == to) return full;
  final shown = [...visible];
  final id = shown.removeAt(from);
  shown.insert(to, id);
  full.remove(id);
  final before = to + 1 < shown.length;
  final anchor = full.indexOf(before ? shown[to + 1] : shown[to - 1]);
  if (anchor < 0 || !library.bookmarks.any((b) => b.id == id))
    throw StateError('The list is out of date');
  full.insert(before ? anchor : anchor + 1, id);
  return full;
}
