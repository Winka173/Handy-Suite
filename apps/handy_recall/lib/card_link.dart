/// A card handed over by another Handy app (Bookmark sends a link as
/// `handy-recall://new?front=…&back=…`). It only opens the card editor
/// pre-filled; nothing is saved until the person saves it.
class CardLink {
  final String front, back;
  const CardLink(this.front, this.back);

  static CardLink? parse(Uri uri) {
    if (uri.scheme != 'handy-recall' || uri.host != 'new') return null;
    String take(String key, int max) {
      final v = (uri.queryParameters[key] ?? '').trim();
      return v.length > max ? v.substring(0, max) : v;
    }

    final link = CardLink(take('front', 500), take('back', 2000));
    return link.front.isEmpty && link.back.isEmpty ? null : link;
  }
}
