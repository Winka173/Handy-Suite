part of 'cover_art.dart';

void _paintAbstract(_Art a, int v) {
  switch (v) {
    case 0:
      a.oval(244, 233, 115, 115, a.i);
      a.rect(294, 123, 78, 159, a.s, 39);
      a.poly([326, 282, 415, 282, 415, 174], a.b);
      a.line(190, 284, 420, 284, a.i, 2);
      a.oval(267, 122, 31, 31, a.b);
    case 1:
      a.oval(300, 200, 203, 203, a.s);
      a.c.save();
      a.c.clipRect(const Rect.fromLTWH(300, 90, 120, 220));
      a.oval(300, 200, 203, 203, a.i);
      a.c.restore();
      a.turn(300, 200, -.65, () {
        a.rect(-124, -13, 248, 26, a.b);
      });
      a.oval(300, 200, 57, 57, a.g);
      a.line(200, 290, 238, 263, a.i, 2);
    case 2:
      for (var n = 0; n < 6; n++) {
        final d = n * 19.0;
        a.curve(
          [
            179 - d,
            281 + d,
            175 - d,
            119 - d,
            419 + d,
            310 + d,
            421 + d,
            118 - d,
          ],
          n.isEven ? a.i : a.s,
          10,
        );
      }
      a.oval(326, 173, 30, 30, a.b);
    case 3:
      a.poly([177, 222, 257, 120, 299, 222, 258, 282], a.b);
      a.poly([257, 120, 337, 162, 299, 222], a.i);
      a.poly([299, 222, 337, 162, 423, 194, 343, 281], a.s);
      a.poly([177, 222, 258, 282, 343, 281, 299, 222], a.i);
      a.line(257, 120, 299, 222, a.g, 2);
      a.line(299, 222, 343, 281, a.g, 2);
    case 4:
      for (var n = 0; n < 3; n++) {
        final x = 204 + n * 69.0, top = 161 - n * 18.0;
        a.arc(x + 29, top, 58, 77, math.pi, math.pi, n == 1 ? a.b : a.i, 16);
        a.line(x, top, x, 279, n == 1 ? a.b : a.i, 16);
        a.line(x + 58, top, x + 58, 279, n == 1 ? a.b : a.i, 16);
      }
      a.rect(181, 284, 246, 10, a.s, 3);
      a.oval(410, 134, 23, 23, a.b);
    case 5:
      a.tiles(72, (tx, y, row, col) {
        final x = tx + (row.isEven ? 0 : 36);
        if ((col + row) % 3 != 0) {
          a.rect(x + 6, y + 6, 60, 60, (col + row).isEven ? a.i : a.s, 3);
          a.rect(x + 12, y + 12, 19, 19, a.b, 1);
        }
      });
  }
}
