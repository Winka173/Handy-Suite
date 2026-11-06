import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../links/link_actions.dart';
import '../scope.dart';
import 'settings_parts.dart';

/// Settings › Help & About › Advanced library tools: how links open, list
/// and search habits, reading page details, and the older management
/// tools (links saved twice, link checks, smart collections, saved
/// searches, the database check). Each keeps its own route or sheet.
Future<void> openLibraryTools(BuildContext context, SaveScope scope) =>
    pushSettingsView(
      context,
      tr(context, 'Advanced library tools', 'Công cụ thư viện nâng cao'),
      listenable: Listenable.merge([scope.c, scope.view]),
      (context) => libraryTools(context, scope),
    );

List<Widget> libraryTools(BuildContext context, SaveScope scope) {
  final c = scope.c;
  final p = c.preferences;
  final l = scope.library;
  Future<void> set(Map<String, Object?> values) => scope.run(
    context,
    () => c.update((l) => l, prefs: {...c.preferences, ...values}),
  );
  final groups = duplicateGroups(l);
  return [
    SettingsPanel(
      gap: false,
      title: tr(context, 'Opening links', 'Mở link'),
      note: tr(
        context,
        'Device lets the phone or computer choose. Its app opens a YouTube link in YouTube when it is installed. Browser always uses the browser.',
        'Mặc định để máy tự chọn. App gốc mở link YouTube bằng YouTube nếu đã cài. Trình duyệt thì luôn mở bằng trình duyệt.',
      ),
      rows: [
        SettingsChoice<String>(
          controlKey: const Key('set-open'),
          icon: Icons.open_in_new,
          title: tr(context, 'Open links with', 'Mở link bằng'),
          value: p['openingMode'] as String? ?? 'system',
          options: [
            ('system', tr(context, 'Device', 'Mặc định')),
            ('app', tr(context, 'Its app', 'App gốc')),
            ('external', tr(context, 'Browser', 'Trình duyệt')),
          ],
          onChanged: (v) => set({'openingMode': v}),
        ),
      ],
    ),
    SettingsPanel(
      title: tr(context, 'Lists and search', 'Danh sách và tìm kiếm'),
      rows: [
        SettingsSwitch(
          key: const Key('set-cards'),
          icon: Icons.view_agenda_outlined,
          title: tr(context, 'Show lists as cards', 'Hiện danh sách dạng thẻ'),
          subtitle: tr(
            context,
            'Bigger pictures, fewer items per screen',
            'Ảnh to hơn, ít mục hơn mỗi màn hình',
          ),
          value: p['cards'] == true,
          onChanged: (v) => set({'cards': v}),
        ),
        SettingsSwitch(
          key: const Key('set-history'),
          icon: Icons.history,
          title: tr(context, 'Remember searches', 'Nhớ các lần tìm'),
          subtitle: tr(
            context,
            'Turning it off forgets them',
            'Tắt đi sẽ xóa các lần tìm đã nhớ',
          ),
          value: p['recentSearchesEnabled'] == true,
          onChanged: (v) => set({
            'recentSearchesEnabled': v,
            if (!v) 'recentSearches': <String>[],
          }),
        ),
      ],
    ),
    SettingsPanel(
      title: tr(context, 'Page details', 'Thông tin trang'),
      note: tr(
        context,
        'Off: only what was shared is kept, and no website is contacted. On: after you save, the app reads the public page for its title and picture.',
        'Tắt: chỉ giữ những gì được chia sẻ, không liên hệ website nào. Bật: sau khi lưu, app đọc trang công khai để lấy tiêu đề và ảnh.',
      ),
      rows: [
        SettingsSwitch(
          key: const Key('set-metadata'),
          icon: Icons.travel_explore,
          title: tr(
            context,
            'Read pages after saving',
            'Đọc trang sau khi lưu',
          ),
          value: p['automaticMetadata'] == true,
          onChanged: (v) => set({'automaticMetadata': v}),
        ),
      ],
    ),
    SettingsPanel(
      title: tr(context, 'Tidy up', 'Dọn dẹp'),
      rows: [
        // Shown only while some link is saved more than once.
        if (groups.isNotEmpty)
          SettingsRow(
            key: const Key('save-duplicates'),
            icon: Icons.merge_type,
            title: tr(
              context,
              groups.length == 1
                  ? '1 link saved twice'
                  : '${groups.length} links saved twice',
              '${groups.length} link lưu trùng',
            ),
            subtitle: tr(
              context,
              'Review and merge each into one.',
              'Xem lại và gộp mỗi link thành một.',
            ),
            navigates: true,
            onTap: () => Navigator.of(context).pushNamed('/duplicates'),
          ),
        SettingsRow(
          key: const Key('save-check-all'),
          icon: Icons.link,
          title: tr(context, 'Check every link', 'Kiểm tra mọi link'),
          subtitle: tr(
            context,
            'Asks each website whether the page is still there',
            'Hỏi từng website xem trang còn không',
          ),
          onTap: () => scope.checkLinks(context, [
            for (final b in scope.library.bookmarks)
              if (b.hasUrl) b.id,
          ]),
        ),
        SettingsRow(
          key: const Key('save-broken'),
          icon: Icons.link_off,
          title: tr(context, 'Broken links', 'Link hỏng'),
          subtitle: tr(
            context,
            'What the last checks found',
            'Kết quả các lần kiểm tra',
          ),
          navigates: true,
          onTap: () => Navigator.of(context).pushNamed('/place/broken'),
        ),
        SettingsRow(
          key: const Key('save-integrity'),
          icon: Icons.fact_check_outlined,
          title: tr(context, 'Check the library', 'Kiểm tra thư viện'),
          subtitle: tr(
            context,
            'Looks for damage in the file that holds it',
            'Tìm lỗi trong tệp lưu thư viện',
          ),
          onTap: () => scope.run(context, () async {
            final status = await c.store!.integrity();
            if (context.mounted) {
              showHandyMessage(
                context,
                status == 'ok'
                    ? tr(context, 'The library is healthy.', 'Thư viện vẫn ổn.')
                    : '${tr(context, 'Problem found', 'Phát hiện lỗi')}: $status',
              );
            }
          }),
        ),
        if (scope.view.canUndo)
          SettingsRow(
            key: const Key('save-undo'),
            icon: Icons.undo,
            title: tr(
              context,
              'Undo the last change',
              'Hoàn tác thay đổi gần nhất',
            ),
            onTap: () => scope.run(context, scope.view.undo),
          ),
      ],
    ),
    SettingsPanel(
      title: tr(context, 'Smart collections', 'Bộ sưu tập thông minh'),
      note: tr(
        context,
        'They fill themselves from rules, like "videos saved this week".',
        'Tự gom link theo điều kiện, ví dụ "video lưu trong tuần này".',
      ),
      rows: [
        for (final s in l.smartCollections)
          SettingsRow(
            key: Key('tools-smart-${s.id}'),
            icon: Icons.auto_awesome_outlined,
            title: s.name,
            navigates: true,
            onTap: () => Navigator.of(context).pushNamed('/smart/${s.id}'),
          ),
        SettingsRow(
          key: const Key('save-smart-new'),
          icon: Icons.add,
          title: tr(
            context,
            'New smart collection',
            'Thêm bộ sưu tập thông minh',
          ),
          onTap: () => scope.editSmart(context),
        ),
      ],
    ),
    if (l.savedSearches.isNotEmpty)
      SettingsPanel(
        title: tr(context, 'Saved searches', 'Tìm kiếm đã lưu'),
        rows: [
          for (final s in l.savedSearches)
            SettingsRow(
              key: Key('tools-search-${s.id}'),
              icon: Icons.manage_search,
              title: s.name,
              navigates: true,
              onTap: () => Navigator.of(context).pushNamed('/search/${s.id}'),
            ),
        ],
      ),
  ];
}
