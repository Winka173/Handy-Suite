import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_core/portable_zip.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
part 'src/portable.dart';
part 'src/labels.dart';

const keepAssetLimit = 5000, keepBoxLimit = 500, keepBackupBytes = 8000000;
String _now() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
Map<String, dynamic> _record(Object? value) {
  if (value is! Map || value.keys.any((k) => k is! String))
    throw const FormatException('Invalid inventory record');
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, int maximum, {bool required = false}) {
  if (value is! String ||
      value.length > maximum ||
      (required && value.trim().isEmpty))
    throw const FormatException('Invalid inventory text');
  return value.trim();
}

String _id(Object? value) {
  final id = _text(value, 100, required: true);
  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id))
    throw const FormatException('Invalid inventory ID');
  return id;
}

bool isCalendarDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      value.compareTo('0001-01-01') < 0)
    return false;
  final date = DateTime.tryParse('${value}T00:00:00.000Z');
  return date != null && date.toIso8601String().substring(0, 10) == value;
}

String _date(Object? value) {
  final result = _text(value, 10);
  if (result.isNotEmpty && !isCalendarDate(result))
    throw const FormatException('Use a real calendar date YYYY-MM-DD');
  return result;
}

String _instant(Object? value) {
  final result = _text(value, 40, required: true);
  if (!RegExp(
        r'^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,3})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)$',
      ).hasMatch(result) ||
      !isCalendarDate(result.substring(0, 10)))
    throw const FormatException('Invalid inventory timestamp');
  final date = DateTime.tryParse(result);
  if (date == null) throw const FormatException('Invalid inventory timestamp');
  return date.toUtc().toIso8601String();
}

String _localUri(Object? value, {bool required = false}) {
  final uri = _text(value, 2000, required: required);
  if (uri.isNotEmpty &&
      (!uri.startsWith('file:///') || RegExp(r'[\x00-\x1f]').hasMatch(uri)))
    throw const FormatException('Only local file URIs are supported');
  return uri;
}

