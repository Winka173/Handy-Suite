part of 'cover_art.dart';

void _paintHome(_Art a, int v) {
  switch (v) {
    case 0:
      a.rect(222, 167, 156, 113, a.i);
      a.oval(300, 167, 156, 145, a.i);
      a.rect(235, 167, 130, 100, a.s);
      a.arc(300, 167, 130, 119, math.pi, math.pi, a.s, 13);
      a.line(300, 111, 300, 269, a.g, 6);
      a.line(235, 184, 365, 184, a.g, 6);
      a.rect(209, 277, 182, 10, a.b, 2);
      a.sprig(405, 257, 76, a.i);
      a.poly([385, 253, 425, 253, 418, 286, 392, 286], a.b);
    case 1:
      // Broad warp and weft: textile rather than another object illustration.
      for (
        var n = (a.bounds.left / 35).floor();
        n <= (a.bounds.right / 35).ceil();
        n++
      ) {
        a.rect(n * 35.0, a.bounds.top, 17, a.bounds.height, a.s);
      }
      final weft = a.i.withValues(alpha: .22);
      for (
        var n = (a.bounds.top / 35).floor();
        n <= (a.bounds.bottom / 35).ceil();
        n++
      ) {
        a.rect(a.bounds.left, n * 35.0, a.bounds.width, 12, weft);
      }
      a.turn(305, 204, .17, () {
        a.rect(-88, -58, 176, 116, a.g, 3);
        for (var n = 0; n < 7; n++) {
          a.line(-80, -46 + n * 15, 80, -46 + n * 15, a.i, 1);
        }
        for (var n = 0; n < 11; n++) {
          a.line(-74 + n * 15, -53, -74 + n * 15, 53, a.s, 2);
        }
        for (var n = 0; n < 10; n++) {
          a.line(-74 + n * 17, 58, -77 + n * 17, 70, a.b, 2);
        }
      });
    case 2:
      a.tiles(80, (tx, y, row, col) {
        final x = tx + 20;
        a.rect(x + 3, y + 3, 74, 74, a.s, 2);
        a.leaf(x + 40, y + 40, 29, -math.pi / 2, a.i);
        a.leaf(x + 40, y + 40, 29, math.pi / 2, a.i);
        a.leaf(x + 40, y + 40, 29, 0, a.b);
        a.leaf(x + 40, y + 40, 29, math.pi, a.b);
      });
    case 3:
      a.rect(-2000, 282, 4000, 2000, a.s);
      a.rect(236, 181, 122, 91, a.b, 25);
      a.rect(226, 229, 145, 29, a.b, 9);
      a.line(244, 258, 238, 282, a.i, 6);
      a.line(351, 258, 359, 282, a.i, 6);
      a.rect(258, 197, 70, 46, a.s, 8);
      a.line(397, 281, 397, 142, a.i, 5);
      a.poly([365, 151, 429, 151, 414, 112, 380, 112], a.s);
      a.book(172, 245, 40, 12, a.i);
      a.line(192, 257, 192, 282, a.i, 5);
    case 4:
      a.poly([191, 281, 191, 135, 263, 105, 263, 281], a.i);
      a.poly([263, 281, 263, 105, 409, 135, 409, 281], a.s);
      a.rect(292, 190, 68, 91, a.b);
      a.oval(326, 190, 68, 77, a.b);
      a.line(265, 281, 415, 308, a.b, 3);
      a.line(211, 301, 355, 301, a.b, 2);
      a.sprig(224, 258, 86, a.s);
      a.poly([203, 251, 245, 251, 239, 281, 210, 281], a.b);
    case 5:
      a.tiles(96, (x, y, row, col) {
        a.rect(x + 2, y + 2, 92, 92, (row + col).isEven ? a.s : a.i);
        a.poly([x + 2, y + 2, x + 94, y + 2, x + 2, y + 94], a.b);
        a.line(x + 8, y + 8, x + 87, y + 87, a.g, 2);
      });
  }
}
