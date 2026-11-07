import 'metadata_types.dart';

/// Judging what a page read gave back, shared by the app and its share
/// sheet: whether a title only names the site, and whether a social site
/// answered with its login page instead of the post.

String _bare(String? v) =>
    (v ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Whether [text] is no more than the site's name or address.
bool onlyNamesSite({
  required String domain,
  required String platform,
  required String? text,
  String? siteName,
}) {
  final bare = _bare(text);
  if (bare.isEmpty) return true;
  final host = domain.toLowerCase().replaceFirst(
    RegExp(r'^(www|m|mobile)\.'),
    '',
  );
  return {
    _bare(host),
    _bare(host.split('.').first),
    _bare(siteName),
    _bare(platform),
  }.contains(bare);
}

/// Sites that answer apps with a login page now and then.
const walledSites = {'facebook', 'instagram', 'tiktok', 'reddit'};

/// A login page or a bare site page (Facebook, Instagram, TikTok's
/// "Make Your Day", Reddit's check) in place of the post or video.
bool looksLikeLoginWall({
  required String domain,
  required String platform,
  required MetadataResult result,
}) =>
    walledSites.contains(platform) &&
    result.thumbnailUrl == null &&
    (onlyNamesSite(
          domain: domain,
          platform: platform,
          text: result.title,
          siteName: result.siteName,
        ) ||
        RegExp(
          r'log ?in|sign up|đăng nhập|make your day',
          caseSensitive: false,
        ).hasMatch(result.title!));
