part of '../handy_card_engine.dart';

/// A starter design: original layouts made for Handy Card, every element
/// editable, contact fields bound live to the design's profile.
class CardTemplate {
  final String id, en, vi, kind;
  final CardDocument Function(ElementRegistry r, DateTime at) build;
  const CardTemplate(this.id, this.en, this.vi, this.kind, this.build);
}

CardElement _el(
  ElementRegistry r,
  String type,
  double x,
  double y,
  double w,
  double h, {
  Map<String, Object?> props = const {},
  String? bind,
  String name = '',
  double rotation = 0,
}) {
  final s = r.spec(type);
  return CardElement(
    id: newCardId(),
    type: type,
    name: name,
    frame: Frame(x, y, w, h, rotation),
    props: s.normalize({...s.defaults(), ...props}),
    binding: bind == null ? null : ElementBinding(bind),
  );
}

CardDocument _doc(
  String kind,
  String name,
  CardSize size,
  DateTime at,
  List<CardElement> front,
  List<CardElement> back, {
  String frontBg = 'FFFFFF',
  String backBg = 'FFFFFF',
  bool portrait = false,
}) {
  final d = blankDocument(
    size: size,
    portrait: portrait,
    kind: kind,
    name: name,
    at: at,
  );
  return d.copyWith(
    pages: [
      d.pages[0].copyWith(elements: front, background: frontBg),
      if (back.isNotEmpty)
        d.pages[1].copyWith(elements: back, background: backBg),
      if (back.isEmpty) d.pages[1].copyWith(background: backBg),
    ],
  );
}

