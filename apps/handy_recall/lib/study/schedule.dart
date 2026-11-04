import 'package:handy_recall/handy_recall.dart';

const ratings = ['again', 'hard', 'good', 'easy'];

/// The engine's timestamp form: UTC, millisecond precision.
String stamp(DateTime t) => DateTime.fromMillisecondsSinceEpoch(
  t.millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();

/// Cards due on each of the next [days] local days, today first. Anything
/// already overdue counts toward today: that is when it will be reviewed.
List<int> forecast(
  RecallState state,
  DateTime now, {
  int days = 14,
  String? deckId,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final counts = List<int>.filled(days, 0);
  for (final c in state.cards) {
    if (deckId != null && c.deckId != deckId) continue;
    final due = DateTime.parse(c.dueAt).toLocal();
    final day = DateTime(due.year, due.month, due.day).difference(today).inDays;
    if (day < days) counts[day < 0 ? 0 : day]++;
  }
  return counts;
}

/// The deck's hard cards: forgotten at least [least] times, most forgotten
/// first, at most [limit]. Practising them does not touch the schedule.
List<String> hardCards(
  RecallState state,
  String deckId, {
  int least = 2,
  int limit = 30,
}) {
  final hard =
      state.cards.where((c) => c.deckId == deckId && c.lapses >= least).toList()
        ..sort((a, b) => b.lapses.compareTo(a.lapses));
  return [for (final c in hard.take(limit)) c.id];
}

/// How long until a card graded [rating] now is seen again, in days.
double nextInterval(RecallCard card, String rating, DateTime now) =>
    reviewCard(card, rating, now: stamp(now)).intervalDays;

/// A span in the words on a grade button: 10 min, 1 day, 3 weeks, 2 months.
(String en, String vi) spanWords(double days) {
  final minutes = (days * 1440).round();
  if (minutes < 60) return ('$minutes min', '$minutes phút');
  final hours = (days * 24).round();
  if (days < 1) return ('$hours h', '$hours giờ');
  final d = days.round();
  if (d < 14) return (d == 1 ? '1 day' : '$d days', '$d ngày');
  if (d < 60) return ('${(d / 7).round()} wk', '${(d / 7).round()} tuần');
  if (d < 365) return ('${(d / 30).round()} mo', '${(d / 30).round()} tháng');
  final y = (d / 365);
  final years = y >= 10 ? y.round().toString() : y.toStringAsFixed(1);
  return ('$years yr', '$years năm');
}

enum DueState { fresh, due, later }

/// Where one card stands: never seen, due now, or due in [days] days.
(DueState, int days) dueState(RecallCard c, DateTime now) {
  if (c.reviewCount == 0) return (DueState.fresh, 0);
  final due = DateTime.parse(c.dueAt);
  if (!due.isAfter(now.toUtc())) return (DueState.due, 0);
  final today = DateTime(now.year, now.month, now.day);
  final local = due.toLocal();
  return (
    DueState.later,
    DateTime(local.year, local.month, local.day).difference(today).inDays,
  );
}

/// About ten seconds a card, rounded up to whole minutes.
int minutesFor(int cards) => cards == 0 ? 0 : ((cards * 10) / 60).ceil();

/// A deck's identity colour: its place in the name-sorted deck list, so
/// decks listed together never share a colour.
int deckHue(List<RecallDeck> decks, String id) {
  final sorted = [...decks]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final at = sorted.indexWhere((d) => d.id == id);
  return at < 0 ? 0 : at;
}
