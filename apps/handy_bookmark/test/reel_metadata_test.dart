import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/services/metadata_client.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart'
    show LinkProbe;
import 'package:handy_core/handy_core.dart';
import 'controller_test.dart' show TestStore, TestInbox;

/// Answers each page read with the next result in [answers].
class ScriptedNet implements MetadataClient {
  ScriptedNet(this.answers);
  final List<MetadataResult> answers;
  int reads = 0;
  @override
  bool get available => true;
  @override
  Future<MetadataResult> fetch(
    String url, {
    CancellationToken? cancellation,
  }) async => answers[(reads++).clamp(0, answers.length - 1)];
  @override
  Future<ThumbnailResult> fetchThumbnail(
    String url, {
    CancellationToken? cancellation,
  }) async => const ThumbnailResult();
  @override
  Future<PageResult> fetchPage(
    String url, {
    CancellationToken? cancellation,
  }) async => const PageResult(errorCode: 'httpStatus');
  @override
  Future<LinkProbe> probe(
    String url, {
    CancellationToken? cancellation,
  }) async => const LinkProbe(status: 200);
  @override
  void dispose() {}
}

const reel = 'https://www.facebook.com/share/r/14vrigv1921/';
const wall = MetadataResult(status: 'partial', title: 'Facebook');
const real = MetadataResult(
  status: 'complete',
  title: '2,9 triệu lượt xem · 56K cảm xúc | Yêu nhầm (Part2) | Threads Hot',
  thumbnailUrl: 'https://scontent.example.net/v/cover.jpg',
);

Future<SaveController> start(ScriptedNet net) async {
  final c = SaveController(
    open: () async => TestStore(),
    shares: TestInbox(),
    metadataClient: net,
  );
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'a Facebook login page is not kept as the title; the next read is',
    () async {
      final net = ScriptedNet([wall, real]);
      final c = await start(net);
      c.preferences['automaticMetadata'] = false;
      final b = (await c.quickSave(reel, title: 'Facebook')).single;

      await c.refreshMetadata(b.id);
      var now = c.library!.bookmarks.single;
      expect(now.metadataStatus, 'failed');
      expect(now.title, 'Facebook');
      expect(now.thumbnailUrl, isNull);

      await c.refreshMetadata(b.id);
      now = c.library!.bookmarks.single;
      expect(now.metadataStatus, 'complete');
      // "Facebook" only named the site: the reel's own title replaces it.
      expect(now.title, real.title);
      expect(now.thumbnailUrl, real.thumbnailUrl);
    },
  );

  test('another site whose title is its own name is read as it is', () async {
    final net = ScriptedNet([
      const MetadataResult(status: 'partial', title: 'Example'),
    ]);
    final c = await start(net);
    c.preferences['automaticMetadata'] = false;
    final b = (await c.quickSave('https://example.com/a')).single;
    await c.refreshMetadata(b.id);
    expect(c.library!.bookmarks.single.metadataStatus, 'partial');
    expect(c.library!.bookmarks.single.title, 'Example');
  });
}
