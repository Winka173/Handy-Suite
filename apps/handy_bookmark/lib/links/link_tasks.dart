import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';

/// The two network jobs a person can start on purpose.
enum LinkJob { check, reading }

/// How a finished (or stopped) job went.
class LinkJobReport {
  final LinkJob job;

  /// Links asked for, links handled, and links left out by the per-run cap.
  final int asked, done, overCap;
  final bool cancelled;

  /// check: ok / moved / gone / unreachable. reading: saved / noText / failed.
  final Map<String, int> counts;
  const LinkJobReport({
    required this.job,
    required this.asked,
    required this.done,
    required this.overCap,
    required this.cancelled,
    required this.counts,
  });
  int count(String key) => counts[key] ?? 0;
  int get broken => count('moved') + count('gone') + count('unreachable');
}

String _host(Bookmark b) => Uri.tryParse(b.originalUrl)?.host ?? '';

ReadingCopy? _extract((String, String, String, String) v) =>
    extractReadingCopy(v.$1, url: v.$2, savedAt: v.$3, fallbackTitle: v.$4);

/// Runs one link check or reading-copy job at a time over chosen links:
/// at most [maxChecks] / [maxCopies] per run, one request at a time, each
/// host asked at most every [hostSpacing], stoppable at any point. Results
/// already found are kept when the person stops. Nothing here runs unless
/// a person starts it.
class LinkTasks extends ChangeNotifier {
  LinkTasks(
    this.c, {
    this.hostSpacing = const Duration(milliseconds: 2100),
    this.retryDelay = const Duration(milliseconds: 2500),
  });
  final SaveController c;
  final Duration hostSpacing, retryDelay;
  static const maxChecks = 500, maxCopies = 200;

  LinkJob? job;
  int done = 0, total = 0;
  LinkJobReport? last;
  CancellationToken? _token;
  bool get running => job != null;
  final _counts = <String, int>{};

  /// The single link being worked on, for the detail view's own button.
  String? currentId;

  void cancel() => _token?.cancel();

  /// Forgets the last report (the person closed it).
  void dismiss() {
    last = null;
    notifyListeners();
  }

  Future<void> _sleep(Duration d, CancellationToken token) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      token.check();
      final left = end.difference(DateTime.now());
      await Future<void>.delayed(
        left < const Duration(milliseconds: 100)
            ? left
            : const Duration(milliseconds: 100),
      );
    }
  }

  /// Calls [ask] and, while the fetcher says it is busy or the host was
  /// asked too recently, waits and asks again (twice at most).
  Future<T> _patient<T>(
    Future<T> Function() ask,
    String? Function(T) error,
    CancellationToken token,
  ) async {
    var result = await ask();
    for (var i = 0; i < 2; i++) {
      final e = error(result);
      if (e != 'busy' && e != 'rateLimited') break;
      await _sleep(retryDelay, token);
      result = await ask();
    }
    return result;
  }

  Future<LinkJobReport> _run(
    LinkJob kind,
    Iterable<String> ids,
    int cap,
    Future<void> Function(Bookmark, CancellationToken) each, {
    Future<void> Function()? flush,
  }) async {
    if (running) throw StateError('Another job is running');
    if (!c.networkAvailable)
      throw UnsupportedError('Not available in the browser');
    final wanted = ids.toSet();
    final all = [
      for (final b in c.library!.bookmarks)
        if (wanted.contains(b.id)) b,
    ];
    final queue = all.take(cap).toList();
    final token = CancellationToken();
    _token = token;
    job = kind;
    done = 0;
    total = queue.length;
    _counts.clear();
    last = null;
    currentId = wanted.length == 1 ? wanted.first : null;
    notifyListeners();
    var cancelled = false;
    final started = <String, DateTime>{};
    try {
      while (queue.isNotEmpty) {
        token.check();
        final now = DateTime.now();
        bool ready(Bookmark b) {
          final at = started[_host(b)];
          return at == null || now.difference(at) >= hostSpacing;
        }

        final i = queue.indexWhere(ready);
        if (i < 0) {
          // Every waiting link shares a host asked a moment ago.
          final soonest = queue
              .map((b) => started[_host(b)]!.add(hostSpacing))
              .reduce((a, b) => a.isBefore(b) ? a : b);
          await _sleep(soonest.difference(now), token);
          continue;
        }
        final b = queue.removeAt(i);
        started[_host(b)] = DateTime.now();
        await each(b, token);
        done++;
        notifyListeners();
      }
    } on Cancelled {
      cancelled = true;
    } finally {
      try {
        await flush?.call();
      } catch (_) {
        _counts['failed'] = (_counts['failed'] ?? 0) + 1;
      }
      job = null;
      _token = null;
      currentId = null;
      last = LinkJobReport(
        job: kind,
        asked: all.length,
        done: done,
        overCap: all.length - total,
        cancelled: cancelled,
        counts: Map.of(_counts),
      );
      notifyListeners();
    }
    return last!;
  }

  void _tally(String key) => _counts[key] = (_counts[key] ?? 0) + 1;

  /// Checks each link (HEAD, then GET) and records ok / moved / gone /
  /// unreachable with the date. Never changes an address by itself.
  Future<LinkJobReport> checkLinks(Iterable<String> ids) {
    final found = <String, (String, LinkCheck)>{};
    Future<void> save() async {
      if (found.isEmpty) return;
      final batch = Map.of(found);
      found.clear();
      await c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              // Only if the address is still the one that was checked.
              if (batch[b.id] case (
                final url,
                final check,
              ) when url == b.originalUrl)
                b.copyWith(linkCheck: check)
              else
                b,
          ],
        ),
      );
    }

    return _run(LinkJob.check, ids, maxChecks, (b, token) async {
      final probe = await _patient(
        () => c.metadata.probe(b.originalUrl, cancellation: token),
        (p) => p.error,
        token,
      );
      token.check();
      final check = classifyLinkProbe(b.originalUrl, probe, saveTime());
      _tally(check.status);
      found[b.id] = (b.originalUrl, check);
      if (found.length >= 10) await save();
    }, flush: save);
  }

  /// Fetches each page and keeps its readable text as an offline copy.
  Future<LinkJobReport> saveCopies(Iterable<String> ids) =>
      _run(LinkJob.reading, ids, maxCopies, (b, token) async {
        final page = await _patient(
          () => c.metadata.fetchPage(b.originalUrl, cancellation: token),
          (p) => p.errorCode,
          token,
        );
        token.check();
        if (page.html == null) return _tally('failed');
        final copy = await compute(_extract, (
          page.html!,
          (page.uri ?? Uri.parse(b.originalUrl)).toString(),
          saveTime(),
          b.title,
        ));
        token.check();
        if (copy == null) return _tally('noText');
        try {
          await c.putReadingCopies({b.id: copy});
          _tally('saved');
        } catch (_) {
          // Deleted meanwhile, or storage refused: nothing half-written.
          _tally('failed');
        }
      });
}
