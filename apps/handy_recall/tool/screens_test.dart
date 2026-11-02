// Review screenshots with the real typefaces and icons.
// SHOTS_DIR=<dir> flutter test --no-pub tool/screens_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_recall_app/app.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../test/apkg.dart';
import '../test/helpers.dart';

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.view(File(p).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

final _root = GlobalKey();

Future<void> shot(WidgetTester t, String name, {bool settle = true}) async {
  final dir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';
  Directory(dir).createSync(recursive: true);
  if (settle) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump();
  }
  await t.runAsync(() async {
    final b =
        _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

/// Frames of a transition for the review GIFs (`name-film-000.png`…).
Future<void> film(
  WidgetTester t,
  String name,
  Future<void> Function() action, {
  int frames = 16,
  Duration step = const Duration(milliseconds: 25),
}) async {
  await action();
  for (var i = 0; i < frames; i++) {
    await shot(t, '$name-film-${i.toString().padLeft(3, '0')}', settle: false);
    await t.pump(step);
  }
  await t.pumpAndSettle();
}

/// A simple drawn diagram for the picture card: four blocks, two links.
Future<String> diagram() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 600, 360),
    Paint()..color = const Color(0xFFF4F1EA),
  );
  const colors = [0xFFB9D7A8, 0xFFE8C9A0, 0xFFA9C6E8, 0xFFE3B5B5];
  const rects = [
    Rect.fromLTWH(40, 40, 220, 120),
    Rect.fromLTWH(340, 40, 220, 120),
    Rect.fromLTWH(40, 200, 220, 120),
    Rect.fromLTWH(340, 200, 220, 120),
  ];
  for (var i = 0; i < rects.length; i++) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rects[i], const Radius.circular(16)),
      Paint()..color = Color(colors[i]),
    );
  }
  final line = Paint()..strokeWidth = 6;
  canvas.drawLine(const Offset(260, 100), const Offset(340, 100), line);
  canvas.drawLine(const Offset(150, 160), const Offset(150, 200), line);
  final image = await recorder.endRecording().toImage(600, 360);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return 'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
}

const _words = [
  ('行う (おこなう)', 'tiến hành, thực hiện'),
  ('届ける (とどける)', 'gửi đến, chuyển tới'),
  ('比べる (くらべる)', 'so sánh'),
  ('伝える (つたえる)', 'truyền đạt'),
  ('迷う (まよう)', 'lạc đường; phân vân'),
  ('間に合う (まにあう)', 'kịp giờ'),
  ('片付ける (かたづける)', 'dọn dẹp'),
  ('慣れる (なれる)', 'quen với'),
  ('任せる (まかせる)', 'giao phó'),
  ('諦める (あきらめる)', 'từ bỏ'),
  ('預ける (あずける)', 'gửi, giao giữ'),
  ('払う (はらう)', 'trả tiền'),
  ('並ぶ (ならぶ)', 'xếp hàng'),
  ('調べる (しらべる)', 'tra cứu, điều tra'),
  ('集める (あつめる)', 'thu thập'),
  ('決める (きめる)', 'quyết định'),
  ('続ける (つづける)', 'tiếp tục'),
  ('育てる (そだてる)', 'nuôi dạy'),
  ('起こす (おこす)', 'đánh thức; gây ra'),
  ('壊れる (こわれる)', 'bị hỏng'),
  ('汚れる (よごれる)', 'bị bẩn'),
  ('助ける (たすける)', 'giúp đỡ'),
  ('答える (こたえる)', 'trả lời'),
  ('思い出す (おもいだす)', 'nhớ ra'),
];

/// Some overdue, a bump tomorrow, a tail across two weeks.
const _offsets = [
  -3,
  -1,
  0,
  0,
  0,
  1,
  1,
  1,
  2,
  3,
  3,
  4,
  6,
  7,
  9,
  10,
  12,
  13,
  15,
  20,
];

