import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:image/image.dart' as img;

final registry = ElementRegistry.standard();
final at = DateTime.utc(2026, 11, 2);

CardProfile anh() => CardProfile(
  id: 'p1',
  displayName: 'Nguyễn Minh Anh',
  role: 'Kiến trúc sư; trưởng nhóm',
  organization: 'Studio Ánh Minh, Hà Nội',
  bio: 'Dòng 1\nDòng 2',
  phones: const [
    ProfileValue('cell', '0912 345 678'),
    ProfileValue('work', '024 3826 0000'),
    ProfileValue('', '0999 000 111', private: true),
  ],
  emails: const [ProfileValue('', 'minhanh@example.com')],
  websites: const [
    ProfileValue('', 'minhanh.example.com'),
    ProfileValue('', 'javascript:alert(1)'),
  ],
  addresses: const [ProfileValue('', '12 Nguyễn Huệ, Quận 1')],
);

Uint8List png(int w, int h) => Uint8List.fromList(
  img.encodePng(
    img.Image(width: w, height: h)..clear(img.ColorRgb8(200, 30, 30)),
  ),
);

void main() {
  group('vCard', () {
    test('escapes, folds at 75 octets and keeps Vietnamese whole', () {
      final v = vcardFor(anh());
      expect(v, startsWith('BEGIN:VCARD\r\nVERSION:3.0\r\n'));
      expect(v, contains(r'TITLE:Kiến trúc sư\; trưởng nhóm'));
      expect(v, contains(r'ORG:Studio Ánh Minh\, Hà Nội'));
      expect(v, contains(r'NOTE:Dòng 1\nDòng 2'));
      expect(
        RegExp('TEL').allMatches(v).length,
        2,
        reason: 'the private number stays out',
      );
      expect(v, isNot(contains('javascript')));
      for (final line in v.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      // Unfolding gives back valid UTF-8 text.
      final unfolded = v.replaceAll('\r\n ', '');
      expect(unfolded, contains('ADR;TYPE=WORK:;;12 Nguyễn Huệ\\, Quận 1;;;;'));
      expect(
        vcardFor(anh(), version: '4.0'),
        contains('TEL;TYPE=cell;VALUE=uri:tel:0912345678'),
      );
      final back = profileFromVcard(v, id: 'x');
      expect(back.displayName, 'Nguyễn Minh Anh');
      expect(back.role, 'Kiến trúc sư; trưởng nhóm');
    });
  });

  group('QR', () {
    test(
      'a vCard payload makes a matrix; too much content is refused clearly',
      () {
        final m = qrMatrix(vcardFor(anh()), ecc: 'M');
        expect(m.size, greaterThan(40));
        expect(() => qrMatrix('x' * 5000), throwsFormatException);
        final check = qrPrintCheck(vcardFor(anh()), sidePoints: 40);
        expect(
          check.warning,
          isNotNull,
          reason: '40 pt is too small for this much',
        );
        expect(
          qrPrintCheck('https://example.com', sidePoints: 72).warning,
          isNull,
        );
        expect(
          qrWifi(ssid: 'Nhà; Lan', password: 'a:b'),
          r'WIFI:T:WPA;S:Nhà\; Lan;P:a\:b;;',
        );
        expect(() => qrUrl('ftp://x'), throwsFormatException);
      },
    );
  });

  group('profile links', () {
    test('only https, tel and mailto survive; private values stay out', () {
      expect(safeHttpsUrl('example.com/a'), 'https://example.com/a');
      expect(safeHttpsUrl('http://example.com'), isNull);
      expect(safeHttpsUrl('https://user:pw@example.com'), isNull);
      expect(safeHttpsUrl('javascript:alert(1)'), isNull);
      expect(telUri('+84 912-345-678'), 'tel:+84912345678');
      expect(
        profileValue(anh(), 'phone:3'),
        '',
        reason: 'the third phone is private',
      );
      expect(anh().problems().single.$1, 'link');
    });

    test('live bindings follow the profile; unlinking keeps the text', () {
      final e = registry.create(
        'contact',
        at: const Vec(0, 0),
        props: {'prefix': 'T: '},
        binding: const ElementBinding('phone'),
      );
      expect(displayText(e, anh()), 'T: 0912 345 678');
      final un = unlinkElement(e, anh());
      expect(un.binding!.mode, 'snapshot');
      final changed = CardProfile(
        id: 'p1',
        phones: const [ProfileValue('', '0000 111 222')],
      );
      expect(displayText(un, changed), 'T: 0912 345 678');
      expect(displayText(e, changed), 'T: 0000 111 222');
    });
  });

  group('HTML', () {
    test('the profile page escapes everything and links only safely', () {
      final evil = CardProfile(
        id: 'p2',
        displayName: '<script>alert(1)</script>',
        bio: '"><img src=x onerror=alert(1)>',
        websites: const [
          ProfileValue('', 'javascript:alert(1)'),
          ProfileValue('Site', 'example.com'),
        ],
        emails: const [ProfileValue('', 'a@b.co')],
      );
      final html = profileHtml(evil);
      expect(html, isNot(contains('<script>')));
      expect(html, isNot(contains('<img src=x')));
      expect(html, isNot(contains('href="javascript')));
      expect(html, contains('href="https://example.com"'));
      expect(html, contains('href="mailto:a@b.co"'));
      expect(html, contains("default-src 'none'"));
      expect(html, contains('data:text/vcard'));
      expect(emailSignatureHtml(evil), isNot(contains('<script>')));
    });
  });

  group('SVG and PDF', () {
    CardDocument design() {
      final d = cardTemplates
          .firstWhere((t) => t.id == 'gradient')
          .build(registry, at);
      return d.copyWith(profileId: 'p1');
    }

    test(
      'SVG sets real text, escapes it and sizes the page in millimetres',
      () {
        final d = design();
        final out = exportSvg(d, d.pages.first.id, profile: anh(), bleed: true);
        expect(
          out.svg,
          contains('width="96mm" height="60mm"'),
          reason: '90 × 54 mm plus 3 mm bleed each side',
        );
        expect(out.svg, contains('Nguyễn Minh Anh'));
        expect(out.svg, contains('linearGradient'));
        final back = exportSvg(d, d.pages[1].id, profile: anh()).svg;
        expect(
          back,
          contains('shape-rendering="crispEdges"'),
          reason: 'the QR is drawn',
        );
        final evil = withPageElements(d, d.pages.first.id, [
          registry.create(
            'text',
            at: const Vec(50, 50),
            props: {'text': '</text><script>x</script>'},
          ),
        ]);
        expect(
          exportSvg(evil, evil.pages.first.id).svg,
          isNot(contains('<script>')),
        );
      },
    );

    test(
      'PDF embeds the face, keeps the size, adds bleed and crop marks',
      () async {
        final face = File(
          '../../apps/handy_card/fonts/HankenGrotesk-Regular.ttf',
        ).readAsBytesSync();
        final d = design();
        final out = await exportPdf(
          d,
          profile: anh(),
          fonts: {'sans-400': face, 'sans-700': face},
          bleed: true,
          cropMarks: true,
        );
        expect(String.fromCharCodes(out.bytes.take(5)), '%PDF-');
        expect(out.warnings, isEmpty);
        final text = latin1.decode(out.bytes);
        expect(
          RegExp(r'/Type\s*/Page\b').allMatches(text).length,
          2,
          reason: 'two sides',
        );
        expect(text, contains('/FontFile2'), reason: 'the face is embedded');
        final plain = await exportPdf(d, profile: anh());
        expect(plain.warnings.single, contains('Helvetica'));
        final sheet = await exportPrintSheet(
          d,
          d.pages.first.id,
          copies: 10,
          fonts: {'sans-400': face},
        );
        expect(sheet.perSheet, greaterThanOrEqualTo(8));
      },
    );

    test('pictures crop and fit the same way in every renderer', () {
      final e = registry.create(
        'image',
        at: const Vec(50, 50),
        props: {'fit': 'cover'},
      );
      final cover = imagePlacement(
        e.copyWith(frame: const Frame(0, 0, 100, 50)),
        200,
        200,
      );
      expect(cover.width, 100);
      expect(cover.y, -25);
      final cropped = e.copyWith(
        frame: const Frame(0, 0, 100, 100),
        props: {...e.props, 'cropX': 0.5, 'cropW': 0.5},
      );
      expect(imagePlacement(cropped, 200, 100).x, closeTo(-100, 1e-6));
    });
  });

  group('project ZIP', () {
    test('round trips designs, profiles and pictures; refuses damage', () {
      final picture = png(4, 4);
      final id = assetId(picture);
      final base = cardTemplates.first.build(registry, at);
      final withPic =
          withPageElements(base, base.pages.first.id, [
            ...base.pages.first.elements,
            registry.create(
              'image',
              at: const Vec(20, 20),
              props: {'asset': id},
            ),
          ]).copyWith(
            assets: [
              CardAsset(
                id: id,
                mime: 'image/png',
                width: 4,
                height: 4,
                size: picture.length,
              ),
            ],
          );
      final zip = encodeCardProject(
        designs: [withPic],
        profiles: [anh()],
        assets: {id: picture},
        at: at,
      );
      final back = decodeCardProject(zip, registry);
      expect(back.designs.single.encode(), withPic.encode());
      expect(back.profiles.single.displayName, 'Nguyễn Minh Anh');
      expect(back.assets[id], picture);
      expect(back.missingAssets, isEmpty);

      // A file changed after export is caught by its hash.
      final archive = ZipDecoder().decodeBytes(zip);
      final tampered = Archive();
      for (final f in archive.files) {
        final bytes = f.name.startsWith('designs/')
            ? utf8.encode(
                utf8
                    .decode(f.content as List<int>)
                    .replaceFirst('Minimal', 'Changed'),
              )
            : f.content as List<int>;
        tampered.addFile(ArchiveFile.bytes(f.name, Uint8List.fromList(bytes)));
      }
      expect(
        () => decodeCardProject(
          Uint8List.fromList(ZipEncoder().encode(tampered)),
          registry,
        ),
        throwsFormatException,
      );

      // Paths outside the fixed list (traversal included) are refused.
      final slip = Archive()
        ..addFile(
          ArchiveFile.bytes(
            'manifest.json',
            Uint8List.fromList(utf8.encode('{}')),
          ),
        )
        ..addFile(
          ArchiveFile.bytes(
            '../evil.json',
            Uint8List.fromList(utf8.encode('{}')),
          ),
        );
      expect(
        () => decodeCardProject(
          Uint8List.fromList(ZipEncoder().encode(slip)),
          registry,
        ),
        throwsFormatException,
      );
      expect(
        () => decodeCardProject(Uint8List.fromList([1, 2, 3]), registry),
        throwsFormatException,
      );
    });
  });

  test('batch rows report problems and keep file names unique', () {
    final rows = batchRows(
      [
        ['Họ tên', 'Email', 'Điện thoại'],
        ['Lan', 'lan@example.com', '0912345678'],
        ['', 'x@example.com', ''],
        ['Lan', 'lan@example.com', ''],
        ['Lan', 'lan2@example.com', 'abc'],
        ['Lan', 'not-an-email', ''],
        ['Nam', '', ''],
      ],
      {'name': 'Họ tên', 'email': 'Email', 'phone': 'Điện thoại'},
    );
    expect(rows.map((r) => r.problem), [
      null,
      'No name',
      'Repeats an earlier row',
      'Phone is not valid',
      'Email is not valid',
      null,
    ]);
    expect(rows.map((r) => r.fileName).toSet().length, rows.length);
  });

  test('every starter template is valid and round trips', () {
    for (final t in cardTemplates) {
      final d = t.build(registry, at);
      expect(
        CardDocument.decode(d.encode(), registry).encode(),
        d.encode(),
        reason: t.id,
      );
    }
  });
}
