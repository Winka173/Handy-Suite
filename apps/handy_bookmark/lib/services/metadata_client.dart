import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart'
    show LinkProbe;
import 'metadata_stub.dart'
    if (dart.library.io) 'metadata_native.dart'
    as platform;
import 'metadata_types.dart';
export 'metadata_types.dart';
export 'metadata_thumbnail.dart' show sanitizeThumbnail;

/// Network operations occur only when these methods are explicitly called.
abstract class MetadataClient {
  factory MetadataClient() = platform.PlatformMetadataClient;
  Future<MetadataResult> fetch(String url, {CancellationToken? cancellation});
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    CancellationToken? cancellation,
  });

  /// False where the network policy cannot be guaranteed (the browser):
  /// reading copies and link checks are then unavailable.
  bool get available;

  /// One picture of an article kept with its offline copy: at most 4 MB
  /// fetched, a still PNG, JPEG or WebP, returned as a clean JPEG of at
  /// most 1280 px. Asked only when the person keeps a copy.
  Future<ThumbnailResult> fetchArticlePicture(
    String url, {
    CancellationToken? cancellation,
  });

  /// The page as text, for an offline reading copy (HTML only, 3 MB).
  Future<PageResult> fetchPage(String url, {CancellationToken? cancellation});

  /// HEAD, then GET when HEAD is refused: the status and any permanent move.
  /// Never reads a body.
  Future<LinkProbe> probe(String url, {CancellationToken? cancellation});
  void dispose();
}