/// A learner three weeks into Japanese N3, anatomy and IELTS writing.
RecallState library(String picture) {
  var s = emptyRecallState();
  s = saveDeck(s, const RecallDeck(id: 'n3', name: 'Tiếng Nhật N3'));
  s = saveDeck(s, const RecallDeck(id: 'anat', name: 'Giải phẫu học'));
  s = saveDeck(s, const RecallDeck(id: 'ielts', name: 'IELTS Writing'));
  var n = 0;
  RecallCard card(
    String deck,
    String q,
    String a,
    int days, {
    int reviews = 2,
  }) {
    final due = now.add(Duration(days: days, hours: days <= 0 ? -1 : 0));
    n++;
    return RecallCard.fromJson({
      ...createCard(
        id: 'c$n',
        deckId: deck,
        front: q,
        back: a,
        now: at(now.subtract(const Duration(days: 30))),
      ).toJson(),
      'dueAt': at(due),
      'reviewCount': reviews,
      'intervalDays': reviews == 0 ? 0 : 4,
      'lapses': reviews > 0 && n % 5 == 0 ? 1 : 0,
      'lastReviewedAt': reviews == 0
          ? ''
          : at(due.subtract(const Duration(days: 4))),
    });
  }

  for (var i = 0; i < _words.length; i++) {
    final (q, a) = _words[i];
    s = saveCard(
      s,
      card('n3', q, a, _offsets[i % _offsets.length], reviews: i > 20 ? 0 : 2),
    );
  }
  const anatomy = [
    ('Cơ nào gập khuỷu tay?', 'Cơ nhị đầu cánh tay', 0),
    ('Xương dài nhất cơ thể?', 'Xương đùi', 2),
    ('Van nào giữa nhĩ trái và thất trái?', 'Van hai lá', 5),
    ('Thần kinh sọ số VII?', 'Thần kinh mặt', 8),
  ];
  for (final (q, a, d) in anatomy) {
    s = saveCard(s, card('anat', q, a, d));
  }
  s = saveCard(
    s,
    createCard(
      id: 'pic',
      deckId: 'anat',
      front: 'Bốn ngăn của tim: hai ngăn nào đang bị che?',
      back: 'Trên trái: tâm nhĩ phải · Dưới phải: tâm thất trái',
      now: at(now.subtract(const Duration(hours: 2))),
      image: RecallImage(
        dataUri: picture,
        masks: const [
          OcclusionMask(x: .06, y: .11, width: .38, height: .34),
          OcclusionMask(x: .56, y: .55, width: .38, height: .34),
        ],
      ),
    ),
  );
  s = saveCard(
    s,
    card(
      'ielts',
      'Linking: contrast',
      'However, / Nevertheless, / On the other hand,',
      18,
    ),
  );
  s = saveCard(
    s,
    card(
      'ielts',
      'Task 2: thesis',
      'State your position in one sentence at the end of the intro.',
      18,
    ),
  );
  return s;
}

/// Japanese with read-aloud on both sides: a reverse pair and two clozes.
RecallState nihongo() {
  var s = saveDeck(
    emptyRecallState(),
    const RecallDeck(
      id: 'jp',
      name: 'Tiếng Nhật N3',
      reverse: true,
      speakFront: 'ja-JP',
      speakBack: 'vi-VN',
    ),
  );
  var n = 0;
  String id() => 'jp${++n}';
  final due = at(now.subtract(const Duration(hours: 1)));
  s = saveNote(
    s,
    deckId: 'jp',
    front: '{{c1::東京}}は{{c2::首都::thủ đô}}です。',
    back: 'Tokyo là thủ đô.',
    newId: id,
    now: due,
  );
  s = saveNote(
    s,
    deckId: 'jp',
    front: '届ける (とどける)',
    back: 'gửi đến, chuyển tới',
    reverse: true,
    newId: id,
    now: due,
  );
  return s;
}

Future<void> boot(
  WidgetTester t,
  Size size, {
  String theme = 'light',
  RecallState? state,
  Files? files,
  FakeSpeaker? speaker,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final picture = (await t.runAsync(diagram))!;
  await t.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: RecallApp(
        documents: Store()
          ..text = exportRecallBackup(state ?? library(picture)),
        files: files ?? Files(),
        preferences: Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: theme),
        reminders: testReminders(),
        speaker: speaker ?? FakeSpeaker(),
        clock: () => now,
      ),
    ),
  );
  await t.pumpAndSettle();
}

