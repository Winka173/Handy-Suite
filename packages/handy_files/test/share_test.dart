import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class SharePort extends SharePlatform {
  ShareParams? params;
  Completer<ShareResult>? gate;
  ShareResult result = const ShareResult('selected', ShareResultStatus.success);
  @override
  Future<ShareResult> share(ShareParams value) async {
    params = value;
    return gate?.future ?? result;
  }
}

void main() {
  test(
    'share snapshots exact bytes, sanitizes filenames and disables remote/download fallback',
    () async {
      final port = SharePort(), source = Uint8List.fromList([1, 2, 255]);
      final share = LocalShare(client: SharePlus.custom(port));
      final future = share.bytes(
        '../private/test.pdf',
        source,
        mimeType: 'application/pdf',
        origin: const Rect.fromLTWH(1, 1, 40, 40),
      );
      source[0] = 42;
      expect(await future, LocalShareResult.selected);
      expect(await port.params!.files!.single.readAsBytes(), [1, 2, 255]);
      expect(port.params!.fileNameOverrides!.single, isNot(contains('/')));
      expect(port.params!.uri, isNull);
      expect(port.params!.text, isNull);
      expect(port.params!.downloadFallbackEnabled, isFalse);
      expect(port.params!.mailToFallbackEnabled, isFalse);
      port.result = const ShareResult('', ShareResultStatus.dismissed);
      expect(
        await share.bytes(
          'copy.pdf',
          source,
          mimeType: 'application/pdf',
          origin: const Rect.fromLTWH(1, 1, 40, 40),
        ),
        LocalShareResult.dismissed,
      );
      port.result = ShareResult.unavailable;
      expect(
        await share.bytes(
          'copy.pdf',
          source,
          mimeType: 'application/pdf',
          origin: const Rect.fromLTWH(1, 1, 40, 40),
        ),
        LocalShareResult.unknown,
      );
    },
  );
  test(
    'share rejects limits/MIME/origin before dispatch and observes cancellation',
    () async {
      final port = SharePort(),
          share = LocalShare(client: SharePlus.custom(SharePort()));
      for (final bytes in [Uint8List(0), Uint8List(30000001)]) {
        await expectLater(
          share.bytes(
            'copy.bin',
            bytes,
            mimeType: 'application/octet-stream',
            origin: const Rect.fromLTWH(1, 1, 40, 40),
          ),
          throwsFormatException,
        );
      }
      await expectLater(
        share.bytes(
          'copy.bin',
          Uint8List(1),
          mimeType: 'https://bad',
          origin: const Rect.fromLTWH(1, 1, 40, 40),
        ),
        throwsFormatException,
      );
      await expectLater(
        share.bytes(
          'copy.bin',
          Uint8List(1),
          mimeType: 'image/png',
          origin: Rect.zero,
        ),
        throwsFormatException,
      );
      final token = CancellationToken()..cancel();
      await expectLater(
        share.bytes(
          'copy.bin',
          Uint8List(1),
          mimeType: 'image/png',
          origin: const Rect.fromLTWH(1, 1, 40, 40),
          cancellation: token,
        ),
        throwsA(isA<Cancelled>()),
      );
      port.gate = Completer<ShareResult>();
      final waiting = CancellationToken();
      final future = LocalShare(client: SharePlus.custom(port)).bytes(
        'copy.bin',
        Uint8List(1),
        mimeType: 'image/png',
        origin: const Rect.fromLTWH(1, 1, 40, 40),
        cancellation: waiting,
      );
      waiting.cancel();
      port.gate!.complete(port.result);
      await expectLater(future, throwsA(isA<Cancelled>()));
    },
  );
}
