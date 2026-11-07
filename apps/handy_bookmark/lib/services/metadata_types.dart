import 'dart:typed_data';

const metadataMaxUrlLength = 8192;

/// How far a page is read for its title and picture: up to its `</head>`,
/// never past this (YouTube puts them after ~800 KB of script).
const metadataHeadMaxBytes = 2 * 1024 * 1024;
const metadataMaxThumbnailBytes = 1024 * 1024;

/// A reel cover is 1080 x 1920 (2.07 Mpx); 4 Mpx also takes 1440 x 2560.
const metadataMaxImagePixels = 4000000;
const metadataMaxRedirects = 3;
const metadataTimeout = Duration(seconds: 8);

/// Reading copies read a whole page, so they allow more bytes and time.
const readingMaxHtmlBytes = 3 * 1024 * 1024;
const readingTimeout = Duration(seconds: 20);

/// Link checks follow a few more redirects than page details do.
const linkCheckMaxRedirects = 5;

class MetadataResult {
  const MetadataResult({
    this.title,
    this.description,
    this.siteName,
    this.author,
    this.canonicalUrl,
    this.thumbnailUrl,
    this.contentType,
    required this.status,
    this.errorCode,
  });
  final String? title,
      description,
      siteName,
      author,
      canonicalUrl,
      thumbnailUrl,
      contentType,
      errorCode;
  final String status;
}

class ThumbnailResult {
  const ThumbnailResult({this.bytes, this.contentType, this.errorCode});
  final Uint8List? bytes;
  final String? contentType, errorCode;
  bool get available => bytes != null;
}

/// A whole HTML page fetched for a reading copy, or why not.
class PageResult {
  const PageResult({this.html, this.uri, this.errorCode});
  final String? html;
  final Uri? uri;
  final String? errorCode;
}
