part of 'cover_art.dart';

void _paintStudy(_Art a, int v) {
  switch (v) {
    case 0: // A notebook page, folded corner, ribbon and diagonal pencil.
      a.turn(298, 200, -.08, () {
        a.rect(-110, -95, 220, 190, a.s, 5);
        for (var x = -86.0; x < 105; x += 22) {
          a.line(x, -88, x, 86, a.g, 1.3);
        }
        for (var y = -70.0; y < 90; y += 22) {
          a.line(-100, y, 100, y, a.g, 1.3);
        }
        a.line(-72, -88, -72, 88, a.b, 2);
        a.poly([78, -95, 110, -63, 78, -63], a.g);
        a.rect(38, -95, 14, 58, a.i);
        a.poly([38, -37, 52, -37, 45, -46], a.s);
      });
      a.pencil(369, 257, 136, .35, a.b);
    case 1: // Open spread: pages fan away from a central stitched spine.
      a.poly([300, 143, 206, 123, 192, 259, 300, 278], a.i);
      a.poly([300, 143, 394, 123, 408, 259, 300, 278], a.b);
      a.poly([298, 147, 211, 133, 202, 250, 298, 267], a.s);
      a.poly([302, 147, 389, 133, 398, 250, 302, 267], a.s);
      for (var n = 0; n < 5; n++) {
        a.line(222, 163 + n * 17, 282, 173 + n * 17, a.g, 2);
        a.line(318, 173 + n * 17, 378, 163 + n * 17, a.g, 2);
      }
      a.line(300, 146, 300, 266, a.i, 2);
      a.line(300, 266, 308, 290, a.b, 5);
      a.leaf(415, 243, 42, .7, a.i);
    case 2: // Unzipped pencil pouch; the instruments have different silhouettes.
      a.rect(190, 194, 220, 74, a.s, 28);
      a.rect(193, 183, 214, 47, a.i, 21);
      a.pencil(234, 213, 91, -.23, a.b);
      a.pencil(278, 211, 115, .04, a.i);
      a.pencil(317, 213, 94, .29, a.b);
      a.rect(343, 131, 23, 82, a.s, 2);
      for (var n = 0; n < 7; n++) {
        a.line(346, 140 + n * 9, 353, 140 + n * 9, a.i, 1.5);
      }
      a.rect(190, 217, 220, 52, a.b, 24);
      a.line(210, 220, 389, 220, a.i, 3);
      a.oval(394, 223, 13, 18, a.i, 3);
    case 3: // Academic marks are abstract arcs and points, with no glyphs.
      a.turn(300, 200, -.32, () {
        a.oval(0, 0, 238, 98, a.i, 3);
        a.oval(0, 0, 98, 238, a.i, 3);
        a.oval(0, 0, 176, 176, a.b, 2);
        a.oval(0, 0, 24, 24, a.b);
        a.oval(-104, -23, 16, 16, a.i);
        a.oval(25, 108, 14, 14, a.i);
        a.oval(70, -56, 14, 14, a.b);
      });
      a.poly([392, 125, 408, 148, 380, 148], a.i, 2);
      a.line(187, 259, 211, 259, a.b, 3);
      a.line(199, 247, 199, 271, a.b, 3);
    case 4: // A small architectural library built from book spines.
      a.rect(170, 281, 260, 10, a.i);
      for (var n = 0; n < 5; n++) {
        final x = 193 + n * 37.0, top = 180 - n * 16.0;
        a.rect(x, top, 29, 281 - top, n.isEven ? a.i : a.b, 2);
        a.line(x + 6, top + 13, x + 23, top + 13, a.s, 2);
        a.line(x + 6, 268, x + 23, 268, a.s, 2);
      }
      a.arc(300, 162, 200, 140, math.pi, math.pi, a.s, 13);
      a.oval(410, 123, 28, 28, a.b);
    case 5: // Set square and protractor overlap on a dark drawing surface.
      a.turn(282, 199, -.16, () {
        a.poly([-83, 70, 83, 70, -83, -87], a.b);
        a.poly([-59, 45, 25, 45, -59, -36], a.g);
        for (var n = 0; n < 9; n++) {
          a.line(-75 + n * 16, 62, -75 + n * 16, 55, a.i, 1.5);
        }
      });
      a.arc(337, 205, 158, 158, math.pi, math.pi, a.i, 18);
      a.line(258, 205, 416, 205, a.i, 7);
      for (var n = 0; n <= 8; n++) {
        final t = math.pi + n * math.pi / 8;
        a.line(
          337 + math.cos(t) * 65,
          205 + math.sin(t) * 65,
          337 + math.cos(t) * 73,
          205 + math.sin(t) * 73,
          a.g,
          2,
        );
      }
      a.pencil(370, 278, 130, .6, a.s);
  }
}
