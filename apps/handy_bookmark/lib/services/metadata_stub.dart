import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart'
    show LinkProbe;
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
  Future<ThumbnailResult> fetchArticlePicture(
    String url, {
    CancellationToken? cancellation,
  }) async => ThumbnailResult(
    errorCode: cancellation?.isCancelled == true
        ? 'cancelled'
        : 'browserNetworkPolicy',
  );
  @override
  bool get available => false;
  @override
  Future<PageResult> fetchPage(
    String url, {
    CancellationToken? cancellation,
  }) async => const PageResult(errorCode: 'browserNetworkPolicy');
  @override
  Future<LinkProbe> probe(
    String url, {
    CancellationToken? cancellation,
  }) async => const LinkProbe(error: 'browserNetworkPolicy');
  @override
  void dispose() {}
}
