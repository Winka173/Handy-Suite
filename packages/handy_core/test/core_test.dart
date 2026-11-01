import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';

void main() {
  test(
    'portable filenames preserve Vietnamese and neutralize reserved/path names',
    () {
      expect(safeFilename('hóa đơn.txt'), 'hóa đơn.txt');
      expect(safeFilename('../CON.txt'), '_CON.txt');
      expect(safeFilename('CON.txt'), 'file_CON.txt');
      expect(safeFilename('a/b:c.txt'), 'a_b_c.txt');
      expect(safeFilename('...'), 'output');
    },
  );
  test(
    'strict UTF8 keeps genuine replacement characters and strips only BOM',
    () {
      expect(decodeUtf8(utf8.encode('\ufeffXin chào �')), 'Xin chào �');
      expect(() => decodeUtf8([0xc3, 0x28]), throwsFormatException);
      expect(() => decodeUtf8([65, 0, 66]), throwsFormatException);
      expect(() => decodeUtf8([65, 66], maxBytes: 1), throwsFormatException);
    },
  );
  test('archive traversal and Windows absolute paths rejected', () {
    for (final path in [
      '../x',
      'a/../x',
      '/root',
      'C:/x',
      'a\\x',
      'a//x',
      'a/./x',
      'a\u0000b',
    ]) {
      expect(safeArchivePath(path), false, reason: path);
    }
    expect(safeArchivePath('assets/ảnh.png'), true);
  });
  test('cancellation cannot be mistaken for successful output', () {
    final c = CancellationToken();
    c.check();
    c.cancel();
    expect(c.check, throwsA(isA<Cancelled>()));
  });
  test(
    'platform registry distinguishes implementation from theoretical capability',
    () {
      for (final p in HandyPlatform.values) {
        final r = Capabilities(p);
        expect(r.get('calculator').usable, true);
        expect(r.get('purchase').usable, false);
        expect(
          r.get('capture').usable,
          p == HandyPlatform.android || p == HandyPlatform.ios,
        );
        expect(r.get('http').usable, true);
        expect(r.get('purchase').requiresSetup, true);
      }
      expect(
        const Capabilities(HandyPlatform.web).get('http').reason,
        contains('CORS'),
      );
      expect(
        const Capabilities(HandyPlatform.web).get('capture').reason,
        contains('Import'),
      );
      expect(
        const Capabilities(HandyPlatform.ios).get('capture').reason,
        contains('not built/run'),
      );
      expect(
        const Capabilities(HandyPlatform.windows).get('ads').implemented,
        false,
      );
    },
  );
  test('free ads require consent and actual setup', () {
    expect(
      adsAllowed(const Entitlement.free(), configured: false, consent: true),
      false,
    );
    expect(
      adsAllowed(const Entitlement.free(), configured: true, consent: false),
      false,
    );
    expect(
      adsAllowed(
        const Entitlement.verified('tools_lifetime'),
        configured: true,
        consent: true,
      ),
      false,
    );
  });
}
