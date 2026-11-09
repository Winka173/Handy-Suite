import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';
import '../reader/keep_pictures.dart';

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

  /// The day's own check, which nobody started.
  final bool quiet;
  const LinkJobReport({
    required this.job,
    required this.asked,
    required this.done,
    required this.overCap,
    required this.cancelled,
    required this.counts,
    this.quiet = false,
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
/// already found are kept when the person stops. Besides what a person
/// starts, [dailyCheck] asks about a few links once a day, quietly, when
/// Settings allows it (on while pages are read after saving).
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

  /// The day's own check is running: no strip, and a report only when it
  /// found a broken link.
  bool quiet = false;
  Future<LinkJobReport>? _quietRun;

  /// How many links the day's check asks about.
  static const dailyCount = 60;

  /// Stops the day's check (a person wants a job of their own) and waits
  /// for it to end; what it found so far is kept.
  Future<void> stopQuiet() async {
    if (!quiet) return;
    cancel();
    try {
      await _quietRun;
    } catch (_) {}
  }

  /// The day's check is allowed: Settings > Advanced library tools. It
  /// follows "Read pages after saving" until set on its own.
  static bool dailyAllowed(Map<String, dynamic> prefs) =>
      prefs['dailyLinkCheck'] as bool? ?? prefs['automaticMetadata'] != false;

  /// The links the day's check asks about: never checked first, then the
  /// ones checked longest ago; none checked in the last week.
  static List<String> dailyPick(
    SaveLibrary l,
    DateTime now, {
    int count = dailyCount,
  }) {
    final cutoff = now.toUtc().subtract(const Duration(days: 7));
    final list = [
      for (final b in l.bookmarks)
        if (b.hasUrl)
          (
            b.id,
            b.linkCheck == null
                ? null
                : DateTime.tryParse(b.linkCheck!.checkedAt),
          ),
    ]..removeWhere((e) => e.$2 != null && e.$2!.isAfter(cutoff));
    list.sort(
      (a, b) => a.$2 == null
          ? (b.$2 == null ? 0 : -1)
          : b.$2 == null
          ? 1
          : a.$2!.compareTo(b.$2!),
    );
    return [for (final e in list.take(count)) e.$1];
  }

  /// Once a day: checks a few links without a strip or a question. A link
  /// found broken is only marked (Broken links, and its card is greyed),
  /// never deleted or changed. Offline (nothing answers), it stops at once
  /// and tries again later the same day.
  Future<LinkJobReport?> dailyCheck({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final day = at.toIso8601String().substring(0, 10);
    final l = c.library;
    if (running ||
        l == null ||
        !c.networkAvailable ||
        !dailyAllowed(c.preferences) ||
        c.preferences['linkCheckDay'] == day)
      return null;
    Future<void> markDay() =>
        c.update((l) => l, prefs: {...c.preferences, 'linkCheckDay': day});
    final ids = dailyPick(l, at);
    if (ids.isEmpty) {
      await markDay();
      return null;
    }
    quiet = true;
    final LinkJobReport r;
    try {
      r = await (_quietRun = checkLinks(ids, limit: ids.length, quiet: true));
    } finally {
      quiet = false;
      _quietRun = null;
    }
    final reached = r.done > 0 && r.count('unreachable') < r.done;
    if (reached) await markDay();
    // Nothing to tell: no strip, no report.
    if (!reached || r.broken == 0) {
      last = null;
      notifyListeners();
    }
    return r;
  }

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
        if (wanted.contains(b.id) && b.hasUrl) b,
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
        quiet: quiet,
      );
      notifyListeners();
    }
    return last!;
  }

  void _tally(String key) => _counts[key] = (_counts[key] ?? 0) + 1;

  /// Checks each link (HEAD, then GET) and records ok / moved / gone /
  /// unreachable with the date. Never changes an address by itself.
  ///
  /// [quiet] (the day's check): no "unreachable" is kept until some site
  /// has answered, so a phone that is offline marks nothing; five in a row
  /// that nothing answers end the run.
  Future<LinkJobReport> checkLinks(
    Iterable<String> ids, {
    int limit = maxChecks,
    bool quiet = false,
  }) {
    if (limit < 1 || limit > maxChecks)
      throw RangeError.range(limit, 1, maxChecks);
    final found = <String, (String, LinkCheck)>{};
    var reached = false, silent = 0;
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

    return _run(LinkJob.check, ids, limit, (b, token) async {
      final probe = await _patient(
        () => c.metadata.probe(b.originalUrl, cancellation: token),
        (p) => p.error,
        token,
      );
      token.check();
      final check = classifyLinkProbe(b.originalUrl, probe, saveTime());
      _tally(check.status);
      if (quiet && !reached) {
        if (check.status == 'unreachable') {
          if (++silent >= 5) token.cancel();
          return;
        }
        reached = true;
      }
      found[b.id] = (b.originalUrl, check);
      if (found.length >= 10) await save();
    }, flush: save);
  }

  /// Fetches each page and keeps its readable text as an offline copy.
  Future<LinkJobReport> saveCopies(
    Iterable<String> ids, {
    int limit = maxCopies,
  }) {
    if (limit < 1 || limit > maxCopies)
      throw RangeError.range(limit, 1, maxCopies);
    return _run(LinkJob.reading, ids, limit, (b, token) async {
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
      final kept = await withArticlePictures(c.metadata, copy, token);
      token.check();
      try {
        await c.putReadingCopies({b.id: kept});
        _tally('saved');
      } catch (_) {
        // Deleted meanwhile, or storage refused: nothing half-written.
        _tally('failed');
      }
    });
  }
}
