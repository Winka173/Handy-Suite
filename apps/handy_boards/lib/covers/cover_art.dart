import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

part 'drawing.dart';
part 'study.dart';
part 'work.dart';
part 'goals.dart';
part 'shopping.dart';
part 'home.dart';
part 'creative.dart';
part 'travel.dart';
part 'events.dart';
part 'wellness.dart';
part 'abstract.dart';

/// Offline artwork. The host supplies bounded width and height.
class CoverArt extends StatelessWidget {
  final String? id;
  const CoverArt(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    final def = coverById(id);
    final vi = Localizations.maybeLocaleOf(context)?.languageCode == 'vi';
    return Semantics(
      image: true,
      label: def == null
          ? (vi ? 'Hình nền trung tính' : 'Neutral cover')
          : (vi ? def.nameVi : def.nameEn),
      child: RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            painter: _CoverPainter(id),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Dominant ground colour, including the fallback for null/unknown IDs.
Color coverTone(String? id) => switch (id) {
  'home.garden-tiles' => const Color(0xFFE7DDC4),
  'home.quilt-blocks' => const Color(0xFFBD886B),
  _ => (_styles[id] ?? _fallback).ground,
};

class _Style {
  final CoverFamily family;
  final int variant;
  final Color ground, ink, accent, soft;
  const _Style(
    this.family,
    this.variant,
    this.ground,
    this.ink,
    this.accent,
    this.soft,
  );
}

const _fallback = _Style(
  CoverFamily.abstract,
  -1,
  Color(0xFFD3D9CF),
  Color(0xFF6B7C70),
  Color(0xFFB3BDAA),
  Color(0xFFE5E7DC),
);
const _styles = <String, _Style>{
  'study.notebook-grid': _Style(
    CoverFamily.study,
    0,
    Color(0xFFE4EBDD),
    Color(0xFF527566),
    Color(0xFFCB895B),
    Color(0xFFF4EEDB),
  ),
  'study.open-book': _Style(
    CoverFamily.study,
    1,
    Color(0xFFD9B394),
    Color(0xFF4E5148),
    Color(0xFFA55843),
    Color(0xFFEEE2C7),
  ),
  'study.pencil-case': _Style(
    CoverFamily.study,
    2,
    Color(0xFF293F38),
    Color(0xFFB9C8AE),
    Color(0xFFD4A75A),
    Color(0xFF40594D),
  ),
  'study.orbital-notes': _Style(
    CoverFamily.study,
    3,
    Color(0xFFDCDDD1),
    Color(0xFF58767A),
    Color(0xFFBF7756),
    Color(0xFFF0E7CE),
  ),
  'study.library-steps': _Style(
    CoverFamily.study,
    4,
    Color(0xFFCBC0A7),
    Color(0xFF4F6554),
    Color(0xFFB77751),
    Color(0xFFE4D8C0),
  ),
  'study.geometry-set': _Style(
    CoverFamily.study,
    5,
    Color(0xFF423C34),
    Color(0xFFC4B898),
    Color(0xFFC79761),
    Color(0xFF625448),
  ),
  'work.folder-stack': _Style(
    CoverFamily.work,
    0,
    Color(0xFFD9E3DC),
    Color(0xFF496B63),
    Color(0xFFBD7A55),
    Color(0xFFF0DDB4),
  ),
  'work.desk-light': _Style(
    CoverFamily.work,
    1,
    Color(0xFFDCC7B2),
    Color(0xFF455C59),
    Color(0xFFC38A54),
    Color(0xFFEEE1C6),
  ),
  'work.sticky-plan': _Style(
    CoverFamily.work,
    2,
    Color(0xFFE8DAB7),
    Color(0xFF666C4F),
    Color(0xFFB66C52),
    Color(0xFFC6D2BD),
  ),
  'work.paper-clips': _Style(
    CoverFamily.work,
    3,
    Color(0xFF304843),
    Color(0xFFB2C6B7),
    Color(0xFFD9AF6B),
    Color(0xFF52695C),
  ),
  'work.architect-desk': _Style(
    CoverFamily.work,
    4,
    Color(0xFFD7DDE0),
    Color(0xFF536C76),
    Color(0xFFB67759),
    Color(0xFFECE6D5),
  ),
  'work.inbox-trays': _Style(
    CoverFamily.work,
    5,
    Color(0xFFB8C5B3),
    Color(0xFF435E4E),
    Color(0xFFB5754E),
    Color(0xFFE5D7BA),
  ),
  'goals.summit-path': _Style(
    CoverFamily.goals,
    0,
    Color(0xFFDADFCF),
    Color(0xFF536954),
    Color(0xFFBB7758),
    Color(0xFFEDE3C9),
  ),
  'goals.stepping-stones': _Style(
    CoverFamily.goals,
    1,
    Color(0xFFB9D0CA),
    Color(0xFF3D6965),
    Color(0xFFC39661),
    Color(0xFFE9DFC5),
  ),
  'goals.growing-branch': _Style(
    CoverFamily.goals,
    2,
    Color(0xFFE5D3B2),
    Color(0xFF52745B),
    Color(0xFFAF684B),
    Color(0xFFC3CD9F),
  ),
  'goals.target-rings': _Style(
    CoverFamily.goals,
    3,
    Color(0xFF443D35),
    Color(0xFFBDB197),
    Color(0xFFCB9866),
    Color(0xFF675743),
  ),
  'goals.milestone-flags': _Style(
    CoverFamily.goals,
    4,
    Color(0xFFCFDDE0),
    Color(0xFF526E78),
    Color(0xFFB2674C),
    Color(0xFFEEE3C9),
  ),
  'goals.sunrise-stairs': _Style(
    CoverFamily.goals,
    5,
    Color(0xFFD9B99B),
    Color(0xFF5D6751),
    Color(0xFFAF654B),
    Color(0xFFEDCCA0),
  ),
  'shopping.market-tote': _Style(
    CoverFamily.shopping,
    0,
    Color(0xFFDCDDC5),
    Color(0xFF536A50),
    Color(0xFFB67C4D),
    Color(0xFFEFE4CB),
  ),
  'shopping.wrapped-parcel': _Style(
    CoverFamily.shopping,
    1,
    Color(0xFFD4B99F),
    Color(0xFF775546),
    Color(0xFF557269),
    Color(0xFFE9D5B3),
  ),
  'shopping.wish-shelf': _Style(
    CoverFamily.shopping,
    2,
    Color(0xFFBCD0CD),
    Color(0xFF496962),
    Color(0xFFC28359),
    Color(0xFFEBD8B6),
  ),
  'shopping.ceramic-picks': _Style(
    CoverFamily.shopping,
    3,
    Color(0xFFE3C5B5),
    Color(0xFF795747),
    Color(0xFFA47A50),
    Color(0xFFEEE0C4),
  ),
  'shopping.pantry-jars': _Style(
    CoverFamily.shopping,
    4,
    Color(0xFF415748),
    Color(0xFFBAC5A0),
    Color(0xFFC59C63),
    Color(0xFFD7D4B0),
  ),
  'shopping.fabric-swatches': _Style(
    CoverFamily.shopping,
    5,
    Color(0xFFDAD3BC),
    Color(0xFF5C7266),
    Color(0xFFB47862),
    Color(0xFFB6C2A2),
  ),
  'home.arched-window': _Style(
    CoverFamily.home,
    0,
    Color(0xFFE1CCB6),
    Color(0xFF5C7267),
    Color(0xFFB57851),
    Color(0xFFAABCAF),
  ),
  'home.woven-linen': _Style(
    CoverFamily.home,
    1,
    Color(0xFFD6C8AD),
    Color(0xFF9E8D70),
    Color(0xFF697D69),
    Color(0xFFE8DEC8),
  ),
  'home.garden-tiles': _Style(
    CoverFamily.home,
    2,
    Color(0xFFC1CFBD),
    Color(0xFF4A6A59),
    Color(0xFFB67C55),
    Color(0xFFE7DDC4),
  ),
  'home.reading-corner': _Style(
    CoverFamily.home,
    3,
    Color(0xFFBFC9BF),
    Color(0xFF49665B),
    Color(0xFFBA8259),
    Color(0xFFE7D7BA),
  ),
  'home.courtyard': _Style(
    CoverFamily.home,
    4,
    Color(0xFFCDB394),
    Color(0xFF6C6551),
    Color(0xFF8C9D72),
    Color(0xFFE7CDA6),
  ),
  'home.quilt-blocks': _Style(
    CoverFamily.home,
    5,
    Color(0xFF55483E),
    Color(0xFFB3AC8F),
    Color(0xFFBD886B),
    Color(0xFF6D7560),
  ),
  'creative.paper-collage': _Style(
    CoverFamily.creative,
    0,
    Color(0xFFDFD4BB),
    Color(0xFF4F7166),
    Color(0xFFBC7254),
    Color(0xFFB8C8AA),
  ),
  'creative.paint-palette': _Style(
    CoverFamily.creative,
    1,
    Color(0xFFD7C3AE),
    Color(0xFF587568),
    Color(0xFFBE6B52),
    Color(0xFFECDDAB),
  ),
  'creative.cutout-garden': _Style(
    CoverFamily.creative,
    2,
    Color(0xFFBED0C1),
    Color(0xFF467261),
    Color(0xFFC28256),
    Color(0xFFE5CEA4),
  ),
  'creative.ceramic-studio': _Style(
    CoverFamily.creative,
    3,
    Color(0xFFCBAF96),
    Color(0xFF715347),
    Color(0xFFA86A4C),
    Color(0xFFE3CBA8),
  ),
  'creative.ribbon-weave': _Style(
    CoverFamily.creative,
    4,
    Color(0xFF334C49),
    Color(0xFFAFBFA8),
    Color(0xFFD09B72),
    Color(0xFF627B68),
  ),
  'creative.printing-blocks': _Style(
    CoverFamily.creative,
    5,
    Color(0xFFDDCFAD),
    Color(0xFF586D5A),
    Color(0xFFAB5C49),
    Color(0xFFBCC8A4),
  ),
  'travel.coastal-route': _Style(
    CoverFamily.travel,
    0,
    Color(0xFFC1D6D2),
    Color(0xFF477D78),
    Color(0xFFC69162),
    Color(0xFFE9D9B6),
  ),
  'travel.mountain-pass': _Style(
    CoverFamily.travel,
    1,
    Color(0xFFD3DCCF),
    Color(0xFF4D7060),
    Color(0xFFA78356),
    Color(0xFFA4BAA2),
  ),
  'travel.city-arches': _Style(
    CoverFamily.travel,
    2,
    Color(0xFFD5BA9D),
    Color(0xFF6F6652),
    Color(0xFFAD6D4C),
    Color(0xFFE9D4AF),
  ),
  'travel.folded-map': _Style(
    CoverFamily.travel,
    3,
    Color(0xFFDBDCC3),
    Color(0xFF668371),
    Color(0xFFB67450),
    Color(0xFFB3C6B5),
  ),
  'travel.night-train': _Style(
    CoverFamily.travel,
    4,
    Color(0xFF263E3D),
    Color(0xFF9EB8AA),
    Color(0xFFC89C63),
    Color(0xFF47625A),
  ),
  'travel.island-harbour': _Style(
    CoverFamily.travel,
    5,
    Color(0xFFB5CECB),
    Color(0xFF42736C),
    Color(0xFFB57B50),
    Color(0xFFE8D0A7),
  ),
  'events.ticket-pair': _Style(
    CoverFamily.events,
    0,
    Color(0xFFDFCCB1),
    Color(0xFF72614C),
    Color(0xFFA9634D),
    Color(0xFFA8BAA5),
  ),
  'events.garden-table': _Style(
    CoverFamily.events,
    1,
    Color(0xFFBDCCB1),
    Color(0xFF526F51),
    Color(0xFFB17C53),
    Color(0xFFEADABD),
  ),
  'events.paper-lanterns': _Style(
    CoverFamily.events,
    2,
    Color(0xFF374E42),
    Color(0xFFB5C29B),
    Color(0xFFCE9B67),
    Color(0xFF60765A),
  ),
  'events.confetti-cutouts': _Style(
    CoverFamily.events,
    3,
    Color(0xFFE3D5BA),
    Color(0xFF547064),
    Color(0xFFB76F50),
    Color(0xFFB4C8A2),
  ),
  'events.ribbon-invite': _Style(
    CoverFamily.events,
    4,
    Color(0xFFD8B6A2),
    Color(0xFF825B4F),
    Color(0xFF526E61),
    Color(0xFFEBD8B8),
  ),
  'events.stage-curtain': _Style(
    CoverFamily.events,
    5,
    Color(0xFF553E33),
    Color(0xFFBEA080),
    Color(0xFFC4885B),
    Color(0xFF795444),
  ),
  'wellness.quiet-waves': _Style(
    CoverFamily.wellness,
    0,
    Color(0xFFB7CFCC),
    Color(0xFF477A72),
    Color(0xFFC69F6A),
    Color(0xFFE6DABF),
  ),
  'wellness.morning-leaves': _Style(
    CoverFamily.wellness,
    1,
    Color(0xFFD5DCC0),
    Color(0xFF53764F),
    Color(0xFFB58B57),
    Color(0xFFE9DFC1),
  ),
  'wellness.tea-ritual': _Style(
    CoverFamily.wellness,
    2,
    Color(0xFFD9C8AB),
    Color(0xFF657653),
    Color(0xFFAA7351),
    Color(0xFFEBDDCA),
  ),
  'wellness.pebble-balance': _Style(
    CoverFamily.wellness,
    3,
    Color(0xFFCCD2C5),
    Color(0xFF667869),
    Color(0xFFA59071),
    Color(0xFFE8DDC4),
  ),
  'wellness.breathing-orbits': _Style(
    CoverFamily.wellness,
    4,
    Color(0xFF304A42),
    Color(0xFFABC1A5),
    Color(0xFFD2AA72),
    Color(0xFF52705B),
  ),
  'wellness.sun-salutation': _Style(
    CoverFamily.wellness,
    5,
    Color(0xFFE2C59D),
    Color(0xFF8C7552),
    Color(0xFFB57149),
    Color(0xFFEFE0BC),
  ),
  'abstract.balanced-forms': _Style(
    CoverFamily.abstract,
    0,
    Color(0xFFDAD2B8),
    Color(0xFF4F6C60),
    Color(0xFFBA7653),
    Color(0xFFB9C6A1),
  ),
  'abstract.split-circle': _Style(
    CoverFamily.abstract,
    1,
    Color(0xFFBBCBC1),
    Color(0xFF476B61),
    Color(0xFFBD865B),
    Color(0xFFE5D5B1),
  ),
  'abstract.terrace-lines': _Style(
    CoverFamily.abstract,
    2,
    Color(0xFFD3B99A),
    Color(0xFF7C5D45),
    Color(0xFF536F5D),
    Color(0xFFE8D4B2),
  ),
  'abstract.folded-rhythm': _Style(
    CoverFamily.abstract,
    3,
    Color(0xFF3C4F45),
    Color(0xFFA3B595),
    Color(0xFFCA9B70),
    Color(0xFF637C65),
  ),
  'abstract.sculpted-arches': _Style(
    CoverFamily.abstract,
    4,
    Color(0xFFD9CFBC),
    Color(0xFF6D7864),
    Color(0xFFB57C5B),
    Color(0xFFB4C0A5),
  ),
  'abstract.offset-checks': _Style(
    CoverFamily.abstract,
    5,
    Color(0xFFD8C5AE),
    Color(0xFF5C7569),
    Color(0xFFAC6C50),
    Color(0xFFE9DBC0),
  ),
};

class _CoverPainter extends CustomPainter {
  final String? id;
  const _CoverPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = _styles[id] ?? _fallback;
    canvas.drawRect(Offset.zero & size, Paint()..color = style.ground);
    canvas.save();
    // Recompose the foreground inside a central 370 × 240 safe frame.
    // The ground and large scene bands bleed to every edge at any aspect.
    final scale = math.min(size.width / 370, size.height / 240);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-300, -200);
    final a = _Art(
      canvas,
      style,
      Rect.fromCenter(
        center: const Offset(300, 200),
        width: size.width / scale,
        height: size.height / scale,
      ),
    );
    if (style.variant < 0) {
      a.oval(260, 200, 150, 90, a.s);
      a.oval(340, 210, 110, 65, a.b);
      a.line(240, 235, 365, 235, a.i, 2);
    } else {
      switch (style.family) {
        case CoverFamily.study:
          _paintStudy(a, style.variant);
        case CoverFamily.work:
          _paintWork(a, style.variant);
        case CoverFamily.goals:
          _paintGoals(a, style.variant);
        case CoverFamily.shopping:
          _paintShopping(a, style.variant);
        case CoverFamily.home:
          _paintHome(a, style.variant);
        case CoverFamily.creative:
          _paintCreative(a, style.variant);
        case CoverFamily.travel:
          _paintTravel(a, style.variant);
        case CoverFamily.events:
          _paintEvents(a, style.variant);
        case CoverFamily.wellness:
          _paintWellness(a, style.variant);
        case CoverFamily.abstract:
          _paintAbstract(a, style.variant);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      id != oldDelegate.id;
}
