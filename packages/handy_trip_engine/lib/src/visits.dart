part of '../handy_trip_engine.dart';

class Visit extends Entity {
  Visit(Json j) : super(j) {
    id(place);
    ref('trip');
    ref('stop');
    instant(at);
    location(zone);
    instant(j['created']);
    instant(j['updated']);
    string(j['note'] ?? '');
    list('tags');
    list('assets');
    if (j['rating'] != null) integer(j['rating'], min: 1, max: 5);
    if (!['manual', 'gps', 'photo-suggestion'].contains(origin))
      throw const FormatException('Invalid visit origin');
    if (j['geo'] != null) Geo.fromJson(object(j['geo']));
    if (j['accuracy'] != null &&
        (j['accuracy'] is! num ||
            !(j['accuracy'] as num).isFinite ||
            j['accuracy'] < 0 ||
            j['accuracy'] > 1000000))
      throw const FormatException('Invalid accuracy');
    if (origin == 'gps' &&
        (j['geo'] == null || j['capturedAt'] == null || j['accuracy'] == null))
      throw const FormatException('GPS visit needs capture metadata');
    if (j['capturedAt'] != null) instant(j['capturedAt']);
  }
  String get place => text('place');
  String? get trip => ref('trip');
  String? get stop => ref('stop');
  String get at => text('at');
  String get zone => text('zone');
  bool get confirmed => data['confirmed'] == true;
  String get origin => text('origin', fallback: 'manual');
  String get note => text('note');
  List<String> get assets => list('assets');
  Visit copy(Json j) => Visit({...toJson(), ...j});
}

class JournalNote extends Entity {
  JournalNote(Json j) : super(j) {
    ref('trip');
    ref('visit');
    ref('stop');
    instant(at);
    location(zone);
    string(j['title'] ?? '', max: 300);
    string(j['body'] ?? '', max: 100000);
    list('assets');
  }
  String? get trip => ref('trip');
  String get at => text('at');
  String get zone => text('zone');
  String get title => text('title');
  String get body => text('body');
  List<String> get assets => list('assets');
  JournalNote copy(Json j) => JournalNote({...toJson(), ...j});
}

class MediaAsset extends Entity {
  MediaAsset(Json j) : super(j) {
    if (!RegExp(
          r'^assets/[A-Za-z0-9_-]+\.(jpg|jpeg|png|webp|pdf)$',
        ).hasMatch(path) ||
        !path.split('/').last.startsWith('$key.'))
      throw const FormatException('Nonportable asset path');
    string(j['name'], max: 300);
    string(j['caption'] ?? '');
    integer(j['size'], min: 1, max: 12000000);
    if (![
          'image/jpeg',
          'image/png',
          'image/webp',
          'application/pdf',
        ].contains(mime) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum))
      throw const FormatException('Invalid asset metadata');
    if (j['width'] != null) integer(j['width'], min: 1, max: 20000);
    if (j['height'] != null) integer(j['height'], min: 1, max: 20000);
  }
  String get path => text('path');
  String get mime => text('mime');
  String get checksum => text('sha256');
  int get size => integer(data['size']);
  MediaAsset copy(Json j) => MediaAsset({...toJson(), ...j});
}

class TripAlarm extends Entity {
  TripAlarm(Json j) : super(j) {
    id(trip);
    instant(at);
    location(zone);
    if (!['stop', 'booking', 'packing'].contains(type))
      throw const FormatException('Invalid reminder target');
    id(target);
  }
  String get trip => text('trip');
  String get at => text('at');
  String get zone => text('zone');
  String get type => text('type');
  String get target => text('target');
  bool get enabled => data['enabled'] == true;
  TripAlarm copy(Json j) => TripAlarm({...toJson(), ...j});
}
