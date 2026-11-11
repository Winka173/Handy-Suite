import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'drive_sync.dart';

String syncStateText(BuildContext c, DriveSyncState state) => switch (state) {
  DriveSyncState.off => tr(c, 'Sync is off', 'Đồng bộ đang tắt'),
  DriveSyncState.connecting => tr(c, 'Connecting…', 'Đang kết nối…'),
  DriveSyncState.syncing => tr(c, 'Syncing…', 'Đang đồng bộ…'),
  DriveSyncState.synced => tr(c, 'In sync', 'Đã đồng bộ'),
  DriveSyncState.pending => tr(c, 'Changes waiting', 'Có thay đổi đang chờ'),
  DriveSyncState.error => tr(c, 'Could not sync', 'Chưa đồng bộ được'),
  DriveSyncState.newerRemote => tr(
    c,
    'Update Handy Habit',
    'Cập nhật Handy Habit',
  ),
};
String syncErrorText(BuildContext c, String? error) => switch (error) {
  'capacity' => tr(
    c,
    'Sync is unavailable at this history size. Local data is safe; you can keep tracking offline.',
    'Lịch sử này vượt khả năng đồng bộ hiện tại. Dữ liệu cục bộ vẫn an toàn; bạn có thể tiếp tục ghi ngoại tuyến.',
  ),
  'configuration' => tr(
    c,
    'Allow Google Drive access again to reconnect. Your local data is preserved.',
    'Cho phép truy cập Google Drive lần nữa để kết nối lại. Dữ liệu trên máy vẫn được giữ.',
  ),
  'newer' => tr(
    c,
    'Drive has data from a newer Handy Habit. Update this app, then try again. Nothing in Drive was overwritten.',
    'Drive có dữ liệu từ Handy Habit mới hơn. Hãy cập nhật app rồi thử lại. Không ghi đè dữ liệu trên Drive.',
  ),
  'authNeeded' => tr(
    c,
    'Google access expired. Choose Allow access again.',
    'Quyền Google đã hết hạn. Chọn Cho phép truy cập lại.',
  ),
  'quota' => tr(
    c,
    'Google Drive is full. Free some space, then sync again.',
    'Google Drive đã đầy. Dọn dung lượng rồi đồng bộ lại.',
  ),
  'damaged' => tr(
    c,
    'Drive data is incomplete or damaged. Local data is safe. Try again; keep a backup if this continues.',
    'Dữ liệu Drive thiếu hoặc hỏng. Dữ liệu trên máy vẫn an toàn. Thử lại; giữ bản sao lưu nếu lỗi tiếp diễn.',
  ),
  'metadata' => tr(
    c,
    'This device’s sync settings could not be read. Local data is safe. Contact support before changing sync files.',
    'Không đọc được cài đặt đồng bộ trên máy. Dữ liệu vẫn an toàn. Liên hệ hỗ trợ trước khi sửa file đồng bộ.',
  ),
  'disconnect' => tr(
    c,
    'Sync is off, but Google access could not be revoked. Try Disconnect again.',
    'Đã tắt đồng bộ nhưng chưa thu hồi được quyền Google. Thử Ngắt kết nối lần nữa.',
  ),
  _ => tr(
    c,
    'Check your connection and try again. You can keep tracking offline.',
    'Kiểm tra mạng rồi thử lại. Bạn vẫn ghi nhận được khi ngoại tuyến.',
  ),
};

