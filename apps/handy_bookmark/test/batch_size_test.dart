import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_bookmark/links/batch_size.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'link_tasks_test.dart' show boot;

void main() {
  test(
    'bounded job processes 25 and retains remaining links and original URLs',
    () async {
      final (c, net, _) = await boot();
      for (var i = 0; i < 26; i++)
        await c.quickSave('https://host$i.example.com/');
      final urls = c.library!.bookmarks.map((b) => b.originalUrl).toList();
      final tasks = LinkTasks(
        c,
        hostSpacing: Duration.zero,
        retryDelay: Duration.zero,
      );
      net.asked.clear();
      final report = await tasks.checkLinks(
        c.library!.bookmarks.map((b) => b.id),
        limit: quickLinkBatch,
      );
      expect(report.done, 25);
      expect(report.overCap, urls.length - 25);
      expect(net.asked, hasLength(25));
      expect(c.library!.bookmarks.map((b) => b.originalUrl).toList(), urls);
      tasks.dispose();
      c.dispose();
    },
  );
  testWidgets('larger batches require an explicit Advanced selection', (
    t,
  ) async {
    int? chosen;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => chosen = await chooseLinkBatch(
                context,
                count: 80,
                maximum: 200,
                reading: true,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('link-batch-large')), findsNothing);
    await t.tap(find.byKey(const Key('link-batch-quick')));
    await t.pumpAndSettle();
    expect(chosen, 25);
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('link-batch-advanced')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('link-batch-large')));
    await t.pumpAndSettle();
    expect(chosen, 80);
    await t.tap(find.text('Start'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('link-batch-cancel')));
    await t.pumpAndSettle();
    expect(chosen, isNull);
  });
}
