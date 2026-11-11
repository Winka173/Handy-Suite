part of '../handy_habit_engine.dart';

/// A routine handed to someone else, as Handy Bookmark hands on its
/// collections: one HTML page that any browser reads (the steps and their
/// minutes), with the routine itself in a marked comment that Handy Habit
/// reads back. Only the routine travels: no habits, records, runs, notes
/// of the day or mood; links to the sender's habits are left out.
const sharedRoutineMarker = 'HANDY_HABIT_ROUTINE_V1:';

/// The largest shared page read back.
const sharedRoutineMaxBytes = 2000000;

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// What leaves the device: the routine without anything tied to the
/// sender's own habits.
Json _portableRoutine(Routine r) {
  final j = r.toJson();
  j.remove('archived');
  j['steps'] = [
    for (final s in r.steps)
      {
        ...s.toJson(),
        'habit': null,
        'linkedValue': 1000,
        'logic': {...s.logic.toJson(), 'habitNotDone': null},
      },
  ];
  return j;
}

/// The page for [r], in English or Vietnamese.
String sharedRoutinePage(Routine r, {required bool vietnamese}) {
  String t(String en, String vi) => vietnamese ? vi : en;
  String minutes(int seconds) {
    final m = (seconds / 60).round();
    return seconds == 0
        ? t('no timer', 'không hẹn giờ')
        : t('$m min', '$m phút');
  }

  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'v': 1, 'routine': _portableRoutine(r)})),
  );
  final steps = StringBuffer();
  for (final (i, s) in r.steps.indexed) {
    steps.write(
      '<li><span class="n">${i + 1}</span><span class="t">${_esc(s.title)}'
      '${s.note.isEmpty ? '' : '<small>${_esc(s.note)}</small>'}</span>'
      '<span class="m">${minutes(s.seconds)}</span></li>\n',
    );
  }
  final total = minutes(r.planned);
  return '''<!doctype html>
<html lang="${vietnamese ? 'vi' : 'en'}">
<head>
<!-- $sharedRoutineMarker$payload -->
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(r.title)} · Handy Habit</title>
<style>
:root{--ground:#FAF7F2;--ink:#291C19;--muted:#66534C;--hue:#B42318;--tint:#F9E4DC;--card:#fff}
@media (prefers-color-scheme:dark){:root{--ground:#151312;--ink:#FFF5ED;--muted:#CCB9AC;--hue:#F07755;--tint:#42271F;--card:#211D1B}}
body{margin:0;background:var(--ground);color:var(--ink);font:16px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
main{max-width:640px;margin:0 auto;padding:32px 16px}
h1{font-size:32px;line-height:1.1;margin:0 0 6px;font-weight:800}
.sub{color:var(--muted);margin:0 0 24px}
ol{list-style:none;margin:0;padding:0;background:var(--card);border-radius:16px}
li{display:flex;gap:12px;align-items:center;padding:14px 16px;border-bottom:1px solid var(--tint)}
li:last-child{border-bottom:0}
.n{flex:none;width:30px;height:30px;border-radius:50%;background:var(--tint);color:var(--hue);display:grid;place-items:center;font-weight:800}
.t{flex:1}.t small{display:block;color:var(--muted)}
.m{color:var(--muted);white-space:nowrap}
.how{margin-top:24px;padding:16px;border-radius:16px;background:var(--tint)}
</style>
</head>
<body><main>
<h1>${_esc(r.title)}</h1>
<p class="sub">${t('${r.steps.length} steps', '${r.steps.length} bước')} · $total${r.note.isEmpty ? '' : ' · ${_esc(r.note)}'}</p>
<ol>
$steps</ol>
<p class="how">${t('To add this routine to Handy Habit: save this file, then in Handy Habit open Routines › New routine › Import a shared routine and choose it.', 'Để thêm quy trình này vào Handy Habit: lưu tệp này, rồi trong Handy Habit mở Quy trình › Quy trình mới › Nhập quy trình được chia sẻ và chọn tệp.')}</p>
</main></body>
</html>
''';
}

/// Whether [bytes] look like a page made by [sharedRoutinePage].
bool isSharedRoutine(Uint8List bytes) {
  if (bytes.length > sharedRoutineMaxBytes) return false;
  return utf8.decode(bytes, allowMalformed: true).contains(sharedRoutineMarker);
}

/// The routine in a shared page, ready to review before saving: a new id,
/// active, with no link to any habit. The whole routine is checked before
/// it is returned; anything broken throws [FormatException].
Routine readSharedRoutine(Uint8List bytes) {
  if (bytes.length > sharedRoutineMaxBytes)
    throw const FormatException('File too large');
  final String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    throw const FormatException('Not a shared routine');
  }
  final match = RegExp(
    '${RegExp.escape(sharedRoutineMarker)}([A-Za-z0-9_=-]+)',
  ).firstMatch(text);
  if (match == null) throw const FormatException('Not a shared routine');
  final Object? data;
  try {
    data = jsonDecode(utf8.decode(base64Url.decode(match.group(1)!)));
  } catch (_) {
    throw const FormatException('Broken shared routine');
  }
  if (data is! Map || data['v'] != 1 || data['routine'] is! Map)
    throw const FormatException('Unknown shared format');
  final raw = Map<String, dynamic>.from(data['routine'] as Map);
  final steps = raw['steps'];
  if (steps is! List || steps.isEmpty || steps.length > 100)
    throw const FormatException('A routine has 1 to 100 steps');
  final routine = Routine.fromJson({
    ...raw,
    'id': uid(),
    'archived': false,
    'steps': [
      for (final s in steps)
        {
          ...Map<String, dynamic>.from(s as Map),
          'habit': null,
          'linkedValue': 1000,
          'logic': {
            ...Map<String, dynamic>.from((s['logic'] ?? {}) as Map),
            'habitNotDone': null,
          },
        },
    ],
  });
  if (routine.title.trim().isEmpty)
    throw const FormatException('A routine needs a name');
  // The same checks as every saved state.
  HabitState(routines: [routine]).validate();
  return routine;
}
