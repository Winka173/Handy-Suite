import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

/// Test child intentionally dies with a transaction open. No production hooks.
Future<void> main(List<String> args) async {
  if (args[1] == 'sync') {
    final part = File('${args[0]}/handy-habit/commits/killed.part');
    await part.parent.create(recursive: true);
    await part.writeAsString('incomplete generation', flush: true);
  } else {
    final db = sqlite3.open(args[0]);
    db.execute('PRAGMA journal_mode=WAL; BEGIN IMMEDIATE');
    db.execute('DELETE FROM events');
    db.execute('UPDATE state SET payload=? WHERE id=1', [
      jsonEncode({'interrupted': args[1]}),
    ]);
    if (args[1] == 'migration') db.execute('PRAGMA user_version=99');
    if (args[1] == 'restore')
      db.execute("INSERT OR REPLACE INTO recovery VALUES(1,'incomplete')");
  }
  stdout.writeln('READY');
  await stdout.flush();
  await stdin.first; // Parent terminates this process, never sends a commit.
}
