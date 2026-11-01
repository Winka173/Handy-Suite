import 'dart:typed_data';

const metadataMaxUrlLength = 8192;
const metadataMaxHtmlBytes = 512 * 1024;
const metadataMaxThumbnailBytes = 1024 * 1024;
const metadataMaxImagePixels = 2000000;
const metadataMaxRedirects = 3;
const metadataTimeout = Duration(seconds: 8);

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
