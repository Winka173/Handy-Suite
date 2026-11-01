import 'package:flutter/material.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// An action that may open pickers/dialogs. Returns a message to show, or null
/// when the user canceled. Throwing shows the error and keeps existing data.
typedef HandySettingsAction = Future<String?> Function(BuildContext context);

/// One settings area: title and description beside its panel on wide
/// screens, stacked above it on phones.
class HandySettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;
  const HandySettingsSection({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        if (description != null) ...[
          const SizedBox(height: HandySpace.xs),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
        ],
      ],
    );
    final panel = HandyGroup(children: children);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HandySpace.xl),
      child: LayoutBuilder(
        builder: (context, size) => size.maxWidth >= 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: label,
                    ),
                  ),
                  const SizedBox(width: HandySpace.xl),
                  Expanded(child: panel),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label,
                  const SizedBox(height: HandySpace.m),
                  panel,
                ],
              ),
      ),
    );
  }
}

/// A control row inside a settings panel: label left, control right, or the
/// control below the label when it needs the width.
class HandySettingRow extends StatelessWidget {
  final String label;
  final Widget control;

  /// Below this width the control goes under its label; raise it for wide
  /// controls such as a three-way switch.
  final double stackBelow;
  const HandySettingRow({
    super.key,
    required this.label,
    required this.control,
    this.stackBelow = 520,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: HandySpace.l,
      vertical: HandySpace.m,
    ),
    child: LayoutBuilder(
      builder: (context, size) => size.maxWidth >= stackBelow
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                control,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: HandySpace.s),
                control,
              ],
            ),
    ),
  );
}

/// Shared settings screen. Every control saves itself; apps add their own
/// sections between Pro and data.
class HandySettingsPage extends StatefulWidget {
  final String appName;
  final String theme, locale;
  final Future<void> Function(String) onTheme, onLocale;
  final List<Widget> sections;
  final HandySettingsAction? onExportSettings, onImportSettings;
  final Future<void> Function()? onClearInputs, onReset;
  final List<Widget> about;
  const HandySettingsPage({
    super.key,
    required this.appName,
    required this.theme,
    required this.locale,
    required this.onTheme,
    required this.onLocale,
    this.sections = const [],
    this.onExportSettings,
    this.onImportSettings,
    this.onClearInputs,
    this.onReset,
    this.about = const [],
  });
  @override
  State<HandySettingsPage> createState() => _HandySettingsPageState();
}

class _HandySettingsPageState extends State<HandySettingsPage> {
  late String theme = widget.theme, locale = widget.locale;
  bool busy = false;
  String message = '';
  HandyTone tone = HandyTone.info;

