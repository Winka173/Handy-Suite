part of 'cover_art.dart';

void _paintEvents(_Art a, int v) {
  switch (v) {
    case 0:
      a.turn(272, 190, -.23, () {
        a.rect(-97, -48, 194, 96, a.i, 8);
        a.oval(-97, 0, 18, 18, a.g);
        a.oval(97, 0, 18, 18, a.g);
        for (var n = 0; n < 6; n++) {
          a.line(48, -38 + n * 14, 48, -32 + n * 14, a.s, 2);
        }
        a.star(-22, 0, 26, a.s);
      });
      a.turn(333, 231, .12, () {
        a.rect(-87, -43, 174, 86, a.b, 8);
        a.oval(-87, 0, 16, 16, a.g);
        a.oval(87, 0, 16, 16, a.g);
        for (var n = 0; n < 5; n++) {
          a.line(39, -32 + n * 14, 39, -26 + n * 14, a.s, 2);
        }
        a.oval(-21, 0, 41, 41, a.s, 3);
      });
    case 1:
      a.rect(195, 210, 211, 16, a.b, 3);
      a.line(215, 226, 208, 280, a.i, 7);
      a.line(386, 226, 393, 280, a.i, 7);
      a.rect(205, 215, 191, 12, a.s, 2);
      for (final x in [235.0, 363.0]) {
        a.oval(x, 200, 39, 16, a.s);
        a.line(x, 173, x, 192, a.i, 2);
        a.oval(x, 167, 14, 17, a.s, 2);
      }
      a.rect(282, 177, 37, 34, a.s, 6);
      a.sprig(300, 178, 62, a.i);
      a.curve([170, 123, 235, 162, 355, 92, 432, 132], a.i, 2);
      for (var n = 0; n < 7; n++) {
        a.oval(192 + n * 35, 134 + math.sin(n) * 10, 6, 6, a.b);
      }
    case 2:
      a.curve([161, 112, 253, 165, 352, 85, 441, 129], a.i, 2);
      for (final (x, y, w, h, col) in [
        (225.0, 182.0, 59.0, 83.0, a.b),
        (310.0, 201.0, 72.0, 102.0, a.i),
        (393.0, 174.0, 49.0, 68.0, a.b),
      ]) {
        a.line(x, 128, x, y - h / 2, col, 2);
        a.oval(x, y, w, h, col);
        for (var n = -1; n <= 1; n++) {
          a.arc(x + n * 7, y, w * .36, h, math.pi / 2, math.pi, a.g, 1.5);
        }
        a.rect(x - 12, y + h / 2 - 5, 24, 9, a.s, 2);
        a.line(x, y + h / 2 + 4, x, y + h / 2 + 22, a.s, 2);
      }
    case 3:
      a.oval(302, 203, 120, 120, a.s);
      for (var n = 0; n < 15; n++) {
        final angle = n * 2.39996, radius = 86 + (n % 3) * 21.0;
        final x = 300 + math.cos(angle) * radius,
            y = 200 + math.sin(angle) * radius * .65;
        a.turn(x, y, angle, () {
          if (n % 3 == 0) {
            a.poly([-9, 9, 9, 9, 0, -12], a.b);
          } else if (n % 3 == 1) {
            a.rect(-5, -12, 10, 24, a.i, 2);
          } else {
            a.arc(0, 0, 21, 21, 0, math.pi, a.b, 5);
          }
        });
      }
      a.star(302, 203, 39, a.b);
      a.oval(302, 203, 16, 16, a.s);
    case 4:
      a.turn(300, 208, -.08, () {
        a.rect(-108, -77, 216, 154, a.s, 4);
        a.rect(-92, -61, 184, 122, a.b, 2, 2);
        a.line(-106, -3, 106, -3, a.i, 13);
        a.line(4, -76, 4, 77, a.i, 13);
        a.oval(-21, -24, 47, 34, a.i, 5);
        a.oval(28, -24, 47, 34, a.i, 5);
        a.poly([4, -9, -16, 31, 4, 23, 22, 39, 20, -8], a.i);
      });
      a.sprig(423, 274, 72, a.b);
    case 5:
      a.rect(188, 112, 224, 180, a.i, 8);
      a.rect(208, 126, 184, 151, a.g, 3);
      a.poly([188, 112, 267, 112, 239, 220, 209, 259, 188, 266], a.b);
      a.poly([412, 112, 333, 112, 361, 220, 391, 259, 412, 266], a.b);
      a.line(193, 224, 234, 219, a.s, 4);
      a.line(366, 219, 407, 224, a.s, 4);
      a.oval(300, 244, 73, 20, a.s);
      a.star(300, 177, 24, a.i);
      a.rect(176, 288, 248, 12, a.b, 2);
  }
}
