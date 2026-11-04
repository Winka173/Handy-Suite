import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'environment_dialog.dart';
import 'history_section.dart';
import 'name_dialog.dart';
import 'workspace.dart';

/// Collections and their requests, the environment in use, and the way to
/// start a new request. A pane beside the editor on wide screens.
class RequestList extends StatelessWidget {
  final Workspace ws;
  final HandyFiles files;
  final VoidCallback onNew;
  const RequestList({
    super.key,
    required this.ws,
    required this.files,
    required this.onNew,
  });

  Future<void> guard(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        showHandyMessage(
          context,
          e is FormatException
              ? e.message
              : tr(
                  context,
                  'Could not save. Nothing changed.',
                  'Chưa lưu được. Không có gì thay đổi.',
                ),
        );
      }
    }
  }

  Future<void> collectionMenu(BuildContext context, ApiCollection c) async {
    final others = ws.value.collections.where((x) => x.id != c.id).toList();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HandyTile(
              icon: Icons.edit_outlined,
              title: tr(context, 'Rename', 'Đổi tên'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            if (others.isNotEmpty)
              HandyTile(
                icon: Icons.delete_outline,
                title: c.requestIds.isEmpty
                    ? tr(context, 'Delete collection', 'Xóa collection')
                    : tr(
                        context,
                        'Delete, moving requests to ${others.first.name}',
                        'Xóa, chuyển request sang ${others.first.name}',
                      ),
                destructive: true,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'rename') {
      await askName(
        context,
        title: tr(context, 'Rename collection', 'Đổi tên collection'),
        initial: c.name,
        commit: (n) => ws.commit(renameCollection(ws.value, c.id, n)),
      );
    } else if (action == 'delete') {
      final ok = await confirmHandy(
        context,
        title: tr(context, 'Delete "${c.name}"?', 'Xóa "${c.name}"?'),
        confirmLabel: tr(context, 'Delete', 'Xóa'),
        destructive: true,
      );
      if (ok && context.mounted) {
        await guard(
          context,
          () => ws.commit(
            removeCollection(
              ws.value,
              c.id,
              moveTo: c.requestIds.isEmpty ? null : others.first.id,
            ),
          ),
        );
      }
    }
  }

  Future<void> importWorkspace(BuildContext context) =>
      guard(context, () async {
        final file = await files.importText(maxBytes: 2000000);
        if (file == null || !context.mounted) return;
        final next = parseWorkspace(file.text);
        final ok = await confirmHandy(
          context,
          title: tr(
            context,
            'Replace your requests?',
            'Thay các request hiện có?',
          ),
          message: tr(
            context,
            'Collections, requests and environment names come from the file.',
            'Collection, request và tên environment lấy từ file.',
          ),
          confirmLabel: tr(context, 'Replace', 'Thay'),
        );
        if (ok) await ws.commit(next);
      });

  Future<void> exportWorkspaceFile(BuildContext context) => guard(
    context,
    () async {
      final uri = await files.exportBytes(
        'handy-dev-requests.json',
        Uint8List.fromList(utf8.encode(exportWorkspace(ws.value))),
        mimeType: 'application/json',
      );
      if (uri != null && context.mounted)
        showHandyMessage(
          context,
          tr(context, 'Exported without secrets', 'Đã xuất, không kèm bí mật'),
        );
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final v = ws.value;
    final method = theme.textTheme.labelMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
      color: theme.colorScheme.onSurface,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        HandySpace.l,
        HandySpace.l,
        HandySpace.l,
        HandySpace.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('request-new'),
                onPressed: onNew,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr(context, 'New request', 'Request mới')),
              ),
            ),
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.create_new_folder_outlined,
                  tr(context, 'New collection', 'Collection mới'),
                  () => askName(
                    context,
                    title: tr(context, 'New collection', 'Collection mới'),
                    commit: (n) => ws.commit(
                      createCollection(ws.value, Workspace.newId('c'), n),
                    ),
                  ),
                  key: const Key('api-create-collection'),
                ),
                HandyMenuItem(
                  Icons.download_outlined,
                  tr(context, 'Import requests', 'Nhập request'),
                  () => importWorkspace(context),
                ),
                HandyMenuItem(
                  Icons.upload_outlined,
                  tr(
                    context,
                    'Export without secrets',
                    'Xuất, không kèm bí mật',
                  ),
                  () => exportWorkspaceFile(context),
                ),
              ],
            ),
          ],
        ),
        HandyLabel(tr(context, 'Environment', 'Environment')),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: Key('env-select-${ws.environment}'),
                initialValue: ws.environment,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(tr(context, 'None', 'Không dùng')),
                  ),
                  for (final e in v.environments)
                    DropdownMenuItem(value: e.id, child: Text(e.name)),
                ],
                onChanged: ws.useEnvironment,
              ),
            ),
            IconButton(
              key: const Key('env-edit'),
              tooltip: tr(context, 'Edit environments', 'Sửa environment'),
              icon: const Icon(Icons.tune),
              onPressed: () => editEnvironment(context, ws),
            ),
          ],
        ),
        for (final col in v.collections) ...[
          HandyLabel(
            col.name == 'General' ? tr(context, 'General', 'Chung') : col.name,
            trailing: IconButton(
              tooltip: tr(context, 'Collection actions', 'Thao tác collection'),
              icon: const Icon(Icons.more_horiz, size: 20),
              onPressed: () => collectionMenu(context, col),
            ),
          ),
          if (col.requestIds.isEmpty)
            HandyEmpty(
              title: tr(context, 'No requests yet.', 'Chưa có request.'),
            )
          else
            HandyGroup(
              children: [
                for (final id in col.requestIds)
                  for (final r in v.requests.where((r) => r.id == id))
                    Material(
                      color: r.id == ws.selected
                          ? c.select
                          : Colors.transparent,
                      child: ListTile(
                        key: Key('request-${r.id}'),
                        leading: SizedBox(
                          width: 60,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: MethodTag(r.method, style: method),
                          ),
                        ),
                        title: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          r.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => ws.select(r.id),
                      ),
                    ),
              ],
            ),
        ],
        SendHistorySection(ws: ws),
      ],
    );
  }
}

/// The request's method on a pale tint of its own colour: GET leaf, POST
/// blue, PUT amber, PATCH sky, DELETE tomato. The word carries the
/// meaning; the colour lets the eye find it. Indices are into Dev's
/// palette, which leaves out teal (too near Dev's green).
class MethodTag extends StatelessWidget {
  final String name;
  final TextStyle? style;
  const MethodTag(this.name, {this.style});

  static int hue(String m) => switch (m.toUpperCase()) {
    'GET' => 2,
    'POST' => 0,
    'PUT' => 1,
    'PATCH' => 5,
    'DELETE' => 4,
    _ => 6,
  };

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: HandyPalette.of(context, hue(name)).tint,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(name, style: style),
    ),
  );
}
