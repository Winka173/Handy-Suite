/// Printing both sides on a printer that prints one: which pages go in
/// each pass, as 0-based indices.
class DuplexPlan {
  /// First pass: pages 1, 3, 5…
  final List<int> fronts;

  /// Second pass, after the printed stack is turned over and put back:
  /// pages …, 6, 4, 2, last first, so each lands on the back of its front.
  final List<int> backs;

  /// With an odd page count the last front has no back: take that sheet
  /// out before the second pass.
  final bool lastFrontAlone;
  const DuplexPlan(this.fronts, this.backs, this.lastFrontAlone);
}

DuplexPlan duplexPlan(int pages) {
  if (pages < 2) {
    throw const FormatException('Both sides needs at least two pages');
  }
  return DuplexPlan(
    [for (var i = 0; i < pages; i += 2) i],
    [for (var i = pages.isOdd ? pages - 2 : pages - 1; i >= 1; i -= 2) i],
    pages.isOdd,
  );
}

/// The number shown on page [index] (0-based), or null when that page is
/// left unnumbered (the cover, when [skipFirst]).
int? pageNumberFor(int index, {int start = 1, bool skipFirst = false}) {
  if (skipFirst && index == 0) return null;
  return start + index - (skipFirst ? 1 : 0);
}
