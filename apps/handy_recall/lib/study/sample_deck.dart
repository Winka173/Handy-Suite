import 'package:handy_recall/handy_recall.dart';

/// Sample decks use this id prefix, so they are told apart from the
/// person's own and removed whole; their name says "sample" too.
const recallSamplePrefix = 'sample-';
bool isSampleDeck(String id) => id.startsWith(recallSamplePrefix);

const _words = [
  ('passport', 'hộ chiếu'),
  ('boarding pass', 'thẻ lên máy bay'),
  ('luggage', 'hành lý'),
  ('departure', 'chuyến đi, giờ khởi hành'),
  ('arrival', 'chuyến đến'),
  ('delay', 'sự chậm trễ'),
  ('return ticket', 'vé khứ hồi'),
  ('reservation', 'đặt chỗ trước'),
  ('check in', 'làm thủ tục nhận phòng / lên máy bay'),
  ('receipt', 'hoá đơn, biên lai'),
  ('exchange rate', 'tỷ giá'),
  ('cash only', 'chỉ nhận tiền mặt'),
  ('platform', 'sân ga'),
  ('one-way street', 'đường một chiều'),
  ('pharmacy', 'nhà thuốc'),
  ('lost and found', 'nơi giữ đồ thất lạc'),
  ('emergency exit', 'lối thoát hiểm'),
  ('sold out', 'đã bán hết'),
  ('the bill, please', 'cho xin hoá đơn'),
  ('how far is it?', 'còn bao xa?'),
];

/// Adds a 20-card English travel words deck, every card due now.
RecallState addSampleDeck(RecallState s, {required bool vi, String? now}) {
  const id = '${recallSamplePrefix}travel-words';
  if (s.decks.any((d) => d.id == id)) return s;
  var next = saveDeck(
    s,
    RecallDeck(
      id: id,
      name: vi
          ? 'Từ vựng du lịch tiếng Anh (mẫu)'
          : 'English travel words (sample)',
      speakFront: 'en-US',
    ),
  );
  for (final (i, (en, viWord)) in _words.indexed) {
    next = saveCard(
      next,
      createCard(
        id: '$recallSamplePrefix$i',
        deckId: id,
        front: en,
        back: viWord,
        now: now,
      ),
    );
  }
  return next;
}

/// Removes every sample deck and its cards; the person's own stay.
RecallState removeSampleDecks(RecallState s) {
  var next = s;
  for (final d in s.decks.where((d) => isSampleDeck(d.id))) {
    next = removeDeck(next, d.id);
  }
  return next;
}
