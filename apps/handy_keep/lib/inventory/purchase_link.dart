import '../ui/words.dart';

/// A purchase handed over by Handy Spend:
/// `handy-keep://new?name=…&price=4500000&currency=VND&date=2026-11-02`.
/// It only pre-fills a new item; the person reviews and saves it.
class PurchaseLink {
  final String name, price, currency, date;
  const PurchaseLink(this.name, this.price, this.currency, this.date);

  /// Null when [value] is not a purchase link; fields that do not check
  /// out are left empty rather than trusted.
  static PurchaseLink? parse(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'handy-keep' || uri.host != 'new')
      return null;
    final q = uri.queryParameters;
    String take(String key, RegExp ok, int max) {
      final v = (q[key] ?? '').trim();
      return v.length <= max && ok.hasMatch(v) ? v : '';
    }

    final name = (q['name'] ?? '').trim();
    final currency = take('currency', RegExp(r'^[A-Z]{3}$'), 3);
    return PurchaseLink(
      name.length > 120 ? name.substring(0, 120) : name,
      take('price', RegExp(r'^\d{1,12}(\.\d{1,2})?$'), 15),
      keepCurrencies.contains(currency) ? currency : '',
      take('date', RegExp(r'^\d{4}-\d{2}-\d{2}$'), 10),
    );
  }
}
