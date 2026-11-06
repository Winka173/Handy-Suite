import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';
import '../services/metadata_types.dart' show PageResult;

/// Where the reader is with one item's text.
enum ReaderState {
  /// Looking for a saved copy on this device.
  opening,

  /// Reading the page online, on the person's tap of Read.
  fetching,

  /// A text is on screen: the saved copy, or the page read online.
  reading,

  /// The online read stopped or failed; [ReaderSession.problem] says why.
  failed,

  /// There is nothing this reader can show (a picture, a deleted item, an
  /// address that is not a web page, or reading online is off here).
  unreadable,
}

ReadingCopy? _extract((String, String, String, String) v) =>
    extractReadingCopy(v.$1, url: v.$2, savedAt: v.$3, fallbackTitle: v.$4);

/// True for the addresses this reader may fetch: http and https only.
bool isWebAddress(String url) {
  final u = Uri.tryParse(url);
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}

/// One opening of the reader. Shows the saved copy when there is one;
/// otherwise reads the page online through the same safe fetch as offline
/// copies (public addresses only, bounded size and time, no cookies), once,
/// because the person asked to read it. Nothing is fetched in the
/// background and nothing is kept unless they choose Save offline.
class ReaderSession extends ChangeNotifier {
  ReaderSession(
    this.c,
    this.id, {
    this.retryDelay = const Duration(milliseconds: 1500),
  });
  final SaveController c;
  final String id;
  final Duration retryDelay;

  ReaderState state = ReaderState.opening;
  ReadingCopy? copy;

  /// The text on screen came from the page just now and is not saved.
  bool online = false;
  bool saving = false;

  /// Why the reader shows no text: deleted, picture, notWeb, browser,
  /// cancelled, noText, or a fetch error code (httpStatus, timeout…).
  String? problem;
  CancellationToken? _token;
  bool _disposed = false;

  Bookmark? get bookmark =>
      c.library?.bookmarks.where((b) => b.id == id).firstOrNull;

  void _set(void Function() change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _stop(ReaderState s, String why) => _set(() {
    state = s;
    problem = why;
    copy = null;
    online = false;
  });

  Future<void> open() async {
    final b = bookmark;
    if (b == null) return _stop(ReaderState.unreadable, 'deleted');
    ReadingCopy? saved;
    try {
      saved = await c.readingCopy(id);
    } catch (_) {
      // The stored copy could not be opened; reading online still can.
    }
    if (saved != null) {
      return _set(() {
        copy = saved;
        online = false;
        problem = null;
        state = ReaderState.reading;
      });
    }
    await readOnline();
  }

  /// Reads the page now. Safe to call again after a failure (Try again).
  Future<void> readOnline() async {
    final b = bookmark;
    if (b == null) return _stop(ReaderState.unreadable, 'deleted');
    if (b.isImage || !b.hasUrl) {
      return _stop(ReaderState.unreadable, 'picture');
    }
    if (!isWebAddress(b.originalUrl)) {
      return _stop(ReaderState.unreadable, 'notWeb');
    }
    if (!c.networkAvailable) {
      return _stop(ReaderState.unreadable, 'browser');
    }
    _token?.cancel();
    final token = CancellationToken();
    _token = token;
    _set(() {
      state = ReaderState.fetching;
      problem = null;
      copy = null;
      online = false;
    });
    try {
      Future<PageResult> ask() =>
          c.metadata.fetchPage(b.originalUrl, cancellation: token);
      var page = await ask();
      // Another job may be using the network; wait a moment, twice at most.
      for (var i = 0; i < 2; i++) {
        if (page.errorCode != 'busy' && page.errorCode != 'rateLimited') {
          break;
        }
        await _wait(retryDelay, token);
        page = await ask();
      }
      token.check();
      final html = page.html;
      if (html == null) {
        throw _Failed(page.errorCode ?? 'networkUnavailable');
      }
      final read = await compute(_extract, (
        html,
        (page.uri ?? Uri.parse(b.originalUrl)).toString(),
        saveTime(),
        b.title,
      ));
      token.check();
      if (read == null) throw const _Failed('noText');
      if (_token != token) return;
      _set(() {
        copy = read;
        online = true;
        state = ReaderState.reading;
      });
    } on Cancelled {
      if (_token == token) _stop(ReaderState.failed, 'cancelled');
    } on _Failed catch (e) {
      if (_token != token) return;
      _stop(
        ReaderState.failed,
        token.isCancelled || e.code == 'cancelled' ? 'cancelled' : e.code,
      );
    } catch (_) {
      if (_token == token) _stop(ReaderState.failed, 'networkUnavailable');
    } finally {
      if (_token == token) _token = null;
    }
  }

  /// Stops the online read at once; whatever arrives later is dropped.
  void cancel() {
    final token = _token;
    if (token == null) return;
    token.cancel();
    _token = null;
    _stop(ReaderState.failed, 'cancelled');
  }

  Future<void> _wait(Duration d, CancellationToken token) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      token.check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Keeps the text read online as this item's offline copy, without
  /// fetching again. True when it was saved.
  Future<bool> saveOffline() async {
    final r = copy;
    if (r == null || !online || saving) return false;
    _set(() => saving = true);
    try {
      final kept = ReadingCopy(
        url: r.url,
        title: r.title,
        savedAt: saveTime(),
        byline: r.byline,
        siteName: r.siteName,
        blocks: r.blocks,
        truncated: r.truncated,
      );
      await c.putReadingCopies({id: kept});
      _set(() {
        copy = kept;
        online = false;
      });
      return true;
    } catch (_) {
      // Deleted meanwhile, or storage refused: nothing half-written.
      return false;
    } finally {
      _set(() => saving = false);
    }
  }

  @override
  void dispose() {
    _token?.cancel();
    _token = null;
    _disposed = true;
    super.dispose();
  }
}

class _Failed implements Exception {
  final String code;
  const _Failed(this.code);
}
