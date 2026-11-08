import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/app.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/data/import_export.dart';
import 'package:handy_bookmark/links/link_tasks.dart';
import 'package:handy_bookmark/scope.dart';
import 'package:handy_bookmark/services/reminders.dart';
import 'package:handy_bookmark/view/library_view.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'backup_restore_test.dart' show photo, wait;
import 'collection_view_test.dart' show twoCollections;
import 'controller_test.dart' show TestStore;
import 'link_tasks_test.dart' show FakeNet;
import 'new_flows_test.dart' show NetController, OneFile, boot, settle;
import 'widget_test.dart' show Preferences, tapKey;

/// Stands in for the OS: what is scheduled is what the last sync asked for.
class FakeReminders extends SaveReminders {
  final scheduled = <String>{};
  int syncs = 0;
  @override
  bool get supported => true;
  @override
  Future<String?> initialize(
    ValueChanged<String> onOpen, {
    VoidCallback? onButton,
  }) async => null;
  @override
  Future<bool> allowedNow() async => true;
  @override
  Future<bool> exactAllowed() async => true;
  @override
  Future<bool> request() async => true;
  @override
  Future<void> sync(
    List<Bookmark> bookmarks, {
    required bool enabled,
    required bool vietnamese,
  }) async {
    syncs++;
    final now = DateTime.now();
    scheduled
      ..clear()
      ..addAll([
        if (enabled)
          for (final b in bookmarks)
            if (b.reminderAt != null &&
                DateTime.parse(b.reminderAt!).isAfter(now))
              b.id,
      ]);
  }
}

SaveScope scopeOf(SaveController c, HandyFiles files) {
  final view = LibraryView(c);
  addTearDown(view.dispose);
  return SaveScope(
    c: c,
    view: view,
    files: files,
    reminders: FakeReminders(),
    tasks: LinkTasks(c),
  );
}

Future<void> passTime(WidgetTester t) async {
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 450)),
  );
  await t.pump(const Duration(milliseconds: 400));
  await settle(t);
}

/// Runs [f] to its end while real time (isolates) and frames both move.
Future<T> drive<T>(WidgetTester t, Future<T> f) async {
  late T value;
  Object? error;
  var done = false;
  f.then(
    (v) {
      value = v;
      done = true;
    },
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 100 && !done; i++) {
    await wait(t, 100);
  }
  if (error != null) throw error!;
  expect(done, isTrue, reason: 'finished in time');
  return value;
}

void main() {
  testWidgets('turning every reminder off cancels what was scheduled', (
    t,
  ) async {
    final reminders = FakeReminders();
    final c = NetController(TestStore(), FakeNet());
    await t.runAsync(c.initialize);
    await c.quickSave('https://a.com/one', title: 'One');
    await t.pumpWidget(
      SaveApp(
        controller: c,
        files: OneFile(),
        reminders: reminders,
        preferences: Preferences(),
        device: false,
        guide: false,
      ),
    );
    addTearDown(c.dispose);
    await settle(t);
    final id = c.library!.bookmarks.single.id;
    final due = DateTime.now().add(const Duration(days: 1)).toUtc();
    await drive(
      t,
      c.update(
        (l) => l.copyWith(
          bookmarks: [
            l.bookmarks.single.copyWith(reminderAt: due.toIso8601String()),
          ],
        ),
        prefs: {...c.preferences, 'notifications': true},
      ),
    );
    await passTime(t);
    expect(reminders.scheduled, {id});

    await drive(
      t,
      c.update((l) => l, prefs: {...c.preferences, 'notifications': false}),
    );
    await passTime(t);
    expect(reminders.scheduled, isEmpty, reason: 'nothing left with the OS');

    // Once cleared, later changes do not ask the OS again.
    final syncs = reminders.syncs;
    await drive(t, c.quickSave('https://b.com/two', title: 'Two'));
    await passTime(t);
    expect(reminders.syncs, syncs);
  });

  testWidgets('an automatic backup records what it left out, and is not '
      'called complete', (t) async {
    final files = OneFile()..next = ImportedBytes('p.jpg', photo());
    final (c, _) = await boot(t, files: files);
    final scope = scopeOf(c, files);
    final store = c.store as TestStore;

    // Everything present: a complete backup.
    await drive(t, scope.fullBackup());
    expect(c.lastBackup!.complete, isTrue);
    expect(c.lastBackup!.automatic, isTrue);
    expect(c.lastBackup!.links, 3);

    // A picture gone from the device, and an offline copy that no longer
    // reads.
    await drive(t, c.addPictures([(bytes: photo(), name: 'p.jpg')]));
    store.ownedMedia.clear();
    store.reading[c.library!.bookmarks.first.id] = {'broken': true};
    final bytes = await drive(t, scope.fullBackup());
    expect(bytes, isNotEmpty, reason: 'the backup is still written');
    final r = c.lastBackup!;
    expect(r.complete, isFalse);
    expect(
      r.omissions,
      unorderedEquals({
        const BackupOmission('pictures', OmissionReason.missing, 1),
        const BackupOmission('readingCopies', OmissionReason.unreadable, 1),
      }),
    );
    // Kept with this device's settings, so Settings can show it later.
    expect(
      BackupReport.fromJson(
        (store.state['preferences'] as Map)[SaveController.lastBackupKey],
      )!.toJson(),
      r.toJson(),
    );
  });

  testWidgets('how each collection is shown survives a ZIP backup and '
      'restore, beside choices the file does not mention', (t) async {
    final (a, _) = await boot(t, seed: twoCollections);
    const views = {
      'food': {'cards': true, 'sort': 'oldest'},
      'trip': {'sort': 'title'},
    };
    await drive(
      t,
      a.update((l) => l, prefs: {...a.preferences, 'collectionViews': views}),
    );
    final zip = await drive(t, scopeOf(a, OneFile()).fullBackup());
    await t.pumpWidget(const SizedBox());

    // Another device with a choice of its own for a collection the file
    // does not have.
    final files = OneFile()..next = ImportedBytes('handy-bookmark.zip', zip);
    final (b, _) = await boot(t, files: files, urls: const []);
    await drive(
      t,
      b.update(
        (l) => l.copyWith(
          collections: [SaveCollection(id: 'mine', name: 'Mine')],
        ),
        prefs: {
          ...b.preferences,
          'collectionViews': {
            'mine': {'cards': true},
          },
        },
      ),
    );
    final scope = scopeOf(b, files);
    unawaited(scope.importLinks(t.element(find.byType(Scaffold).first)));
    await wait(t);
    await tapKey(t, 'import-replace');
    await tapKey(t, 'confirm-action');
    await wait(t);
    expect(b.library!.collections.map((c) => c.id), {'food', 'trip'});
    expect(b.preferences['collectionViews'], {
      'mine': {'cards': true},
      ...views,
    });
  });
}