final cardTemplates = <CardTemplate>[
  CardTemplate(
    'minimal',
    'Minimal professional',
    'Tối giản chuyên nghiệp',
    'business',
    (r, at) {
      return _doc(
        'business',
        'Minimal',
        cardSizes[0],
        at,
        [
          _el(
            r,
            'text',
            17,
            22,
            200,
            24,
            bind: 'name',
            props: {'text': 'Nguyễn Minh Anh', 'size': 15, 'weight': 600},
          ),
          _el(
            r,
            'text',
            17,
            44,
            200,
            16,
            bind: 'role',
            props: {'text': 'Kiến trúc sư', 'size': 8.5, 'color': '5F6670'},
          ),
          _el(
            r,
            'line',
            17,
            70,
            28,
            2,
            props: {'stroke': '111111', 'strokeWidth': 1},
          ),
          _el(r, 'icon', 17, 90, 8, 8, props: {'glyph': 'phone'}),
          _el(
            r,
            'contact',
            30,
            88,
            200,
            12,
            bind: 'phone',
            props: {'text': '0912 345 678', 'size': 7.5},
          ),
          _el(r, 'icon', 17, 104, 8, 8, props: {'glyph': 'mail'}),
          _el(
            r,
            'contact',
            30,
            102,
            200,
            12,
            bind: 'email',
            props: {'text': 'minhanh@example.com', 'size': 7.5},
          ),
          _el(r, 'icon', 17, 118, 8, 8, props: {'glyph': 'web'}),
          _el(
            r,
            'contact',
            30,
            116,
            200,
            12,
            bind: 'website',
            props: {'text': 'minhanh.example.com', 'size': 7.5},
          ),
        ],
        [
          _el(
            r,
            'text',
            27,
            64,
            200,
            26,
            bind: 'org',
            props: {
              'text': 'Studio Ánh Minh',
              'size': 14,
              'weight': 600,
              'align': 'center',
            },
          ),
        ],
      );
    },
  ),
  CardTemplate(
    'gradient',
    'Modern gradient',
    'Hiện đại chuyển màu',
    'business',
    (r, at) {
      return _doc(
        'business',
        'Gradient',
        cardSizes[0],
        at,
        [
          _el(
            r,
            'rect',
            0,
            0,
            255.118,
            153.071,
            name: 'Background',
            props: {'fill': '0B3D2E', 'fill2': '1F7A5A', 'angle': 35},
          ),
          _el(
            r,
            'text',
            20,
            52,
            215,
            26,
            bind: 'name',
            props: {
              'text': 'Trần Quốc Bảo',
              'size': 17,
              'weight': 700,
              'color': 'FFFFFF',
            },
          ),
          _el(
            r,
            'text',
            20,
            78,
            215,
            14,
            bind: 'role',
            props: {'text': 'Kỹ sư phần mềm', 'size': 8.5, 'color': 'D6F2E6'},
          ),
          _el(
            r,
            'contact',
            20,
            118,
            150,
            12,
            bind: 'email',
            props: {'text': 'bao@example.com', 'size': 7.5, 'color': 'FFFFFF'},
          ),
        ],
        [
          _el(
            r,
            'qr',
            95,
            34,
            64,
            64,
            bind: 'vcard',
            props: {'payload': 'https://example.com'},
          ),
          _el(
            r,
            'text',
            40,
            106,
            175,
            12,
            props: {
              'text': 'Quét để lưu danh bạ',
              'size': 7,
              'align': 'center',
              'color': '5F6670',
            },
          ),
        ],
      );
    },
  ),
  CardTemplate('elegant', 'Elegant', 'Thanh lịch', 'business', (r, at) {
    return _doc(
      'business',
      'Elegant',
      cardSizes[0],
      at,
      [
        _el(
          r,
          'rect',
          10,
          10,
          235.118,
          133.071,
          props: {'fill': null, 'stroke': 'A88B5A', 'strokeWidth': 0.6},
        ),
        _el(
          r,
          'text',
          20,
          46,
          215,
          26,
          bind: 'name',
          props: {
            'text': 'Lê Thu Hà',
            'size': 16,
            'font': 'serif',
            'align': 'center',
          },
        ),
        _el(
          r,
          'text',
          20,
          72,
          215,
          12,
          bind: 'role',
          props: {
            'text': 'Luật sư',
            'size': 7.5,
            'align': 'center',
            'upper': true,
            'letterSpacing': 1.2,
            'color': '6B5A3A',
          },
        ),
        _el(
          r,
          'contact',
          20,
          108,
          215,
          12,
          bind: 'phone',
          props: {'text': '0987 654 321', 'size': 7.5, 'align': 'center'},
        ),
      ],
      [],
      frontBg: 'FBF8F2',
      backBg: '1E1B16',
    );
  }),
  CardTemplate('creator', 'Creator / social', 'Nhà sáng tạo', 'social', (
    r,
    at,
  ) {
    return _doc('social', 'Creator', cardSizes[6], at, [
      _el(
        r,
        'rect',
        0,
        0,
        1080,
        1080,
        props: {'fill': 'FFE9D6', 'fill2': 'FFD1E3', 'angle': 120},
      ),
      _el(r, 'image', 390, 180, 300, 300, props: {'mask': 'ellipse'}),
      _el(
        r,
        'text',
        140,
        520,
        800,
        90,
        bind: 'name',
        props: {
          'text': 'Mai Linh',
          'size': 72,
          'weight': 700,
          'align': 'center',
        },
      ),
      _el(
        r,
        'text',
        140,
        620,
        800,
        50,
        bind: 'bio',
        props: {
          'text': 'Nấu ăn · Du lịch · Sài Gòn',
          'size': 30,
          'align': 'center',
          'color': '4A3F45',
        },
      ),
      _el(
        r,
        'qr',
        440,
        740,
        200,
        200,
        bind: 'url',
        props: {'payload': 'https://example.com'},
      ),
    ], []);
  }),
  CardTemplate('portfolio', 'Portfolio', 'Portfolio', 'portfolio', (r, at) {
    return _doc('portfolio', 'Portfolio', cardSizes[0], at, [
      _el(r, 'rect', 0, 0, 96, 153.071, props: {'fill': '111111'}),
      _el(
        r,
        'text',
        110,
        30,
        135,
        40,
        bind: 'name',
        props: {'text': 'Phạm Gia Huy', 'size': 14, 'weight': 700},
      ),
      _el(
        r,
        'text',
        110,
        70,
        135,
        14,
        bind: 'role',
        props: {'text': 'Nhiếp ảnh gia', 'size': 8},
      ),
      _el(
        r,
        'contact',
        110,
        116,
        135,
        12,
        bind: 'website',
        props: {'text': 'giahuy.example.com', 'size': 7.5},
      ),
      _el(r, 'polygon', 28, 56, 40, 40, props: {'sides': 6, 'fill': 'FFFFFF'}),
    ], []);
  }),
  CardTemplate('badge', 'Conference badge', 'Thẻ hội nghị', 'event', (r, at) {
    return _doc(
      'event',
      'Badge',
      cardSizes[5],
      at,
      [
        _el(r, 'rect', 0, 0, 215.433, 44, props: {'fill': '111111'}),
        _el(
          r,
          'text',
          14,
          12,
          190,
          20,
          props: {
            'text': 'HỘI NGHỊ CÔNG NGHỆ 2026',
            'size': 9,
            'weight': 600,
            'color': 'FFFFFF',
            'letterSpacing': 1,
          },
        ),
        _el(
          r,
          'text',
          14,
          100,
          190,
          40,
          bind: 'name',
          props: {'text': 'Đỗ Khánh Vy', 'size': 22, 'weight': 700},
        ),
        _el(
          r,
          'text',
          14,
          140,
          190,
          16,
          bind: 'org',
          props: {'text': 'Công ty Ánh Sao', 'size': 10, 'color': '5F6670'},
        ),
        _el(r, 'badge', 150, 220, 52, 52, props: {'label': 'DIỄN GIẢ'}),
        _el(
          r,
          'qr',
          14,
          216,
          60,
          60,
          bind: 'vcard',
          props: {'payload': 'https://example.com'},
        ),
      ],
      [],
      portrait: true,
    );
  }),
  CardTemplate('shop', 'Shop / brand', 'Cửa hàng', 'brand', (r, at) {
    return _doc(
      'brand',
      'Shop',
      cardSizes[0],
      at,
      [
        _el(r, 'ellipse', 18, 40, 72, 72, props: {'fill': 'C2410C'}),
        _el(
          r,
          'text',
          18,
          66,
          72,
          20,
          bind: 'org',
          props: {
            'text': 'Bánh Mì Cô Ba',
            'size': 7,
            'weight': 700,
            'color': 'FFFFFF',
            'align': 'center',
          },
        ),
        _el(
          r,
          'text',
          104,
          46,
          140,
          18,
          props: {'text': 'Mở cửa 6:00 – 21:00', 'size': 8.5, 'weight': 600},
        ),
        _el(r, 'icon', 104, 72, 8, 8, props: {'glyph': 'pin'}),
        _el(
          r,
          'contact',
          116,
          70,
          130,
          24,
          bind: 'address',
          props: {'text': '12 Nguyễn Huệ, Quận 1', 'size': 7.5},
        ),
        _el(r, 'icon', 104, 100, 8, 8, props: {'glyph': 'phone'}),
        _el(
          r,
          'contact',
          116,
          98,
          130,
          12,
          bind: 'phone',
          props: {'text': '028 3822 0000', 'size': 7.5},
        ),
      ],
      [],
      frontBg: 'FFF7ED',
    );
  }),
  CardTemplate(
    'blank',
    'Blank',
    'Trang trắng',
    'custom',
    (r, at) =>
        blankDocument(size: cardSizes[0], at: at, kind: 'custom', name: ''),
  ),
];
