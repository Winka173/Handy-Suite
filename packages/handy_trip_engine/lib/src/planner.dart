part of '../handy_trip_engine.dart';

class Trip extends Entity {
  Trip(Json j) : super(j) {
    string(j['title'], max: 200, required: true);
    date(start);
    date(end);
    location(zone);
    currencyScale(currency);
    minorValue(j['budget'] ?? '0');
    if (date(end).difference(date(start)).inDays < 0 ||
        date(end).difference(date(start)).inDays > 3660 ||
        ![
          'idea',
          'planned',
          'ongoing',
          'completed',
          'archived',
        ].contains(status))
      throw const FormatException('Invalid trip interval/status');
    instant(j['created']);
    instant(j['updated']);
    string(j['description'] ?? '');
    string(j['destination'] ?? '', max: 500);
    ref('cover');
  }
  String get title => text('title');
  String get start => text('start');
  String get end => text('end');
  String get zone => text('zone');
  String get currency => text('currency');
  String get status => text('status', fallback: 'idea');
  BigInt get budget => minorValue(data['budget'] ?? '0');
  String get destination => text('destination');
  String? get cover => ref('cover');
  List<String> get days => List.generate(
    date(end).difference(date(start)).inDays + 1,
    (i) => addDays(start, i),
  );
  Trip copy(Json j) => Trip({...toJson(), ...j});
}

class Place extends Entity {
  Place(Json j) : super(j) {
    string(j['name'], max: 300, required: true);
    for (final k in ['address', 'country', 'region', 'city', 'note'])
      string(j[k] ?? '', max: 10000);
    safeUrl(j['url']);
    list('tags');
    ref('targetTrip');
    integer(j['priority'] ?? 0, max: 9);
    if (j['geo'] != null) Geo.fromJson(object(j['geo']));
    if (![
      'food',
      'attraction',
      'shopping',
      'lodging',
      'activity',
      'other',
    ].contains(category))
      throw const FormatException('Invalid place category');
  }
  String get name => text('name');
  String get category => text('category', fallback: 'other');
  String get address => text('address');
  String? get url => safeUrl(data['url']);
  Geo? get geo =>
      data['geo'] == null ? null : Geo.fromJson(object(data['geo']));
  bool get wishlist => data['wishlist'] == true;
  bool get favorite => data['favorite'] == true;
  Place copy(Json j) => Place({...toJson(), ...j});
}

class Stop extends Entity {
  Stop(Json j) : super(j) {
    id(trip);
    date(on);
    string(j['title'], max: 300, required: true);
    ref('place');
    integer(j['order'] ?? 0);
    integer(j['duration'] ?? 0, max: 10080);
    string(j['note'] ?? '');
    list('tags');
    minorValue(j['estimate'] ?? '0');
    if (j['currency'] != null) currencyScale(text('currency'));
    if (![
          'sightseeing',
          'food',
          'transit',
          'lodging',
          'activity',
          'other',
        ].contains(type) ||
        !['planned', 'visited', 'skipped'].contains(status))
      throw const FormatException('Invalid stop type/status');
    if (time != null) minute(time!);
    if (endTime != null) minute(endTime!);
    integer(j['endOffset'] ?? 0, max: 7);
    if (endTime != null && time == null)
      throw const FormatException('End needs start');
    if (time != null &&
        endTime != null &&
        endOffset == 0 &&
        minute(endTime!) < minute(time!))
      throw const FormatException('Choose next-day offset for overnight stop');
  }
  String get trip => text('trip');
  String get on => text('day');
  String get title => text('title');
  String? get place => ref('place');
  String get type => text('type', fallback: 'other');
  String get status => text('status', fallback: 'planned');
  String? get time => data['time'] as String?;
  String? get endTime => data['endTime'] as String?;
  int get endOffset => integer(data['endOffset'] ?? 0, max: 7);
  int get order => integer(data['order'] ?? 0);
  int get duration => integer(data['duration'] ?? 0, max: 10080);
  Stop copy(Json j) => Stop({...toJson(), ...j});
}

class Booking extends Entity {
  Booking(Json j) : super(j) {
    id(trip);
    string(j['title'], max: 300, required: true);
    location(zone);
    instant(start);
    instant(end);
    if (DateTime.parse(end).isBefore(DateTime.parse(start)))
      throw const FormatException('Booking ends before start');
    if (![
      'flight',
      'train',
      'bus',
      'hotel',
      'car',
      'activity',
      'other',
    ].contains(type))
      throw const FormatException('Invalid booking type');
    for (final k in ['code', 'provider', 'address', 'note']) string(j[k] ?? '');
    list('assets');
    currencyScale(text('currency', fallback: 'USD'));
    minorValue(j['cost'] ?? '0');
  }
  String get trip => text('trip');
  String get title => text('title');
  String get type => text('type', fallback: 'other');
  String get start => text('start');
  String get end => text('end');
  String get zone => text('zone');
  String get code => text('code');
  String get maskedCode => code.isEmpty ? '—' : '••••';
  Booking copy(Json j) => Booking({...toJson(), ...j});
}

class PackItem extends Entity {
  PackItem(Json j) : super(j) {
    id(trip);
    string(j['title'], max: 300, required: true);
    string(j['list'] ?? 'Packing', max: 200);
    string(j['category'] ?? '', max: 200);
    integer(j['quantity'] ?? 1, min: 1, max: 10000);
    integer(j['order'] ?? 0);
    integer(j['weightGrams'] ?? 0, max: 100000000);
  }
  String get trip => text('trip');
  String get title => text('title');
  bool get packed => data['packed'] == true;
  int get quantity => integer(data['quantity'] ?? 1, min: 1, max: 10000);
  int get order => integer(data['order'] ?? 0);
  PackItem copy(Json j) => PackItem({...toJson(), ...j});
}

class Expense extends Entity {
  Expense(Json j) : super(j) {
    id(trip);
    instant(at);
    if (j['zone'] != null) location(text('zone'));
    currencyScale(currency);
    minorValue(j['minor']);
    string(j['description'] ?? '');
    string(j['payer'] ?? '', max: 300);
    ref('receipt');
    if (![
      'transport',
      'lodging',
      'food',
      'activity',
      'shopping',
      'other',
    ].contains(category))
      throw const FormatException('Invalid expense category');
    if (j['source'] != null) string(j['source'], max: 200);
  }
  String get trip => text('trip');
  String get at => text('at');
  String get currency => text('currency');
  String get category => text('category', fallback: 'other');
  BigInt get minor => minorValue(data['minor']);
  Expense copy(Json j) => Expense({...toJson(), ...j});
}
