/// Line diff of two texts with Myers' O(ND) algorithm, bounded in lines and
/// in changes so a large or unrelated pair cannot exhaust memory.
library;

import 'dart:typed_data';

enum DiffOp { same, removed, added }

class DiffLine {
  final DiffOp op;
  final String text;

  /// 1-based line numbers in the before and after text, when the line is
  /// on that side.
  final int? before, after;
  const DiffLine(this.op, this.text, {this.before, this.after});
}

/// Most lines per side, and most changed lines, a diff may hold.
const maxDiffLines = 20000, maxDiffChanges = 2000;

class TextDiff {
  final List<DiffLine> lines;
  const TextDiff(this.lines);
  int get added => lines.where((l) => l.op == DiffOp.added).length;
  int get removed => lines.where((l) => l.op == DiffOp.removed).length;
  bool get identical => lines.every((l) => l.op == DiffOp.same);

  /// Rows for a side-by-side view: unchanged lines face themselves; within a
  /// change, removed lines face added lines in order.
  List<(DiffLine?, DiffLine?)> sideBySide() {
    final rows = <(DiffLine?, DiffLine?)>[];
    var i = 0;
    while (i < lines.length) {
      if (lines[i].op == DiffOp.same) {
        rows.add((lines[i], lines[i]));
        i++;
        continue;
      }
      final removed = <DiffLine>[], added = <DiffLine>[];
      while (i < lines.length && lines[i].op != DiffOp.same) {
        (lines[i].op == DiffOp.removed ? removed : added).add(lines[i]);
        i++;
      }
      for (var j = 0; j < removed.length || j < added.length; j++) {
        rows.add((
          j < removed.length ? removed[j] : null,
          j < added.length ? added[j] : null,
        ));
      }
    }
    return rows;
  }

  /// Unified format with [context] lines around each change. Empty when the
  /// texts are identical.
  String unified({
    int context = 3,
    String from = 'before',
    String to = 'after',
  }) {
    if (identical) return '';
    final out = StringBuffer('--- $from\n+++ $to\n');
    final changed = [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].op != DiffOp.same) i,
    ];
    var k = 0;
    while (k < changed.length) {
      final start = (changed[k] - context).clamp(0, lines.length - 1);
      var end = changed[k];
      while (k + 1 < changed.length &&
          changed[k + 1] - end <= context * 2 + 1) {
        end = changed[++k];
      }
      k++;
      end = (end + context).clamp(0, lines.length - 1);
      final hunk = lines.sublist(start, end + 1);
      // Counts of old lines and new lines before the hunk give its start
      // when a side has no lines in it.
      var oldBefore = 0, newBefore = 0;
      for (final l in lines.take(start)) {
        if (l.op != DiffOp.added) oldBefore++;
        if (l.op != DiffOp.removed) newBefore++;
      }
      final oldCount = hunk.where((l) => l.op != DiffOp.added).length;
      final newCount = hunk.where((l) => l.op != DiffOp.removed).length;
      String range(int before, int count) =>
          '${count == 0 ? before : before + 1}${count == 1 ? '' : ',$count'}';
      out.writeln(
        '@@ -${range(oldBefore, oldCount)} +${range(newBefore, newCount)} @@',
      );
      for (final l in hunk) {
        out.writeln(
          '${switch (l.op) {
            DiffOp.same => ' ',
            DiffOp.removed => '-',
            DiffOp.added => '+',
          }}${l.text}',
        );
      }
    }
    return out.toString();
  }
}

List<String> _lines(String text) {
  if (text.isEmpty) return const [];
  final l = text.replaceAll('\r\n', '\n').split('\n');
  if (l.last.isEmpty) l.removeLast();
  if (l.length > maxDiffLines) {
    throw const FormatException(
      'Each side is limited to $maxDiffLines lines / '
      'Mỗi bên tối đa $maxDiffLines dòng',
    );
  }
  return l;
}

