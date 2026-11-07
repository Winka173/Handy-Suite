import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  test(
    'catalog has stable unique bilingual identities and a generous free set',
    () {
      expect(coverCatalog.length, greaterThanOrEqualTo(60));
      expect(
        coverCatalog.where((c) => !c.pro).length,
        greaterThanOrEqualTo(30),
      );
      expect(coverCatalog.map((c) => c.id).toSet().length, coverCatalog.length);
      for (final c in coverCatalog) {
        expect(c.id, matches(RegExp(r'^[a-z]+\.[a-z]+(?:-[a-z]+)*$')));
        expect(c.id.split('.').first, c.family.name);
        expect(c.nameEn.trim(), isNotEmpty);
        expect(c.nameVi.trim(), isNotEmpty);
        expect(c.provenance, 'original procedural');
        expect(coverById(c.id), same(c));
      }
      expect(coverById(null), isNull);
      expect(coverById('unknown.cover'), isNull);
      expect(coverById(''), isNull);
    },
  );

  for (final f in CoverFamily.values) {
    test('${f.name} has six distinct choices and three free choices', () {
      final covers = coversIn(f).toList();
      expect(covers.length, inInclusiveRange(6, 7));
      expect(covers.where((c) => !c.pro).length, greaterThanOrEqualTo(3));
      expect(covers.map((c) => c.nameEn).toSet().length, covers.length);
      expect(covers.map((c) => c.nameVi).toSet().length, covers.length);
      expect(familyNameEn(f).trim(), isNotEmpty);
      expect(familyNameVi(f).trim(), isNotEmpty);
    });
  }
}
