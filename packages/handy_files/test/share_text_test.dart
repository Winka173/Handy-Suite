import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/share.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class SharePort extends SharePlatform {
  ShareParams? params;
  ShareResult result = const ShareResult('selected', ShareResultStatus.success);
  @override
  Future<ShareResult> share(ShareParams value) async {
    params = value;
    return result;
  }
}

void main() {
  const origin = Rect.fromLTWH(1, 1, 40, 40);

  test('text share sends only the given text, subject and title, with no '
      'download or e-mail fallback', () async {
    final port = SharePort();
    final share = LocalShare(client: SharePlus.custom(port));
    expect(
      await share.text(
        '  Phở Hà Nội\nhttps://a.com/pho  ',
        subject: 'Phở Hà Nội',
        title: 'Phở Hà Nội',
        origin: origin,
      ),
      LocalShareResult.selected,
    );
    expect(port.params!.text, 'Phở Hà Nội\nhttps://a.com/pho');
    expect(port.params!.subject, 'Phở Hà Nội');
    expect(port.params!.title, 'Phở Hà Nội');
    expect(port.params!.files, isNull);
    expect(port.params!.uri, isNull);
    expect(port.params!.sharePositionOrigin, origin);
    expect(port.params!.downloadFallbackEnabled, isFalse);
    expect(port.params!.mailToFallbackEnabled, isFalse);

    await share.text('https://a.com', subject: '  ', origin: origin);
    expect(port.params!.subject, isNull, reason: 'blank subject is dropped');
    expect(port.params!.title, isNull);

    port.result = const ShareResult('', ShareResultStatus.dismissed);
    expect(
      await share.text('https://a.com', origin: origin),
      LocalShareResult.dismissed,
    );
    port.result = ShareResult.unavailable;
    expect(
      await share.text('https://a.com', origin: origin),
      LocalShareResult.unknown,
    );
  });

  test('text share refuses empty or huge text and a bad origin before '
      'dispatch, and observes cancellation', () async {
    final port = SharePort();
    final share = LocalShare(client: SharePlus.custom(port));
    for (final text in ['', '   ', 'x' * 100001]) {
      await expectLater(
        share.text(text, origin: origin),
        throwsFormatException,
      );
    }
    await expectLater(
      share.text('https://a.com', origin: Rect.zero),
      throwsFormatException,
    );
    await expectLater(
      share.text(
        'https://a.com',
        origin: const Rect.fromLTWH(double.nan, 0, 1, 1),
      ),
      throwsFormatException,
    );
    expect(port.params, isNull, reason: 'nothing reached the share sheet');
    final token = CancellationToken()..cancel();
    await expectLater(
      share.text('https://a.com', origin: origin, cancellation: token),
      throwsA(isA<Cancelled>()),
    );
    expect(port.params, isNull);
  });
}
