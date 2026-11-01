import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_media/capture_draft.dart';
import 'package:handy_media/capture_library.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'capture_test.dart' show Store, bundle;

void main() {
  testWidgets(
    'debounced recovery roundtrip preserves project and exact assets; clear waits for writes',
    (tester) async {
      final store = Store(), original = bundle();
      final draft = CaptureDraft(store, original.project.id);
      draft.schedule(() => original, (e) => fail('$e'));
      await tester.pump(const Duration(milliseconds: 499));
      expect(store.attempts, 0);
      await tester.pump(const Duration(milliseconds: 1));
      final loaded = (await draft.load())!;
      expect(loaded.project.serialize(), original.project.serialize());
      expect(loaded.assets.values.single, original.assets.values.single);
      draft.schedule(
        () => PortableCapture(
          original.project.copyWith(title: 'Latest'),
          original.assets,
        ),
        (e) => fail('$e'),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect((await draft.load())!.project.title, 'Latest');
      await draft.clear();
      await tester.pump(const Duration(seconds: 1));
      expect(await draft.load(), isNull);
      draft.dispose();
    },
  );

  testWidgets(
    'failed writes and corrupt or mismatched drafts preserve prior bytes',
    (tester) async {
      final original = bundle(), store = Store();
      store.text = CaptureLibrary([original]).serialize();
      final before = store.text, errors = <Object>[];
      final draft = CaptureDraft(store, original.project.id);
      store.fail = true;
      draft.schedule(() => original, errors.add);
      await tester.pump(const Duration(milliseconds: 500));
      expect(errors, hasLength(1));
      expect(store.text, before);
      await expectLater(draft.clear(), throwsStateError);
      store.fail = false;
      final wrong = CaptureDraft(store, 'other');
      await expectLater(wrong.load(), throwsFormatException);
      expect(store.text, before);
      store.text = '{broken';
      await expectLater(draft.load(), throwsFormatException);
      expect(store.text, '{broken');
      wrong.dispose();
      draft.dispose();
    },
  );

  testWidgets(
    'serialized backup cannot resurrect a cleared draft behind a slow write',
    (tester) async {
      final store = SlowStore(), original = bundle();
      final draft = CaptureDraft(store, original.project.id);
      draft.schedule(() => original, (e) => fail('$e'));
      await tester.pump(const Duration(milliseconds: 500));
      final clearing = draft.clear();
      store.pending.complete();
      await clearing;
      expect(await draft.load(), isNull);
      draft.dispose();
    },
  );
}

class SlowStore extends Store {
  final pending = Completer<void>();
  @override
  Future<void> save(String value) async {
    if (attempts == 0) {
      attempts++;
      await pending.future;
    }
    text = value;
  }
}
