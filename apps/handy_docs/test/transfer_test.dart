import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/transfer/qr_view.dart';
import 'package:handy_docs/transfer/transfer_page.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

Uint8List bytes(int n) {
  final r = Random(5);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

/// The page with a camera that is fed by hand.
class Feed {
  ValueChanged<String>? read;
}

Future<Feed> page(
  WidgetTester tester,
  Files files, {
  bool camera = true,
}) async {
  final feed = Feed();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    HandyApp(
      brand: HandyBrand.docs,
      app: 'docs',
      title: 'Handy Docs',
      accent: docsAccent,
      home: TransferPage(
        files: files,
        camera: camera,
        scanner: (onCode) {
          feed.read = onCode;
          return const ColoredBox(color: Color(0xFF000000));
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return feed;
}

String progress(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('transfer-progress'))).data!;

void main() {
  testWidgets('the desk opens Send on a device without a camera', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await start(tester);
    await tapKey(tester, 'desk-transfer');
    expect(find.byKey(const Key('transfer-send-side')), findsOneWidget);
    await tapKey(tester, 'transfer-receive');
    expect(find.byKey(const Key('transfer-use-send')), findsOneWidget);
    await tapKey(tester, 'transfer-use-send');
    expect(find.byKey(const Key('transfer-choose')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a chosen file plays at once; Pause holds the frame', (
    tester,
  ) async {
    final files = Files()..next = ImportedBytes('note.txt', bytes(2000));
    await page(tester, files);
    await tapKey(tester, 'transfer-send');
    await tester.tap(find.byKey(const Key('transfer-choose')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(QrView), findsOneWidget);
    String frame() =>
        tester.widget<Text>(find.byKey(const Key('transfer-frame'))).data!;
    expect(frame(), contains('name and size'));
    await tester.pump(const Duration(milliseconds: 1000 ~/ qrTransferFps));
    expect(frame(), contains('frame 1 of 5'));
    await tester.tap(find.byKey(const Key('transfer-pause')));
    await tester.pump(const Duration(seconds: 1));
    expect(frame(), contains('frame 1 of 5'));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 1000 ~/ qrTransferFps));
    expect(frame(), contains('frame 2 of 5'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a file over 100 KB is refused and nothing plays', (
    tester,
  ) async {
    final files = Files()
      ..next = ImportedBytes('big.pdf', Uint8List(qrTransferLimit + 1));
    await page(tester, files, camera: false);
    await tapKey(tester, 'transfer-choose');
    expect(find.byType(QrView), findsNothing);
    expect(find.textContaining('over 100 KB'), findsOneWidget);
  });

  testWidgets('frames in any order arrive whole and save as the same file', (
    tester,
  ) async {
    final files = Files();
    final feed = await page(tester, files);
    final file = bytes(3000);
    final frames = qrTransferFrames('Hợp đồng.pdf', file);
    expect(progress(tester), contains('Point the camera'));
    for (final f in [...frames.skip(2), 'https://example.com']) {
      feed.read!(f);
    }
    await tester.pump();
    expect(progress(tester), contains('waiting for the name'));
    feed.read!(frames.first);
    await tester.pump();
    expect(find.text('Hợp đồng.pdf'), findsOneWidget);
    expect(progress(tester), contains('6 of 7 frames'));
    expect(find.byKey(const Key('transfer-save')), findsNothing);
    feed.read!(frames[1]);
    await tester.pumpAndSettle();
    expect(progress(tester), contains('Arrived whole'));
    await tapKey(tester, 'transfer-save');
    expect(files.exported, file);
    expect(files.name, 'Hợp đồng.pdf');
    expect(files.mime, 'application/pdf');
    expect(find.textContaining('Saved: Hợp đồng.pdf'), findsOneWidget);
    await tapKey(tester, 'transfer-again');
    expect(progress(tester), contains('Point the camera'));
  });

  testWidgets('a damaged file is never offered to save', (tester) async {
    final files = Files();
    final feed = await page(tester, files);
    final frames = qrTransferFrames('x.bin', bytes(1000));
    final parts = frames[1].split(':');
    parts[4] = 'AAAA${parts[4].substring(4)}';
    for (final f in [frames[0], parts.join(':'), frames[2], frames[3]]) {
      feed.read!(f);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-save')), findsNothing);
    expect(find.textContaining('did not arrive intact'), findsOneWidget);
    expect(files.exported, isNull);
    // It starts over: the good frames now complete it.
    for (final f in frames) {
      feed.read!(f);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-save')), findsOneWidget);
  });
}
