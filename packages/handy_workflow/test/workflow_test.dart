import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_workflow/handy_workflow.dart';

void main() {
  test(
    'event-loop cancellation interrupts immediate-Future transforms',
    () async {
      final cancel = CancellationToken();
      var calls = 0;
      final steps = {
        'fast': WorkflowStep('fast', 'text/plain', 'text/plain', (s) async {
          calls++;
          return '$s!';
        }),
      };
      final running = execute(
        Recipe('Cancel', ['fast', 'fast', 'fast']),
        steps,
        'x',
        cancellation: cancel,
      );
      Timer.run(cancel.cancel);
      await expectLater(running, throwsA(isA<Cancelled>()));
      expect(calls, 1);
    },
  );
  test(
    'event-loop cancellation stops batch before subsequent outputs',
    () async {
      final cancel = CancellationToken();
      var calls = 0;
      final running = batch([1, 2, 3], (n) async {
        calls++;
        return n;
      }, cancellation: cancel);
      Timer.run(cancel.cancel);
      await expectLater(running, throwsA(isA<Cancelled>()));
      expect(calls, 1);
    },
  );
  test('UTF-8 input budget validates before processing', () async {
    var called = false;
    final steps = {
      'work': WorkflowStep('work', 'text/plain', 'text/plain', (s) async {
        called = true;
        return s;
      }),
    };
    await expectLater(
      execute(Recipe('Big', ['work']), steps, '😀' * 250001),
      throwsFormatException,
    );
    expect(called, false);
  });
  test('registry key cannot impersonate a different step identity', () {
    final map = {
      'work': WorkflowStep(
        'different',
        'text/plain',
        'text/plain',
        (s) async => s,
      ),
    };
    expect(
      () => plan(Recipe('Mismatch', ['work']), map, 'text/plain'),
      throwsFormatException,
    );
  });
  test('bounded batch does not materialize an infinite iterable', () async {
    Iterable<int> infinite() sync* {
      var n = 0;
      while (true) {
        yield n++;
      }
    }

    var called = false;
    await expectLater(
      batch(infinite(), (n) async {
        called = true;
        return n;
      }),
      throwsFormatException,
    );
    expect(called, false);
  });
  final registry = {
    'upper': WorkflowStep(
      'upper',
      'text/plain',
      'text/plain',
      (s) async => s.toUpperCase(),
    ),
    'image': WorkflowStep('image', 'image/png', 'image/png', (s) async => s),
  };
  test('legacy v1 recipe roundtrip and deterministic execution', () async {
    final r = Recipe.fromJson({
      'version': 1,
      'name': 'Việt',
      'steps': ['upper'],
    });
    expect(Recipe.fromJson(jsonDecode(r.export())).toJson(), r.toJson());
    expect(await execute(r, registry, 'xin chào'), 'XIN CHÀO');
  });
  test('contract validation runs before side effects', () {
    expect(
      () => plan(Recipe('bad', ['upper', 'image']), registry, 'text/plain'),
      throwsFormatException,
    );
    expect(
      () => plan(Recipe('bad', ['missing']), registry, 'text/plain'),
      throwsFormatException,
    );
  });
  test('malformed/oversized/versioned recipes rejected', () {
    for (final r in [
      null,
      {'version': 2},
      {
        'version': 1,
        'name': '',
        'steps': ['upper'],
      },
      {'version': 1, 'name': 'x', 'steps': []},
      {
        'version': 1,
        'name': 'x',
        'steps': [1],
      },
      {'version': 1, 'name': 'x', 'steps': List.filled(21, 'upper')},
    ]) {
      expect(() => Recipe.fromJson(r), throwsFormatException);
    }
  });
  test('cancel between steps prevents subsequent side effects', () async {
    final c = CancellationToken();
    var calls = 0;
    final map = {
      'stop': WorkflowStep('stop', 'text/plain', 'text/plain', (s) async {
        calls++;
        c.cancel();
        return s;
      }),
    };
    await expectLater(
      execute(Recipe('cancel', ['stop', 'stop']), map, 'x', cancellation: c),
      throwsA(isA<Cancelled>()),
    );
    expect(calls, 1);
  });
  test('output growth bounded by UTF8 not UTF16 character count', () async {
    final map = {
      'grow': WorkflowStep(
        'grow',
        'text/plain',
        'text/plain',
        (s) async => '😀' * 250001,
      ),
    };
    await expectLater(
      execute(Recipe('grow', ['grow']), map, 'x'),
      throwsFormatException,
    );
  });
  test('batch isolates file failures and honors cancellation', () async {
    final outputs = await batch([1, 2, 3], (int n) async {
      if (n == 2) throw const FormatException('bad file');
      return n * 2;
    });
    expect(outputs.map((o) => o.value), [2, null, 6]);
    expect(outputs[1].error, isA<FormatException>());
    final c = CancellationToken()..cancel();
    await expectLater(
      batch([1], (int n) async => n, cancellation: c),
      throwsA(isA<Cancelled>()),
    );
  });
}