class HabitSyncPage extends StatelessWidget {
  final HabitScope scope;
  const HabitSyncPage({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final d = scope.drive!;
    return ListenableBuilder(
      listenable: Listenable.merge([d, scope.controller]),
      builder: (context, _) {
        final theme = Theme.of(context), colors = HandyColors.of(context);
        String when(DateTime date) =>
            '${MaterialLocalizations.of(context).formatShortDate(date.toLocal())} ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';
        Widget fact(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        );
        final days = dayOperationConflicts(scope.state.operations),
            moods = moodSyncConflicts(scope.state);
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(
              key: const Key('sync-back'),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(tr(context, 'Sync', 'Đồng bộ')),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              key: const Key('sync-scroll'),
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
                16,
                MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
                32,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          syncStateText(context, d.state),
                          key: const Key('sync-status'),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          context,
                          'Keep your Android devices in step. Sync is optional and free.',
                          'Giữ dữ liệu nhất quán trên các máy Android. Đồng bộ tùy chọn và miễn phí.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (d.errorCode != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              syncErrorText(context, d.errorCode),
                              key: const Key('sync-error'),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          key: const Key('sync-primary'),
                          onPressed: d.busy
                              ? null
                              : d.enabled && d.errorCode != 'authNeeded'
                              ? d.syncNow
                              : d.enable,
                          child: Text(
                            d.busy
                                ? tr(context, 'Please wait…', 'Vui lòng chờ…')
                                : !d.enabled
                                ? tr(context, 'Turn on sync', 'Bật đồng bộ')
                                : d.errorCode == 'authNeeded'
                                ? tr(
                                    context,
                                    'Allow access again',
                                    'Cho phép truy cập lại',
                                  )
                                : tr(context, 'Sync now', 'Đồng bộ ngay'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      fact(
                        tr(context, 'Provider', 'Dịch vụ'),
                        'Google Drive · Android',
                      ),
                      fact(
                        tr(context, 'Account', 'Tài khoản'),
                        d.account ??
                            tr(
                              context,
                              d.enabled
                                  ? 'Access allowed in Google'
                                  : 'Not connected',
                              d.enabled
                                  ? 'Đã cho phép trong Google'
                                  : 'Chưa kết nối',
                            ),
                      ),
                      fact(
                        tr(
                          context,
                          'Last successful sync',
                          'Đồng bộ thành công gần nhất',
                        ),
                        d.lastSync == null
                            ? tr(
                                context,
                                'Not synced yet',
                                'Chưa đồng bộ lần nào',
                              )
                            : when(d.lastSync!),
                      ),
                      fact(
                        tr(context, 'Pending changes', 'Thay đổi đang chờ'),
                        d.enabled
                            ? '${d.pending} ${tr(context, d.pending == 1 ? 'change' : 'changes', 'thay đổi')}'
                            : tr(context, 'Sync is off', 'Đồng bộ đang tắt'),
                      ),
                      fact(
                        tr(context, 'Last error', 'Lỗi gần nhất'),
                        d.lastError == null
                            ? tr(context, 'None', 'Không có')
                            : syncErrorText(context, d.lastError),
                      ),
                      if (d.enabled || d.account != null)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (d.enabled)
                              TextButton(
                                key: const Key('sync-off'),
                                onPressed: d.busy ? null : () => d.disable(),
                                child: Text(
                                  tr(context, 'Turn off sync', 'Tắt đồng bộ'),
                                ),
                              ),
                            TextButton(
                              key: const Key('sync-disconnect'),
                              onPressed: d.busy
                                  ? null
                                  : () => d.disable(disconnect: true),
                              child: Text(
                                tr(context, 'Disconnect', 'Ngắt kết nối'),
                              ),
                            ),
                          ],
                        ),
                      if (days.isNotEmpty || moods.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          tr(context, 'Needs review', 'Cần xem lại'),
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          tr(
                            context,
                            'Both devices’ versions are kept. Choose the total or mood to use; other days stay as they are.',
                            'Giữ các phiên bản từ cả hai máy. Chọn tổng hoặc tâm trạng muốn dùng; giữ nguyên các ngày khác.',
                          ),
                        ),
                        for (final e in days.entries) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${scope.habit(e.value.first.after!['habit'] as String)?.title ?? e.value.first.after!['habit']} · ${e.value.first.after!['day']}',
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final o in e.value)
                                OutlinedButton(
                                  key: Key('resolve-day-${o.id}'),
                                  onPressed: () => scope.write(
                                    context,
                                    (s) => setManualTotal(
                                      s,
                                      o.after!['habit'] as String,
                                      o.after!['day'] as String,
                                      o.after!['value'] as int,
                                      skipped: o.after!['skipped'] == true,
                                      today: o.after!['day'] as String,
                                    ),
                                  ),
                                  child: Text(
                                    o.after!['skipped'] == true
                                        ? tr(context, 'Use skip', 'Chọn bỏ qua')
                                        : tr(
                                            context,
                                            'Use ${amount(o.after!['value'] as int)}',
                                            'Chọn ${amount(o.after!['value'] as int)}',
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        for (final e in moods.entries) ...[
                          const SizedBox(height: 16),
                          Text(
                            '${tr(context, 'Mood', 'Tâm trạng')} · ${e.key.substring(5)}',
                          ),
                          for (final o in e.value)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                key: Key('resolve-mood-${o.id}'),
                                onPressed: () => scope.write(
                                  context,
                                  (s) =>
                                      resolveMoodSyncConflict(s, e.key, o.id),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    o.after == null
                                        ? tr(
                                            context,
                                            'Use no entry',
                                            'Chọn không ghi',
                                          )
                                        : '${tr(context, 'Use', 'Chọn')} ${o.after!['mood']}/5${o.after!['deletedAt'] != null ? ' · ${tr(context, 'Deleted', 'Đã xóa')}' : ''}${o.after!['note'] == '' ? '' : ' · ${o.after!['note']}'}',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                      const Divider(),
                      ExpansionTile(
                        key: const Key('sync-activity'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(tr(context, 'Activity', 'Hoạt động')),
                        subtitle: Text(
                          d.activity.isEmpty
                              ? tr(
                                  context,
                                  'No successful syncs yet',
                                  'Chưa có lần đồng bộ thành công',
                                )
                              : tr(
                                  context,
                                  '${d.activity.length} recent successful ${d.activity.length == 1 ? 'sync' : 'syncs'}',
                                  '${d.activity.length} lần đồng bộ thành công gần đây',
                                ),
                        ),
                        children: [
                          for (final stamp in d.activity)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                tr(context, 'Sync completed', 'Đồng bộ xong'),
                              ),
                              subtitle: Text(when(DateTime.parse(stamp))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(
                          context,
                          'Data goes to Handy Habit’s hidden folder in your own Google Drive, using appdata access only. No developer server receives it. It is not end-to-end encrypted. Sync runs while the app is open, on return and after changes; edits and deletions reach your other Android devices. Turning sync off or disconnecting deletes nothing here or in Drive. Older Drive generations may retain deleted content; remove hidden app data in Drive settings to erase all cloud copies. Keep a separate backup. Use backup to move data to iOS, Windows or web.',
                          'Dữ liệu vào thư mục ẩn riêng của Handy Habit trong Google Drive của bạn, chỉ dùng quyền appdata. Không gửi tới máy chủ nhà phát triển. Không mã hóa đầu-cuối. Đồng bộ khi app đang mở, khi quay lại và sau thay đổi; sửa và xóa được chuyển tới máy Android khác. Tắt hay ngắt kết nối không xóa dữ liệu trên máy hoặc Drive. Bản cũ trên Drive có thể giữ nội dung đã xóa; xóa dữ liệu ẩn của app trong cài đặt Drive để xóa hết bản trên cloud. Giữ bản sao lưu riêng. Dùng sao lưu để chuyển sang iOS, Windows hoặc web.',
                        ),
                        key: const Key('sync-privacy'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/help/sync'),
                          child: Text(
                            tr(context, 'Sync vs backup', 'Đồng bộ và sao lưu'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
