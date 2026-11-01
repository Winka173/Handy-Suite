import 'package:handy_core/handy_core.dart';
import 'metadata_client.dart';

/// Browser Fetch hides DNS and redirect addresses. Without a proxy there is no
/// trustworthy SSRF check, so the browser adapter performs no network requests.
class PlatformMetadataClient implements MetadataClient {
  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async => MetadataResult(
    status: 'unavailable',
    errorCode: cancellation?.isCancelled == true
        ? 'cancelled'
        : 'browserNetworkPolicy',
  );
  @override
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    CancellationToken? cancellation,
  }) async => ThumbnailResult(
    errorCode: cancellation?.isCancelled == true
        ? 'cancelled'
        : 'browserNetworkPolicy',
  );
  @override
  void dispose() {}
}