/// Grades every card of the session as "Got it" until it ends.
Future<void> finish(WidgetTester t) async {
  while (find.byKey(const Key('review-show')).evaluate().isNotEmpty) {
    await tapKey(t, 'review-show');
    await tapKey(t, 'grade-good');
  }
}

void main() {
  setUpAll(() async {
    const ui = '../../packages/handy_ui/fonts';
    await _font('packages/handy_ui/Geist', [
      '$ui/Geist-Regular.ttf',
      '$ui/Geist-Medium.ttf',
      '$ui/Geist-Bold.ttf',
    ]);
    await _font('packages/handy_ui/GeistMono', ['$ui/GeistMono-Regular.ttf']);
    await _font('packages/handy_ui/Bricolage', [
      '$ui/BricolageGrotesque-Medium.ttf',
      '$ui/BricolageGrotesque-Display.ttf',
    ]);
    // Japanese cards: the system face the kit falls back to on Windows.
    const yu = r'C:\Windows\Fonts\YuGothM.ttc';
    if (File(yu).existsSync()) await _font('Yu Gothic', [yu]);
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    await _font('Lexend', [
      for (final f in Directory('fonts').listSync())
        if (f.path.endsWith('.ttf')) f.path,
    ]);
    await _font('MaterialIcons', [
      '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  });

  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('tablet', const Size(768, 1024)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label today', (t) async {
      await boot(t, size);
      await shot(t, '$label-1-today');
    });
    testWidgets('$label review', (t) async {
      await boot(t, size);
      await tapKey(t, 'study-start');
      await shot(t, '$label-2-question');
      await tapKey(t, 'review-show');
      await shot(t, '$label-3-answer');
    });
    testWidgets('$label dictation', (t) async {
      await boot(
        t,
        size,
        state: saveCard(
          saveDeck(
            emptyRecallState(),
            const RecallDeck(id: 'en', name: 'Tiếng Anh', speakBack: 'en-US'),
          ),
          createCard(
            id: 'c1',
            deckId: 'en',
            front: 'Tôi đã từng đến Hà Nội hai lần',
            back: 'I have been to Hanoi twice',
            now: at(now.subtract(const Duration(hours: 1))),
          ),
        ),
      );
      await tapKey(t, 'study-start');
      await tapKey(t, 'review-dictation');
      await t.enterText(
        find.byKey(const Key('dictation-input')),
        'I have bean to Hanoi',
      );
      await t.pumpAndSettle();
      await shot(t, '$label-2b-dictation');
      await tapKey(t, 'dictation-check');
      await shot(t, '$label-2c-dictation-checked');
    });
    testWidgets('$label deck', (t) async {
      await boot(t, size);
      await tapKey(t, 'deck-n3');
      await shot(t, '$label-4-deck');
    });
  }
  testWidgets('phone picture card', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'deck-review-anat');
    while (find.byKey(const Key('occlusion-surface')).evaluate().isEmpty &&
        find.byKey(const Key('review-show')).evaluate().isNotEmpty) {
      await tapKey(t, 'review-show');
      await tapKey(t, 'grade-good');
    }
    await shot(t, 'phone-5-picture');
    await tapKey(t, 'review-show');
    await shot(t, 'phone-6-picture-answer');
  });
  testWidgets('phone editor', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'deck-anat');
    await tapKey(t, 'card-pic');
    await shot(t, 'phone-7-editor');
  });
  testWidgets('phone done', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'deck-review-anat');
    await finish(t);
    await shot(t, 'phone-8-done');
  });
  testWidgets('desktop settings', (t) async {
    await boot(t, const Size(1440, 900));
    await tapKey(t, 'open-settings');
    await shot(t, 'desktop-9-settings');
  });
  testWidgets('phone dark', (t) async {
    await boot(t, const Size(390, 844), theme: 'dark');
    await shot(t, 'phone-10-dark');
  });
  testWidgets('phone empty', (t) async {
    await boot(t, const Size(390, 844), state: emptyRecallState());
    await shot(t, 'phone-11-empty');
  });
  testWidgets('phone cloze', (t) async {
    await boot(t, const Size(390, 844), state: nihongo());
    await tapKey(t, 'study-start');
    await shot(t, 'phone-12-cloze');
    await tapKey(t, 'review-show');
    await shot(t, 'phone-13-cloze-answer');
  });
  testWidgets('phone reverse card', (t) async {
    await boot(t, const Size(390, 844), state: nihongo());
    await tapKey(t, 'deck-review-jp');
    while (find.byKey(const Key('review-reversed')).evaluate().isEmpty) {
      await tapKey(t, 'review-show');
      await tapKey(t, 'grade-good');
    }
    await shot(t, 'phone-14-reverse');
  });
  testWidgets('phone editor cloze', (t) async {
    await boot(t, const Size(390, 844), state: nihongo());
    await tapKey(t, 'deck-jp');
    await tapKey(t, 'card-jp2');
    await shot(t, 'phone-15-editor-cloze');
  });
  testWidgets('phone editor new card with reverse', (t) async {
    await boot(t, const Size(390, 844), state: nihongo());
    await tapKey(t, 'deck-jp');
    await tapKey(t, 'card-new');
    await t.enterText(find.byKey(const Key('card-front')), '比べる (くらべる)');
    await t.enterText(find.byKey(const Key('card-back')), 'so sánh');
    await t.pumpAndSettle();
    await shot(t, 'phone-16-editor-reverse');
  });
  testWidgets('phone deck settings', (t) async {
    await boot(t, const Size(390, 844), state: nihongo());
    await tapKey(t, 'deck-jp');
    await tapKey(t, 'more-menu');
    await tapKey(t, 'deck-rename');
    await shot(t, 'phone-17-deck-settings');
  });
  testWidgets('phone deck settings without voices', (t) async {
    await boot(
      t,
      const Size(390, 844),
      state: nihongo(),
      speaker: FakeSpeaker([]),
    );
    await tapKey(t, 'deck-new');
    await shot(t, 'phone-18-no-voices');
  });
  for (final (label, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('$label anki preview', (t) async {
      final package = apkg();
      await boot(
        t,
        size,
        files: Files()..bytes = ImportedBytes('spanish.apkg', package),
      );
      await tapKey(t, 'anki-open');
      await shot(t, '$label-19-anki-preview');
    });
  }
  testWidgets('phone anki not a package', (t) async {
    await boot(
      t,
      const Size(390, 844),
      files: Files()
        ..bytes = ImportedBytes('notes.apkg', Uint8List.fromList([1, 2, 3])),
    );
    await tapKey(t, 'anki-open');
    await shot(t, 'phone-20-anki-error');
  });
  testWidgets('narrow 320 today and empty', (t) async {
    await boot(t, const Size(320, 640));
    await shot(t, 'narrow-21-today');
    await boot(t, const Size(320, 640), state: emptyRecallState());
    await shot(t, 'narrow-22-empty');
  });
  testWidgets('desktop editor cloze', (t) async {
    await boot(t, const Size(1440, 900), state: nihongo());
    await tapKey(t, 'deck-jp');
    await tapKey(t, 'card-jp2');
    await shot(t, 'desktop-23-editor-cloze');
  });
  testWidgets('films', (t) async {
    await boot(t, const Size(390, 844));
    await film(t, 'phone-start', () async {
      await t.tap(find.byKey(const Key('study-start')));
      await t.pump();
    });
    await film(t, 'phone-reveal', () async {
      await t.tap(find.byKey(const Key('review-show')));
      await t.pump();
    });
    await film(t, 'phone-next-card', () async {
      await t.tap(find.byKey(const Key('grade-good')));
      await t.pump();
    }, frames: 20);
  });

  testWidgets('phone paste notes', (t) async {
    await boot(t, const Size(390, 844));
    await tapKey(t, 'deck-n3');
    await t.tap(find.byType(HandyMenuButton).last);
    await t.pumpAndSettle();
    await tapKey(t, 'deck-paste');
    await t.enterText(
      find.byKey(const Key('paste-text')),
      '- 食べる – ăn\n- 飲む – uống\n読む: đọc\nMột dòng ghi chú không có đáp án',
    );
    await t.pumpAndSettle();
    await shot(t, 'phone-21-paste');
  });
}
