import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

Future<Docs> write(WidgetTester tester, {String? draft, Size? size}) async {
  final docs = Docs();
  if (draft != null) docs.markdown.text = serializeMarkdownDraft(draft);
  await start(tester, docs: docs, size: size ?? const Size(800, 900));
  await go(tester, '/write');
  return docs;
}

Future<void> export(WidgetTester tester, String kind) async {
  await tapKey(tester, 'markdown-export');
  await tapKey(tester, 'markdown-export-$kind');
}

void main() {
  testWidgets(
    'export history records checksums only, and a canceled export records nothing',
    (tester) async {
      const source = '# Private content';
      final docs = await write(tester, draft: source);
      docs.files.cancel = true;
      await export(tester, 'md');
      expect(await docs.history.load(), isEmpty);
      expect(find.text('Export canceled'), findsOneWidget);
      docs.files.cancel = false;
      await export(tester, 'md');
      final entry = (await docs.history.load()).single;
      expect(entry.mime, 'text/markdown');
      expect(entry.tool, 'md-source');
      expect(entry.matches(utf8.encode(source)), isTrue);
      expect(docs.log.text, isNot(contains('Private content')));
      docs.log.fail = true;
      await export(tester, 'md');
      expect(docs.files.exported, utf8.encode(source));
      expect(parseMarkdownDraft(docs.markdown.text!), source);
    },
  );

  testWidgets('a legacy BOM/CRLF draft exports its exact bytes', (
    tester,
  ) async {
    const source = '﻿# Tiếng Việt\r\n\r\nLine\r\n';
    final docs = await write(tester, draft: source);
    await export(tester, 'md');
    expect(docs.files.exported, utf8.encode(source));
    expect(parseMarkdownDraft(docs.markdown.text!), source);
  });

  testWidgets('open, save, reopen and MD/HTML/TXT exports round-trip', (
    tester,
  ) async {
    const source = '# Tiếng Việt\n\n| A | B |\n| --- | --- |\n| one | two |\n';
    final docs = await write(tester);
    docs.files.next = ImportedBytes(
      'doc.md',
      Uint8List.fromList(utf8.encode(source)),
    );
    await menu(tester, 'markdown-import');
    expect(sourceText(tester), source);
    await tapKey(tester, 'markdown-save');
    expect(parseMarkdownDraft(docs.markdown.text!), source);
    for (final kind in ['md', 'html', 'txt']) {
      await export(tester, kind);
      expect(docs.files.name, 'document.$kind');
      expect(utf8.decode(docs.files.exported!), switch (kind) {
        'md' => source,
        'html' => parseMarkdownDocument(source).html,
        _ => parseMarkdownDocument(source).text,
      });
    }
    await tester.pumpWidget(const SizedBox());
    await start(tester, docs: docs);
    await go(tester, '/write');
    expect(sourceText(tester), source);
  });

  testWidgets(
    'preview blocks remote and local pictures; a link shows its address and opens nothing',
    (tester) async {
      await write(
        tester,
        draft:
            '# Heading\n\n![Remote](https://secret.invalid/a.png)\n\n![Private](file:///private/data)\n\n[Link](https://secret.invalid/destination)\n\n<script>bad()</script>',
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('[Image blocked: Remote]'), findsOneWidget);
      expect(find.text('[Image blocked: Private]'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.text('Link', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.text('Link destination'), findsOneWidget);
      expect(find.text('https://secret.invalid/destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wide screens show the text and the page side by side', (
    tester,
  ) async {
    await write(
      tester,
      draft: '# Side\n\nby side',
      size: const Size(1280, 800),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markdown-source')), findsOneWidget);
    expect(find.byKey(const Key('markdown-preview')), findsOneWidget);
    expect(find.text('Preview'), findsNothing);
    await tester.enterText(find.byKey(const Key('markdown-source')), '# Live');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Live', findRichText: true), findsOneWidget);
  });

  testWidgets(
    'a failed save, a canceled picker, a declined replace and a canceled export keep the draft',
    (tester) async {
      final docs = await write(tester, draft: 'Saved');
      await tester.enterText(
        find.byKey(const Key('markdown-source')),
        'Unsaved',
      );
      await tester.pumpAndSettle();
      docs.markdown.fail = true;
      await tapKey(tester, 'markdown-save');
      expect(docs.markdown.attempts, 1);
      expect(parseMarkdownDraft(docs.markdown.text!), 'Saved');
      await menu(tester, 'markdown-import');
      expect(sourceText(tester), 'Unsaved');
      docs.files.next = ImportedBytes(
        'replacement.md',
        Uint8List.fromList(utf8.encode('Replacement')),
      );
      await menu(tester, 'markdown-import');
      expect(find.text('Replace unsaved draft?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(sourceText(tester), 'Unsaved');
      docs.files.cancel = true;
      await export(tester, 'md');
      expect(docs.files.exported, isNull);
      docs.markdown.fail = false;
      await tapKey(tester, 'markdown-save');
      expect(parseMarkdownDraft(docs.markdown.text!), 'Unsaved');
    },
  );

  testWidgets('replace is literal and templates use the engine', (
    tester,
  ) async {
    final docs = await write(tester, draft: 'Hello Hello');
    await menu(tester, 'markdown-find-open');
    await tester.enterText(find.byKey(const Key('markdown-find')), 'Hello');
    await tester.pumpAndSettle();
    expect(find.textContaining('2 found'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('markdown-replacement')),
      r'$&',
    );
    await tapKey(tester, 'markdown-replace-all');
    expect(sourceText(tester), r'$& $&');
    await menu(tester, 'markdown-template-table');
    expect(sourceText(tester), insertMarkdownTemplate(r'$& $&', 'table'));
    expect(parseMarkdownDraft(docs.markdown.text!), 'Hello Hello');
  });

  testWidgets(
    'past the preview limit the page says so; the exact text still exports',
    (tester) async {
      final source = '€' * 40000;
      final docs = await write(tester, draft: source);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Preview limit: 100 KB'), findsOneWidget);
      expect(find.byKey(const Key('markdown-preview')), findsNothing);
      await export(tester, 'md');
      expect(utf8.decode(docs.files.exported!), source);
      expect(parseMarkdownDraft(docs.markdown.text!), source);
    },
  );

  testWidgets('a damaged draft is never replaced by an empty one', (
    tester,
  ) async {
    final docs = Docs()..markdown.text = '{bad';
    await start(tester, docs: docs);
    await go(tester, '/write');
    expect(find.byKey(const Key('markdown-save')), findsNothing);
    expect(find.text('The draft could not be read'), findsOneWidget);
    expect(docs.markdown.attempts, 0);
    expect(docs.markdown.text, '{bad');
  });

  testWidgets(
    'leaving with unsaved words asks; keep writing stays, discard reverts, save saves',
    (tester) async {
      final docs = await write(tester, draft: 'Kept');
      await tester.enterText(find.byKey(const Key('markdown-source')), 'New');
      await tester.pumpAndSettle();
      await back(tester);
      expect(find.text('Save the draft first?'), findsOneWidget);
      await tester.tap(find.text('Keep writing'));
      await tester.pumpAndSettle();
      expect(sourceText(tester), 'New');
      await back(tester);
      await tester.tap(find.byKey(const Key('write-leave-discard')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('docs-desk')), findsOneWidget);
      expect(parseMarkdownDraft(docs.markdown.text!), 'Kept');
      await go(tester, '/write');
      expect(sourceText(tester), 'Kept');
      await tester.enterText(
        find.byKey(const Key('markdown-source')),
        'Saved now',
      );
      await tester.pumpAndSettle();
      await back(tester);
      await tester.tap(find.byKey(const Key('write-leave-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('docs-desk')), findsOneWidget);
      expect(parseMarkdownDraft(docs.markdown.text!), 'Saved now');
      expect(find.byKey(const Key('desk-work-write')), findsOneWidget);
    },
  );
}