  Future<void> guard(Future<String?> Function() action, String failure) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final result = await action();
      if (mounted && result != null)
        setState(() {
          message = result;
          tone = HandyTone.success;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          message = e is FormatException ? '$failure ${e.message}' : failure;
          tone = HandyTone.error;
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> cleanup(bool reset) async {
    final ok = await confirmHandy(
      context,
      title: reset
          ? tr(context, 'Reset preferences?', 'Đặt lại cài đặt?')
          : tr(context, 'Clear saved inputs?', 'Xóa nội dung đã lưu?'),
      message: reset
          ? tr(
              context,
              'Language, theme, pins, workflows and saved inputs go back to defaults. Documents, projects, exported files and purchases are kept.',
              'Ngôn ngữ, giao diện, ghim, quy trình và nội dung đã lưu về mặc định. Giữ nguyên tài liệu, project, file đã xuất và quyền mua.',
            )
          : tr(
              context,
              'Only inputs you saved in tools are removed. Everything else is kept.',
              'Chỉ xóa nội dung bạn đã lưu trong công cụ. Mọi thứ khác được giữ nguyên.',
            ),
      confirmLabel: reset
          ? tr(context, 'Reset preferences', 'Đặt lại cài đặt')
          : tr(context, 'Clear inputs', 'Xóa nội dung'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    final done = tr(
      context,
      'Done. Files and libraries were kept.',
      'Xong. Giữ nguyên file và thư viện.',
    );
    await guard(
      () async {
        await (reset ? widget.onReset! : widget.onClearInputs!)();
        if (reset && mounted)
          setState(() {
            theme = 'system';
            locale = 'system';
          });
        return done;
      },
      tr(
        context,
        'Could not save. Existing data was kept.',
        'Chưa lưu được. Dữ liệu cũ được giữ nguyên.',
      ),
    );
  }

  Widget segmented(
    Key key,
    String value,
    List<(String, String)> options,
    Future<void> Function(String) onChanged,
    void Function(String) local,
  ) => SegmentedButton<String>(
    key: key,
    showSelectedIcon: false,
    segments: [
      for (final o in options) ButtonSegment(value: o.$1, label: Text(o.$2)),
    ],
    selected: {value},
    onSelectionChanged: busy
        ? null
        : (s) => guard(() async {
            await onChanged(s.first);
            local(s.first);
            return null;
          }, tr(context, 'Could not save.', 'Chưa lưu được.')),
  );

  @override
  Widget build(BuildContext context) {
    final system = tr(context, 'System', 'Hệ thống');
    final data =
        widget.onExportSettings != null || widget.onImportSettings != null;
    final cleanups = widget.onClearInputs != null || widget.onReset != null;
    return HandyPage(
      title: tr(context, 'Settings', 'Cài đặt'),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (message.isNotEmpty) ...[
          const SizedBox(height: HandySpace.s),
          HandyNotice(message, tone: tone),
        ],
        HandySettingsSection(
          title: tr(context, 'General', 'Chung'),
          description: tr(
            context,
            'Saved on this device as soon as you change it.',
            'Lưu trên thiết bị ngay khi bạn thay đổi.',
          ),
          children: [
            HandySettingRow(
              label: tr(context, 'Appearance', 'Giao diện'),
              control: segmented(
                const Key('settings-theme'),
                theme,
                [
                  ('system', system),
                  ('light', tr(context, 'Light', 'Sáng')),
                  ('dark', tr(context, 'Dark', 'Tối')),
                ],
                widget.onTheme,
                (v) => setState(() => theme = v),
              ),
            ),
            HandySettingRow(
              label: tr(context, 'Language', 'Ngôn ngữ'),
              control: segmented(
                const Key('settings-locale'),
                locale,
                [('system', system), ('en', 'English'), ('vi', 'Tiếng Việt')],
                widget.onLocale,
                (v) => setState(() => locale = v),
              ),
            ),
          ],
        ),
        const Divider(),
        const HandyProSection(),
        for (final s in widget.sections) ...[const Divider(), s],
        if (data) ...[
          const Divider(),
          HandySettingsSection(
            title: tr(context, 'Backup', 'Sao lưu'),
            description: tr(
              context,
              'Data stays on this device and is not encrypted. Back up before uninstalling or clearing browser data.',
              'Dữ liệu chỉ nằm trên thiết bị và không mã hóa. Hãy sao lưu trước khi gỡ app hoặc xóa dữ liệu trình duyệt.',
            ),
            children: [
              if (widget.onExportSettings != null)
                HandyTile(
                  key: const Key('settings-export'),
                  icon: Icons.upload_outlined,
                  title: tr(
                    context,
                    'Export settings to a file',
                    'Xuất cài đặt ra file',
                  ),
                  onTap: busy
                      ? null
                      : () => guard(
                          () => widget.onExportSettings!(context),
                          tr(context, 'Could not export.', 'Chưa xuất được.'),
                        ),
                ),
              if (widget.onImportSettings != null)
                HandyTile(
                  key: const Key('settings-import'),
                  icon: Icons.download_outlined,
                  title: tr(
                    context,
                    'Restore settings from a file',
                    'Khôi phục cài đặt từ file',
                  ),
                  onTap: busy
                      ? null
                      : () => guard(
                          () => widget.onImportSettings!(context),
                          tr(
                            context,
                            'Could not restore. Current settings were kept.',
                            'Chưa khôi phục được. Giữ nguyên cài đặt hiện tại.',
                          ),
                        ),
                ),
            ],
          ),
        ],
        const Divider(),
        HandySettingsSection(
          title: tr(context, 'About', 'Giới thiệu'),
          children: [
            ...widget.about,
            HandyTile(
              icon: Icons.description_outlined,
              title: tr(
                context,
                'Open-source licenses',
                'Giấy phép mã nguồn mở',
              ),
              navigates: true,
              onTap: () => showLicensePage(
                context: context,
                applicationName: widget.appName,
              ),
            ),
          ],
        ),
        if (cleanups) ...[
          const Divider(),
          HandySettingsSection(
            title: tr(context, 'Reset', 'Đặt lại'),
            description: tr(
              context,
              'Files, libraries and purchases are never touched here.',
              'Không bao giờ đụng tới file, thư viện và quyền mua.',
            ),
            children: [
              if (widget.onClearInputs != null)
                HandyTile(
                  key: const Key('settings-clear-inputs'),
                  title: tr(
                    context,
                    'Clear saved inputs',
                    'Xóa nội dung đã lưu',
                  ),
                  destructive: true,
                  onTap: busy ? null : () => cleanup(false),
                ),
              if (widget.onReset != null)
                HandyTile(
                  key: const Key('settings-reset'),
                  title: tr(context, 'Reset preferences', 'Đặt lại cài đặt'),
                  destructive: true,
                  onTap: busy ? null : () => cleanup(true),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Pro Lifetime as a settings area: one call to action, restore below it.
class HandyProSection extends StatelessWidget {
  const HandyProSection({super.key});
  @override
  Widget build(BuildContext context) {
    final model = LifetimeScope.maybeOf(context);
    if (model == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final status = switch (model.snapshot?.status) {
      _ when model.pending => tr(
        context,
        'Purchase pending. Pro unlocks after the store confirms.',
        'Giao dịch đang chờ. Pro mở sau khi cửa hàng xác nhận.',
      ),
      'canceled' => tr(context, 'Purchase canceled.', 'Đã hủy mua.'),
      'error' || 'unavailable' => tr(
        context,
        'Store unavailable. Try again or restore purchases.',
        'Cửa hàng chưa sẵn sàng. Thử lại hoặc khôi phục giao dịch.',
      ),
      _ => null,
    };
    return HandySettingsSection(
      title: 'Pro Lifetime',
      description: tr(
        context,
        'Pay once to remove ads in this app. Every core tool stays free. Purchases belong to this store account.',
        'Trả một lần để bỏ quảng cáo trong app này. Mọi công cụ chính vẫn miễn phí. Quyền mua thuộc tài khoản cửa hàng này.',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(HandySpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.pro
                    ? tr(
                        context,
                        'Active. No ads.',
                        'Đang dùng. Không quảng cáo.',
                      )
                    : model.configured
                    ? tr(context, 'Free with ads', 'Miễn phí, có quảng cáo')
                    : tr(
                        context,
                        'Not on sale in this build.',
                        'Bản này chưa mở bán.',
                      ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: model.pro ? null : c.muted,
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: HandySpace.m),
                HandyNotice(status),
              ],
              if (model.configured && !model.pro) ...[
                const SizedBox(height: HandySpace.l),
                FilledButton(
                  key: const Key('pro-buy'),
                  onPressed: model.busy || model.pending
                      ? null
                      : () => model.action('buy'),
                  child: Text(
                    tr(context, 'Get Pro Lifetime', 'Mua Pro Lifetime'),
                  ),
                ),
              ],
              if (model.busy) ...[
                const SizedBox(height: HandySpace.m),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        if (model.configured)
          HandyTile(
            icon: Icons.restore,
            title: tr(context, 'Restore purchases', 'Khôi phục giao dịch'),
            onTap: model.busy ? null : () => model.action('restore'),
          ),
        if (model.config.adsEnabled)
          HandyTile(
            icon: Icons.privacy_tip_outlined,
            title: tr(
              context,
              'Ad privacy choices',
              'Quyền riêng tư quảng cáo',
            ),
            onTap: () => showAdPrivacyChoices(model),
          ),
      ],
    );
  }
}
