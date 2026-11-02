import 'package:handy_recall/handy_recall.dart';

/// What one card shows on each side and in which language each side is read
/// aloud. Cloze cards ask their text with the blank and keep any extra text
/// for below the rule; reverse cards ask the back and expect the front.
class CardText {
  /// The question area: one plain span, or a cloze text's runs.
  final List<ClozeSpan> question;

  /// The text under the rule once the answer shows ('' when there is none).
  final String answer;

  /// Read-aloud languages of the two areas ('' when not read aloud).
  final String questionLanguage, answerLanguage;
  const CardText(
    this.question,
    this.answer,
    this.questionLanguage,
    this.answerLanguage,
  );

  String get spokenQuestion =>
      question.map((s) => s.part == ClozePart.blank ? '…' : s.text).join();
}

CardText cardText(RecallCard c, RecallDeck? deck, {required bool revealed}) {
  final front = deck?.speakFront ?? '', back = deck?.speakBack ?? '';
  if (c.cloze > 0) {
    return CardText(
      clozeSpans(c.front, c.cloze, revealed: revealed),
      c.back,
      front,
      back,
    );
  }
  return CardText(
    [if (c.question.isNotEmpty) ClozeSpan(c.question, ClozePart.text)],
    c.answer,
    c.reversed ? back : front,
    c.reversed ? front : back,
  );
}

/// The one line a card row shows: its question as asked.
String cardTitle(RecallCard c) =>
    c.cloze > 0 ? clozeText(c.front, c.cloze, revealed: false) : c.question;
