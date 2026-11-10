part of '../handy_habit_engine.dart';

/// A daily reflection. Deletion retains the payload for explicit restore/Undo.
/// Day identity is stable across devices; concurrent revisions must not average.
class MoodEntry {
  final String day, recordedAt, updatedAt, note;
  final int mood, revision;
  final int? energy;
  final List<String> tags;
  final String? deletedAt;
  String get id => 'mood:$day';
  bool get deleted => deletedAt != null;
  MoodEntry({
    required this.day,
    required this.mood,
    required String recordedAt,
    String? updatedAt,
    this.energy,
    this.note = '',
    List<String> tags = const [],
    this.revision = 1,
    String? deletedAt,
  }) : tags = List.unmodifiable(tags),
       recordedAt = timestamp(recordedAt),
       updatedAt = timestamp(updatedAt ?? recordedAt),
       deletedAt = deletedAt == null ? null : timestamp(deletedAt) {
    date(day);
    integer(mood, min: 1, max: 5);
    if (energy != null) integer(energy, min: 1, max: 5);
    integer(revision, min: 1);
    text(note, max: 4096);
    if (tags.length > 8 ||
        tags.toSet().length != tags.length ||
        tags.any((t) => t.trim().isEmpty || t != t.trim() || t.length > 40)) {
      throw const FormatException(
        'Use up to 8 distinct tags, 40 characters each / Dùng tối đa 8 nhãn khác nhau, mỗi nhãn 40 ký tự',
      );
    }
    if (DateTime.parse(
          this.updatedAt,
        ).isBefore(DateTime.parse(this.recordedAt)) ||
        this.deletedAt != null && this.deletedAt != this.updatedAt) {
      throw const FormatException('Invalid mood timestamps');
    }
  }
  Json toJson() => {
    'id': id,
    'day': day,
    'mood': mood,
    'energy': energy,
    'note': note,
    'tags': tags,
    'revision': revision,
    'recordedAt': recordedAt,
    'updatedAt': updatedAt,
    'deletedAt': deletedAt,
  };
  factory MoodEntry.fromJson(Json j) {
    final entry = MoodEntry(
      day: text(j['day']),
      mood: integer(j['mood'], min: 1, max: 5),
      energy: j['energy'] == null ? null : integer(j['energy'], min: 1, max: 5),
      note: text(j['note']),
      tags: List<String>.from(j['tags'] as List),
      revision: integer(j['revision'], min: 1),
      recordedAt: timestamp(j['recordedAt']),
      updatedAt: timestamp(j['updatedAt']),
      deletedAt: j['deletedAt'] == null ? null : timestamp(j['deletedAt']),
    );
    if (j['id'] != entry.id)
      throw const FormatException('Invalid mood identity');
    return entry;
  }
}

MoodEntry? moodOn(HabitState s, String day, {bool includeDeleted = false}) => s
    .moods
    .where((m) => m.day == day && (includeDeleted || !m.deleted))
    .firstOrNull;

/// Draft mutation; recordChange commits the causal row revision with its parents.
HabitState saveMood(
  HabitState s,
  String day,
  int mood, {
  int? energy,
  String note = '',
  List<String> tags = const [],
  required DateTime now,
  required int expectedRevision,
}) {
  final old = moodOn(s, day, includeDeleted: true);
  if ((old?.revision ?? 0) != expectedRevision)
    throw StateError(
      'Mood changed; reopen it before editing / Tâm trạng đã đổi; mở lại trước khi sửa',
    );
  final stamp = _moodStamp(old, now);
  final entry = MoodEntry(
    day: day,
    mood: mood,
    energy: energy,
    note: note,
    tags: tags,
    recordedAt: old?.recordedAt ?? stamp,
    updatedAt: stamp,
    revision: (old?.revision ?? 0) + 1,
  );
  return s.copy({
    'moods': [
      for (final m in s.moods)
        if (m.day != day) m.toJson(),
      entry.toJson(),
    ],
  });
}

String _moodStamp(MoodEntry? old, DateTime now) {
  final previous = old == null ? null : DateTime.parse(old.updatedAt);
  final stamp = now.toUtc();
  return (previous != null && !stamp.isAfter(previous)
          ? previous.add(const Duration(microseconds: 1))
          : stamp)
      .toIso8601String();
}

HabitState deleteMood(
  HabitState s,
  String day, {
  required DateTime now,
  required int expectedRevision,
}) {
  final old = moodOn(s, day);
  if (old == null || old.revision != expectedRevision)
    throw StateError(
      'Mood changed; reopen it before deleting / Tâm trạng đã đổi; mở lại trước khi xóa',
    );
  final stamp = _moodStamp(old, now);
  return s.copy({
    'moods': [
      for (final m in s.moods)
        if (m.day == day)
          {
            ...m.toJson(),
            'revision': m.revision + 1,
            'updatedAt': stamp,
            'deletedAt': stamp,
          }
        else
          m.toJson(),
    ],
  });
}

HabitState restoreMood(
  HabitState s,
  String day, {
  required DateTime now,
  required int expectedRevision,
}) {
  final old = moodOn(s, day, includeDeleted: true);
  if (old == null || !old.deleted || old.revision != expectedRevision)
    throw StateError(
      'Deleted mood changed; reopen it / Bản ghi đã xóa đã đổi; hãy mở lại',
    );
  return saveMood(
    s,
    day,
    old.mood,
    energy: old.energy,
    note: old.note,
    tags: old.tags,
    now: now,
    expectedRevision: expectedRevision,
  );
}
