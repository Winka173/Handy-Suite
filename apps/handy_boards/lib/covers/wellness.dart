part of 'cover_art.dart';

void _paintWellness(_Art a, int v) {
  switch (v) {
    case 0:
      a.oval(306, 151, 77, 77, a.s);
      for (var n = 0; n < 4; n++) {
        final y = 202 + n * 34.0;
        a.curve(
          [-600, y, 170, y - 65, 348, y + 50, 1200, y - 12],
          n.isEven ? a.i : a.s,
          22,
        );
      }
      a.curve([161, 197, 238, 167, 327, 231, 424, 201], a.b, 3);
    case 1:
      a.oval(333, 168, 134, 134, a.s);
      a.curve([217, 284, 249, 230, 329, 184, 374, 117], a.i, 4);
      for (final (x, y, len, angle) in [
        (238.0, 253.0, 64.0, -.7),
        (267.0, 227.0, 78.0, .8),
        (299.0, 202.0, 69.0, -.6),
        (328.0, 172.0, 59.0, .8),
        (353.0, 144.0, 42.0, -.3),
      ]) {
        a.leaf(x, y, len, angle, a.i);
      }
      a.oval(397, 251, 9, 9, a.b);
      a.oval(412, 239, 6, 6, a.b);
    case 2:
      a.oval(295, 266, 203, 32, a.i, 2);
      a.mug(286, 226, a.s);
      a.oval(286, 207, 41, 8, a.b);
      a.curve([269, 180, 252, 162, 286, 153, 272, 133], a.i, 2);
      a.curve([292, 179, 275, 159, 315, 142, 297, 117], a.i, 2);
      a.leaf(379, 259, 51, .9, a.i);
      a.leaf(380, 259, 42, -.3, a.i);
      a.line(380, 259, 408, 276, a.i, 2);
    case 3:
      a.line(194, 281, 406, 281, a.i, 2);
      a.oval(300, 259, 155, 43, a.i);
      a.oval(304, 219, 119, 43, a.s);
      a.oval(291, 182, 86, 37, a.b);
      a.oval(301, 149, 51, 32, a.i);
      a.sprig(410, 272, 67, a.i);
      a.oval(212, 139, 26, 26, a.s);
    case 4:
      for (var n = 0; n < 4; n++) {
        final d = 68 + n * 49.0;
        a.arc(300, 200, d, d, -1.18, 4.6, n.isEven ? a.i : a.b, 3);
      }
      a.oval(300, 200, 37, 37, a.i);
      a.oval(317, 100, 9, 9, a.b);
      a.leaf(300, 281, 28, -.8, a.i);
      a.leaf(300, 281, 28, .8, a.i);
    case 5:
      a.oval(300, 200, 130, 130, a.s);
      a.arc(300, 200, 181, 181, math.pi, math.pi, a.b, 3);
      for (var n = 0; n < 9; n++) {
        final angle = math.pi + n * math.pi / 8;
        a.line(
          300 + math.cos(angle) * 101,
          200 + math.sin(angle) * 101,
          300 + math.cos(angle) * 114,
          200 + math.sin(angle) * 114,
          a.b,
          3,
        );
      }
      a.rect(-2000, 251, 4000, 2000, a.g);
      a.line(205, 254, 395, 254, a.i, 3);
      a.line(229, 271, 371, 271, a.i, 2);
      a.poly([236, 251, 300, 227, 365, 251], a.b);
  }
}
