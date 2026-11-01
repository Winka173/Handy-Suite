import 'package:handy_storage/documents.dart';
import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';

/// Optional on-device QR history. Off by default; never part of settings
/// backups. Every failure keeps the stored history as it was.
class QrHistoryController extends ChangeNotifier {
  final DocumentRepository store;
  QrHistoryController(this.store);
  QrHistory? history, pendingCleanup;
  bool loading = true, busy = false;

  /// (English, Vietnamese) message of the last failure, or null.
  (String, String)? error;

  bool get enabled => history?.enabled ?? false;

  Future<void> load() async {
    try {
      final raw = await store.load();
      history = raw == null ? QrHistory() : QrHistory.parse(raw);
      error = null;
    } catch (_) {
      error = (
        'History could not be opened. Saved data was kept.',
        'Chưa mở được lịch sử. Dữ liệu đã lưu được giữ nguyên.',
      );
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _commit(QrHistory next) async {
    await store.save(next.serialize());
    history = next;
    pendingCleanup = next;
    notifyListeners();
    // Replace the recovery slot too so cleared entries cannot reappear.
    try {
      await store.save(next.serialize());
      pendingCleanup = null;
    } catch (_) {
      throw const FormatException('cleanup');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on FormatException catch (e) {
      error = e.message == 'cleanup'
          ? (
              'History was updated, but the backup copy was not. Try again.',
              'Đã cập nhật lịch sử nhưng chưa cập nhật bản dự phòng. Hãy thử lại.',
            )
          : (
              'History could not be saved. Try again.',
              'Chưa lưu được lịch sử. Hãy thử lại.',
            );
    } catch (_) {
      error = (
        'History could not be saved. Try again.',
        'Chưa lưu được lịch sử. Hãy thử lại.',
      );
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> record(String text) async {
    if (!enabled || loading) return;
    await _run(() => _commit(history!.add(text)));
  }

  Future<void> setEnabled(bool on) =>
      _run(() => _commit(QrHistory(enabled: on)));
  Future<void> remove(int i) => _run(() => _commit(history!.remove(i)));
  Future<void> retry() =>
      pendingCleanup == null ? load() : _run(() => _commit(pendingCleanup!));
}

/// History list and the switch that turns it on or off.
class QrHistoryPage extends StatelessWidget {
  final QrHistoryController controller;
  const QrHistoryPage({super.key, required this.controller});

  Future<void> toggle(BuildContext context, bool on) async {
    if (!on && controller.history!.entries.isNotEmpty) {
      final ok = await confirmHandy(
        context,
        title: tr(
          context,
          'Turn off and clear history?',
          'Tắt và xóa lịch sử?',
        ),
        message: tr(
          context,
          'Every saved QR code is removed from this device.',
          'Mọi mã QR đã lưu sẽ bị xóa khỏi thiết bị này.',
        ),
        confirmLabel: tr(context, 'Clear history', 'Xóa lịch sử'),
        destructive: true,
      );
      if (!ok) return;
    }
    await controller.setEnabled(on);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final h = controller.history, e = controller.error;
      final c = HandyColors.of(context);
      return HandyPage(
        title: tr(context, 'QR history', 'Lịch sử QR'),
        children: [
          const SizedBox(height: HandySpace.l),
          HandyGroup(
            children: [
              SwitchListTile.adaptive(
                key: const Key('qr-history-toggle'),
                title: Text(
                  tr(
                    context,
                    'Keep history on this device',
                    'Lưu lịch sử trên thiết bị',
                  ),
                ),
                subtitle: Text(
                  tr(
                    context,
                    'Codes can hold Wi-Fi passwords or contact details. Not included in backups.',
                    'Mã có thể chứa mật khẩu Wi-Fi hoặc thông tin liên hệ. Không nằm trong bản sao lưu.',
                  ),
                ),
                value: controller.enabled,
                onChanged: controller.busy || controller.loading || h == null
                    ? null
                    : (on) => toggle(context, on),
              ),
            ],
          ),
          if (e != null) ...[
            const SizedBox(height: HandySpace.m),
            HandyNotice(
              tr(context, e.$1, e.$2),
              tone: HandyTone.error,
              action: TextButton(
                onPressed: controller.busy ? null : controller.retry,
                child: Text(tr(context, 'Retry', 'Thử lại')),
              ),
            ),
          ],
          if (h != null && h.enabled) ...[
            HandyLabel(tr(context, 'Saved codes', 'Mã đã lưu')),
            if (h.entries.isEmpty)
              HandyEmpty(
                title: tr(
                  context,
                  'Codes you save or share will appear here.',
                  'Mã bạn lưu hoặc chia sẻ sẽ hiện ở đây.',
                ),
              )
            else
              HandyGroup(
                children: [
                  for (var i = 0; i < h.entries.length; i++)
                    ListTile(
                      title: Text(
                        h.entries[i]['text']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        h.entries[i]['at']!
                            .replaceFirst('T', ' ')
                            .substring(0, 16),
                        style: TextStyle(fontFeatures: tabular, color: c.muted),
                      ),
                      onTap: () => Navigator.pop(context, h.entries[i]['text']),
                      trailing: IconButton(
                        tooltip: tr(context, 'Delete', 'Xóa'),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: controller.busy
                            ? null
                            : () => controller.remove(i),
                      ),
                    ),
                ],
              ),
          ],
        ],
      );
    },
  );
}
