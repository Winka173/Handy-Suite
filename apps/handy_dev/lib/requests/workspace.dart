import 'package:handy_core/handy_core.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_ui/kit.dart';
import '../http_transport.dart';

/// Requests, collections and environments for this session. What is written
/// to disk is always `exportWorkspace`: URLs without query values, no header
/// values, bodies or secrets. The full values live only in memory.
class Workspace extends ChangeNotifier {
  final DocumentRepository store;
  final HttpTransport transport;

  /// Where the opt-in send history lives, apart from the requests.
  final DocumentRepository? historyStore;
  Workspace(this.store, this.transport, {this.historyStore});

  /// Off until turned on; see [recordSend] for what one send keeps.
  SendHistory history = SendHistory();

  ApiWorkspace value = emptyWorkspace();
  bool loading = true, sending = false;
  Object? loadError;
  String? selected, environment;
  ApiResponse? response;

  /// The response the same request got the time before, to compare with.
  /// Session memory only, like every response.
  ApiResponse? previous;
  final _last = <String, ApiResponse>{};

  /// (English, Vietnamese) message of the last failed send.
  (String, String)? sendError;

  /// A request being written that is not saved yet (new, or from cURL).
  ApiRequest? draft;

  ApiRequest? get request =>
      value.requests.where((r) => r.id == selected).firstOrNull ??
      (draft?.id == selected ? draft : null);

  bool get saved => value.requests.any((r) => r.id == selected);

  void openDraft(ApiRequest r) {
    draft = r;
    select(r.id);
  }

  /// Saves into the request's collection, or the first one when new.
  Future<void> save(ApiRequest r) async {
    await commit(
      saveRequest(
        value,
        r,
        collectionId: value.requests.any((x) => x.id == r.id)
            ? null
            : value.collections.first.id,
      ),
    );
    if (draft?.id == r.id) draft = null;
    select(r.id);
  }

  ApiEnvironment? get env =>
      value.environments.where((e) => e.id == environment).firstOrNull;

  Future<void> load() async {
    try {
      final h = await historyStore?.load();
      history = h == null ? SendHistory() : parseSendHistory(h);
    } catch (_) {
      // A history that cannot be read starts again, off; requests still load.
      history = SendHistory();
    }
    try {
      final text = await store.load();
      value = text == null ? emptyWorkspace() : parseWorkspace(text);
      loadError = null;
    } catch (e) {
      loadError = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Writes the sanitized copy first; the screen changes only after it.
  Future<void> commit(ApiWorkspace next) async {
    await store.save(exportWorkspace(next));
    value = next;
    notifyListeners();
  }

  void select(String? id) {
    if (id != draft?.id) draft = null;
    selected = id;
    response = null;
    previous = null;
    sendError = null;
    notifyListeners();
  }

  void useEnvironment(String? id) {
    environment = id;
    notifyListeners();
  }

  /// Turning it off forgets every send at once.
  Future<void> keepHistory(bool on) =>
      _writeHistory(switchSendHistory(history, on));

  Future<void> _writeHistory(SendHistory next) async {
    await historyStore?.save(exportSendHistory(next));
    history = next;
    notifyListeners();
  }

  /// Opens the saved request a past send came from.
  void openSent(SentRequest s) {
    if (value.requests.any((r) => r.id == s.requestId)) select(s.requestId);
  }

  static String newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}';

  Future<void> send(ApiRequest r) async {
    if (sending) return;
    sending = true;
    sendError = null;
    response = null;
    previous = null;
    notifyListeners();
    try {
      response = await transport.send(
        prepareRequest(r, env?.values ?? const {}),
      );
      previous = _last[r.id];
      _last[r.id] = response!;
      await _remember(r, response);
    } on Cancelled {
      sendError = ('Request cancelled.', 'Đã hủy request.');
    } on FormatException catch (e) {
      sendError = (e.message, e.message);
    } catch (e) {
      sendError = (
        'Could not reach the server. Check the address and your connection.',
        'Không gọi được máy chủ. Kiểm tra địa chỉ và kết nối.',
      );
      await _remember(r, null);
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void cancel() => transport.cancel();

  /// A failed history write never turns a good send into an error.
  Future<void> _remember(ApiRequest r, ApiResponse? answer) async {
    if (!history.on) return;
    try {
      await _writeHistory(
        recordSend(
          history,
          r,
          at: DateTime.now(),
          status: answer?.status,
          elapsedMs: answer?.elapsedMs ?? 0,
          bytes: answer?.bytes ?? 0,
        ),
      );
    } catch (_) {}
  }
}