/// Lines of [before] against [after]. Line endings are normalised; a final
/// newline does not count as a line.
TextDiff diffText(String before, String after) {
  final a = _lines(before), b = _lines(after);
  // Common ends cost nothing; only the middle goes through Myers.
  var head = 0;
  while (head < a.length && head < b.length && a[head] == b[head]) {
    head++;
  }
  var tail = 0;
  while (tail < a.length - head &&
      tail < b.length - head &&
      a[a.length - 1 - tail] == b[b.length - 1 - tail]) {
    tail++;
  }
  final ids = <String, int>{};
  int id(String s) => ids.putIfAbsent(s, () => ids.length);
  final x0 = [for (final s in a.sublist(head, a.length - tail)) id(s)];
  final y0 = [for (final s in b.sublist(head, b.length - tail)) id(s)];
  final middle = _myers(x0, y0);

  final out = <DiffLine>[];
  for (var i = 0; i < head; i++) {
    out.add(DiffLine(DiffOp.same, a[i], before: i + 1, after: i + 1));
  }
  var ai = head, bi = head;
  // Within each change, removed lines come before added lines.
  var removed = <DiffLine>[], added = <DiffLine>[];
  void flush() {
    out
      ..addAll(removed)
      ..addAll(added);
    removed = [];
    added = [];
  }

  for (final op in middle) {
    switch (op) {
      case DiffOp.same:
        flush();
        out.add(DiffLine(DiffOp.same, a[ai], before: ai + 1, after: bi + 1));
        ai++;
        bi++;
      case DiffOp.removed:
        removed.add(DiffLine(DiffOp.removed, a[ai], before: ai + 1));
        ai++;
      case DiffOp.added:
        added.add(DiffLine(DiffOp.added, b[bi], after: bi + 1));
        bi++;
    }
  }
  flush();
  for (var i = 0; i < tail; i++) {
    out.add(
      DiffLine(DiffOp.same, a[ai + i], before: ai + i + 1, after: bi + i + 1),
    );
  }
  return TextDiff(out);
}

/// The edit script from [a] to [b] (Myers 1986), with a snapshot of the
/// frontier per step for the walk back.
List<DiffOp> _myers(List<int> a, List<int> b) {
  final n = a.length, m = b.length;
  if (n == 0) return List.filled(m, DiffOp.added);
  if (m == 0) return List.filled(n, DiffOp.removed);
  final limit = maxDiffChanges;
  final off = limit + 1;
  final v = Int32List(2 * limit + 3);
  final trace = <Int32List>[];
  var found = -1;
  for (var d = 0; d <= limit && d <= n + m; d++) {
    // Snapshot k in [-d-1, d+1] before this step.
    trace.add(Int32List.fromList(v.sublist(off - d - 1, off + d + 2)));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[off + k - 1] < v[off + k + 1]))
          ? v[off + k + 1]
          : v[off + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a[x] == b[y]) {
        x++;
        y++;
      }
      v[off + k] = x;
      if (x >= n && y >= m) {
        found = d;
        break;
      }
    }
    if (found >= 0) break;
  }
  if (found < 0) {
    throw const FormatException(
      'More than $maxDiffChanges changed lines; compare smaller parts / '
      'Hơn $maxDiffChanges dòng khác nhau; hãy so từng phần nhỏ hơn',
    );
  }
  final ops = <DiffOp>[];
  var x = n, y = m;
  for (var d = found; d >= 0; d--) {
    final snap = trace[d];
    int at(int k) => snap[k + d + 1];
    final k = x - y;
    final prevK = (k == -d || (k != d && at(k - 1) < at(k + 1)))
        ? k + 1
        : k - 1;
    final prevX = d == 0 ? 0 : at(prevK);
    final prevY = d == 0 ? 0 : prevX - prevK;
    while (x > prevX && y > prevY) {
      ops.add(DiffOp.same);
      x--;
      y--;
    }
    if (d > 0) {
      ops.add(x == prevX ? DiffOp.added : DiffOp.removed);
    }
    x = prevX;
    y = prevY;
  }
  return ops.reversed.toList();
}