class InventoryReceipt {
  final String id, name, mime, uri;
  InventoryReceipt({
    required this.id,
    required this.name,
    required this.mime,
    required this.uri,
  });
  factory InventoryReceipt.fromJson(Object? value) {
    final r = _record(value), mime = _text(r['mime'], 100);
    if (!['image/png', 'image/jpeg', 'application/pdf'].contains(mime))
      throw const FormatException('Unsupported receipt type');
    return InventoryReceipt(
      id: _id(r['id']),
      name: _text(r['name'], 200, required: true),
      mime: mime,
      uri: _localUri(r['uri'], required: true),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'mime': mime,
    'uri': uri,
  };
}

class InventoryAsset {
  final Map<String, dynamic> _data;
  InventoryAsset._(Map<String, dynamic> data) : _data = Map.unmodifiable(data);
  factory InventoryAsset.fromJson(Object? value) {
    final a = _record(value),
        r = <String, dynamic>{
          'id': _id(a['id']),
          'name': _text(a['name'], 200, required: true),
          'location': _text(a['location'], 500),
          'serial': _text(a['serial'], 200),
          'notes': _text(a['notes'], 10000),
          'purchasedOn': _date(a['purchasedOn']),
          'warrantyUntil': _date(a['warrantyUntil']),
          'maintenanceDue': _date(a['maintenanceDue']),
          'borrower': _text(a['borrower'], 200),
          'lentOn': _date(a['lentOn']),
          'returnDue': _date(a['returnDue']),
          'boxId': a['boxId'] == '' ? '' : _id(a['boxId']),
          'photoUri': _localUri(a['photoUri'] ?? ''),
          'createdAt': _instant(a['createdAt']),
          'updatedAt': _instant(a['updatedAt']),
        };
    if (a.containsKey('receipts')) {
      final values = a['receipts'];
      if (values is! List || values.length > 20)
        throw const FormatException('At most 20 receipts per item');
      final receipts = values.map(InventoryReceipt.fromJson).toList();
      if (receipts.map((r) => r.id).toSet().length != receipts.length)
        throw const FormatException('Duplicate receipt IDs');
      r['receipts'] = List<InventoryReceipt>.unmodifiable(receipts);
    }
    if ((r['warrantyUntil'] as String).isNotEmpty &&
        (r['purchasedOn'] as String).isNotEmpty &&
        (r['warrantyUntil'] as String).compareTo(r['purchasedOn'] as String) <
            0)
      throw const FormatException('Warranty cannot precede purchase');
    if ((r['returnDue'] as String).isNotEmpty &&
        (r['lentOn'] as String).isNotEmpty &&
        (r['returnDue'] as String).compareTo(r['lentOn'] as String) < 0)
      throw const FormatException('Return date cannot precede lending');
    if ((r['borrower'] == '' && (r['lentOn'] != '' || r['returnDue'] != '')) ||
        (r['borrower'] != '' && r['lentOn'] == ''))
      throw const FormatException('Loan requires borrower and lending date');
    if ((r['updatedAt'] as String).compareTo(r['createdAt'] as String) < 0)
      throw const FormatException('Updated time cannot precede creation');
    return InventoryAsset._(r);
  }
  String get id => _data['id'];
  String get name => _data['name'];
  String get location => _data['location'];
  String get serial => _data['serial'];
  String get notes => _data['notes'];
  String get purchasedOn => _data['purchasedOn'];
  String get warrantyUntil => _data['warrantyUntil'];
  String get maintenanceDue => _data['maintenanceDue'];
  String get borrower => _data['borrower'];
  String get lentOn => _data['lentOn'];
  String get returnDue => _data['returnDue'];
  String get boxId => _data['boxId'];
  String get photoUri => _data['photoUri'];
  String get createdAt => _data['createdAt'];
  String get updatedAt => _data['updatedAt'];
  List<InventoryReceipt> get receipts =>
      (_data['receipts'] as List<InventoryReceipt>?) ?? const [];
  Map<String, dynamic> toJson() => {
    ..._data,
    if (_data.containsKey('receipts'))
      'receipts': receipts.map((r) => r.toJson()).toList(),
  };
  InventoryAsset copyWith(Map<String, Object?> changes) =>
      InventoryAsset.fromJson({...toJson(), ...changes});
}

class InventoryBox {
  final String id, name, location, notes;
  InventoryBox({
    required this.id,
    required this.name,
    this.location = '',
    this.notes = '',
  });
  factory InventoryBox.fromJson(Object? value) {
    final r = _record(value);
    return InventoryBox(
      id: _id(r['id']),
      name: _text(r['name'], 200, required: true),
      location: _text(r['location'], 500),
      notes: _text(r['notes'], 10000),
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'notes': notes,
  };
  InventoryBox copyWith(Map<String, Object?> changes) =>
      InventoryBox.fromJson({...toJson(), ...changes});
}

class KeepState {
  final List<InventoryAsset> assets;
  final List<InventoryBox> boxes;
  KeepState({
    Iterable<InventoryAsset> assets = const [],
    Iterable<InventoryBox> boxes = const [],
  }) : assets = List.unmodifiable(assets),
       boxes = List.unmodifiable(boxes);
  Map<String, Object?> toJson() => {
    'version': 1,
    'assets': assets.map((a) => a.toJson()).toList(),
    'boxes': boxes.map((b) => b.toJson()).toList(),
  };
}

KeepState emptyKeepState() => KeepState();
KeepState validateKeepState(Object? value) {
  final r = _record(value), a = r['assets'], b = r['boxes'];
  if (r['version'] != 1 ||
      a is! List ||
      b is! List ||
      a.length > keepAssetLimit ||
      b.length > keepBoxLimit)
    throw const FormatException(
      'Unsupported inventory or collection limit exceeded',
    );
  final assets = a.map(InventoryAsset.fromJson).toList(),
      boxes = b.map(InventoryBox.fromJson).toList(),
      boxIds = boxes.map((b) => b.id).toSet();
  if (assets.map((a) => a.id).toSet().length != assets.length ||
      boxIds.length != boxes.length)
    throw const FormatException('Duplicate inventory IDs');
  if (assets.any((a) => a.boxId.isNotEmpty && !boxIds.contains(a.boxId)))
    throw const FormatException('Asset refers to missing box');
  return KeepState(assets: assets, boxes: boxes);
}

InventoryAsset createAsset({
  required String id,
  required String name,
  String? now,
  Map<String, Object?> fields = const {},
}) {
  final at = now ?? _now();
  return InventoryAsset.fromJson({
    'id': id,
    'name': name,
    'location': '',
    'serial': '',
    'notes': '',
    'purchasedOn': '',
    'warrantyUntil': '',
    'maintenanceDue': '',
    'borrower': '',
    'lentOn': '',
    'returnDue': '',
    'boxId': '',
    'photoUri': '',
    'createdAt': at,
    'updatedAt': at,
    ...fields,
  });
}

KeepState saveAsset(KeepState state, InventoryAsset asset) =>
    validateKeepState({
      'version': 1,
      'assets': state.assets.any((a) => a.id == asset.id)
          ? state.assets
                .map((a) => a.id == asset.id ? asset.toJson() : a.toJson())
                .toList()
          : [...state.assets.map((a) => a.toJson()), asset.toJson()],
      'boxes': state.boxes.map((b) => b.toJson()).toList(),
    });
KeepState removeAsset(KeepState state, String id) => validateKeepState({
  'version': 1,
  'assets': state.assets
      .where((a) => a.id != id)
      .map((a) => a.toJson())
      .toList(),
  'boxes': state.boxes.map((b) => b.toJson()).toList(),
});
KeepState saveBox(KeepState state, InventoryBox box) => validateKeepState({
  'version': 1,
  'assets': state.assets.map((a) => a.toJson()).toList(),
  'boxes': state.boxes.any((b) => b.id == box.id)
      ? state.boxes
            .map((b) => b.id == box.id ? box.toJson() : b.toJson())
            .toList()
      : [...state.boxes.map((b) => b.toJson()), box.toJson()],
});
KeepState removeBox(KeepState state, String id) => validateKeepState({
  'version': 1,
  'assets': state.assets
      .map(
        (a) => a.boxId == id ? a.copyWith({'boxId': ''}).toJson() : a.toJson(),
      )
      .toList(),
  'boxes': state.boxes.where((b) => b.id != id).map((b) => b.toJson()).toList(),
});
InventoryAsset _asset(KeepState state, String id) => state.assets.firstWhere(
  (a) => a.id == id,
  orElse: () => throw const FormatException('Asset not found'),
);
KeepState lendAsset(
  KeepState state,
  String id,
  String borrower,
  String lentOn,
  String returnDue, {
  String? now,
}) => saveAsset(
  state,
  _asset(state, id).copyWith({
    'borrower': borrower,
    'lentOn': lentOn,
    'returnDue': returnDue,
    'updatedAt': now ?? _now(),
  }),
);
KeepState returnAsset(KeepState state, String id, {String? now}) => saveAsset(
  state,
  _asset(state, id).copyWith({
    'borrower': '',
    'lentOn': '',
    'returnDue': '',
    'updatedAt': now ?? _now(),
  }),
);
List<InventoryAsset> searchAssets(KeepState state, String query) {
  final words = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final boxes = {for (final b in state.boxes) b.id: b};
  return state.assets.where((a) {
    final b = boxes[a.boxId],
        haystack = [
          a.name,
          a.location,
          a.serial,
          a.borrower,
          a.notes,
          b?.name ?? '',
          b?.location ?? '',
        ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }).toList();
}

List<InventoryAsset> assetsInBox(KeepState state, String id) =>
    state.assets.where((a) => a.boxId == id).toList();

class KeepReminder {
  final String assetId, kind, date;
  final bool overdue;
  const KeepReminder(this.assetId, this.kind, this.date, this.overdue);
}

List<KeepReminder> getKeepReminders(KeepState state, String today) {
  if (!isCalendarDate(today))
    throw const FormatException('Invalid current calendar date');
  final results = <KeepReminder>[];
  for (final a in state.assets) {
    for (final pair in [
      ('loan', a.borrower.isNotEmpty ? a.returnDue : ''),
      ('maintenance', a.maintenanceDue),
      ('warranty', a.warrantyUntil),
    ]) {
      if (pair.$2.isNotEmpty)
        results.add(
          KeepReminder(a.id, pair.$1, pair.$2, pair.$2.compareTo(today) < 0),
        );
    }
  }
  results.sort((a, b) {
    final date = a.date.compareTo(b.date);
    return date != 0 ? date : a.assetId.compareTo(b.assetId);
  });
  return results;
}

void _backupSize(String source) {
  if (source.length > keepBackupBytes ||
      utf8.encode(source).length > keepBackupBytes)
    throw const FormatException('Inventory backup is too large');
}

String serializeKeepState(KeepState state) {
  final source = jsonEncode(validateKeepState(state.toJson()).toJson());
  _backupSize(source);
  return source;
}

KeepState parseKeepState(String source) {
  _backupSize(source);
  return validateKeepState(jsonDecode(source));
}

KeepState _stripPaths(KeepState state) => KeepState(
  assets: state.assets.map(
    (a) => a.copyWith({
      'photoUri': '',
      if (a.toJson().containsKey('receipts')) 'receipts': [],
    }),
  ),
  boxes: state.boxes,
);
String exportKeepBackup(KeepState state) {
  final source = const JsonEncoder.withIndent(
    '  ',
  ).convert(_stripPaths(validateKeepState(state.toJson())).toJson());
  _backupSize(source);
  return source;
}

KeepState parseKeepBackup(String source) => _stripPaths(parseKeepState(source));
