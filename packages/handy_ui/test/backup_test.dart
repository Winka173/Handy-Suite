import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/sealed.dart';
import 'package:handy_files/auto_backup.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';

class MemoryFolders implements BackupFolders {
  final files = <String, Uint8List>{};
  bool web = false;
  int chosen = 0;
  @override
  bool get supported => !web;
  @override
  bool get canChoose => true;
  @override
  Future<BackupFolder?> choose() async {
    chosen++;
    return const BackupFolder('tree', 'content://drive/Handy', 'Handy');
  }

  @override
  Future<bool> reachable(BackupFolder folder) async => true;
  @override
  Future<BackupEntry> write(
    BackupFolder f,
    String name,
    Uint8List bytes,
  ) async {
    files[name] = bytes;
    return BackupEntry(name, name);
  }

  @override
  Future<List<BackupEntry>> list(BackupFolder folder) async => [
    for (final n in files.keys) BackupEntry(n, n),
  ];
  @override
  Future<void> delete(BackupFolder folder, BackupEntry entry) async =>
      files.remove(entry.name);
  @override
  Future<void> forget(BackupFolder folder) async {}
}

Widget host(Widget child, {double width = 390}) => MediaQuery(
  data: MediaQueryData(size: Size(width, 900)),
  child: MaterialApp(
    theme: buildHandyTheme(const Color(0xFFB7791F), Brightness.light),
    home: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  final data = Uint8List.fromList(utf8.encode('backup'));

  testWidgets('choosing a folder backs up at once and shows where', (t) async {
    final folders = MemoryFolders();
    AutoBackupSettings? stored;
    final backup = HandyAutoBackup(
      app: 'keep',
      extension: 'zip',
      build: () async => data,
      store: (s) async => stored = s,
      initial: const AutoBackupSettings(),
      folders: folders,
    );
    await t.pumpWidget(host(HandyAutoBackupSection(backup: backup)));
    expect(find.text('No backup yet'), findsOneWidget);
    expect(find.byKey(const Key('backup-now')), findsNothing);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('backup-folder')));
      for (
        var i = 0;
        i < 50 && !(stored?.last != null && !backup.running);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await t.pumpAndSettle();
    expect(folders.files.keys.single, startsWith('handy-keep-'));
    expect(stored!.enabled, isTrue);
    expect(stored!.folder!.name, 'Handy');
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('Handy'), findsOneWidget);
    expect(find.textContaining('handy-keep-'), findsOneWidget);
    expect(find.byKey(const Key('backup-enabled')), findsOneWidget);
    // Keeping fewer copies saves at once.
    await t.tap(find.byKey(const Key('backup-every')).last);
    await t.tap(find.text('Weekly'));
    await t.pumpAndSettle();
    expect(stored!.everyHours, 168);
  });

  testWidgets('a write failure says so and offers a retry', (t) async {
    final backup = HandyAutoBackup(
      app: 'keep',
      extension: 'zip',
      build: () async => data,
      store: (_) async {},
      initial: const AutoBackupSettings(
        enabled: true,
        folder: BackupFolder('tree', 'x', 'Drive'),
        lastError: 'write',
      ),
      folders: MemoryFolders(),
    );
    await t.pumpWidget(host(HandyAutoBackupSection(backup: backup)));
    expect(find.text('The last backup could not be written.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the web says plainly that there is no folder', (t) async {
    final backup = HandyAutoBackup(
      app: 'keep',
      extension: 'zip',
      build: () async => data,
      store: (_) async {},
      initial: const AutoBackupSettings(),
      folders: MemoryFolders()..web = true,
    );
    await t.pumpWidget(host(HandyAutoBackupSection(backup: backup)));
    expect(find.textContaining('browser does not let'), findsOneWidget);
    expect(find.byKey(const Key('backup-folder')), findsNothing);
  });

  testWidgets('a locked backup asks for its password and retries', (t) async {
    late Uint8List sealed;
    await t.runAsync(() async {
      sealed = await seal(
        data,
        await SealKey.create('right-pass', iterations: 10000),
      );
    });
    Uint8List? opened;
    var done = false;
    await t.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              opened = await openSealedBackup(context, sealed);
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    Future<void> attempt(String password) async {
      await t.enterText(find.byKey(const Key('password-first')), password);
      await t.runAsync(() async {
        await t.tap(find.byKey(const Key('password-ok')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await t.pumpAndSettle();
    }

    await attempt('wrong-pass');
    expect(find.text('Wrong password.'), findsOneWidget);
    await attempt('right-pass');
    expect(done, isTrue);
    expect(opened, data);
    // A plain file passes through untouched.
    expect(
      await openSealedBackup(t.element(find.text('open')), data),
      same(data),
    );
  });

  testWidgets('sibling apps show only when they have a page', (t) async {
    await t.pumpWidget(host(const HandyMoreApps(app: 'keep', listings: {})));
    expect(find.text('Other Handy apps'), findsNothing);
    await t.pumpWidget(
      host(
        const HandyMoreApps(
          app: 'keep',
          listings: {
            'keep': 'https://example.org/keep',
            'spend': 'https://example.org/spend',
          },
        ),
        width: 1200,
      ),
    );
    expect(find.text('Other Handy apps'), findsOneWidget);
    expect(find.text('Handy Spend'), findsOneWidget);
    expect(find.text('Handy Keep'), findsNothing);
  });

  test('listing URLs must be https', () {
    expect(
      MonetizationConfig.parse(
        '{"keep":{"android":{"listingUrl":"https://play.google.com/x"}}}',
        'keep',
        'android',
      ).listingUrl,
      'https://play.google.com/x',
    );
    expect(
      () => MonetizationConfig.parse(
        '{"keep":{"android":{"listingUrl":"javascript:alert(1)"}}}',
        'keep',
        'android',
      ),
      throwsFormatException,
    );
  });
}
