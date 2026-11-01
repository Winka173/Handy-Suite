import 'package:handy_core/handy_core.dart';
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
  void dispose();
}
