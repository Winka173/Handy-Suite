import 'dart:convert';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../pro/entitlements.dart';
import 'studio_style.dart';
import 'studio_preview.dart';
import 'theme.dart';

class HabitStudioPage extends StatefulWidget {
  final HabitScope scope;
  const HabitStudioPage({super.key, required this.scope});
  @override
  State<HabitStudioPage> createState() => _HabitStudioPageState();
}

class _HabitStudioPageState extends State<HabitStudioPage> {
  late Map<String, dynamic> draft = StudioStyle.read(
    widget.scope.state.settings,
    pro: true,
  ).toJson();
  late final String original;
  @override
  void initState() {
    super.initState();
    original = jsonEncode(widget.scope.state.settings['studio']);
  }

  String? habit;
  String? error;
  bool saving = false;
  Future<void> apply() async {
    final scope = widget.scope;
    if (!scope.pro(context)) {
      await openHabitPro(context, HabitProFeature.studio);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    String? failure;
    final ok = await scope.write(context, (s) {
      if (!scope.pro(context))
        throw StateError(
          tr(
            context,
            'Pro is required to apply this look.',
            'Cần Pro để áp dụng diện mạo này.',
          ),
        );
      if (jsonEncode(s.settings['studio']) != original) {
        failure = tr(
          context,
          'Your saved look changed. Reopen the studio.',
          'Diện mạo đã lưu đã đổi. Mở lại xưởng giao diện.',
        );
        throw StateError(failure!);
      }
      return s.copy({
        'settings': {...s.settings, 'studio': styleDraft()},
      });
    }, done: (c) => tr(c, 'Look applied.', 'Đã áp dụng diện mạo.'));
    if (mounted) {
      setState(() {
        saving = false;
        if (!ok)
          error =
              failure ??
              tr(
                context,
                'Could not apply. Check storage and try again.',
                'Chưa áp dụng được. Kiểm tra bộ nhớ rồi thử lại.',
              );
      });
      if (ok) Navigator.pop(context);
    }
  }

  Map<String, dynamic> styleDraft() =>
      StudioStyle.read({'studio': draft}, pro: true).toJson();
  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final pro = widget.scope.pro(context);
    final style = StudioStyle.read({'studio': draft}, pro: true);
    Widget choices(
      String id,
      String title,
      List<(String, String, String)> options,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final (key, en, vi) in options)
              ChoiceChip(
                key: Key('studio-$id-$key'),
                label: Text(t(en, vi)),
                selected: draft[id] == key,
                onSelected: saving
                    ? null
                    : (_) => setState(() => draft = {...draft, id: key}),
              ),
          ],
        ),
      ],
    );
    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Text(error!, key: const Key('studio-error')),
          ),
        choices('palette', t('Habit palettes', 'Bảng màu Habit'), [
          ('vermilion', 'Vermilion', 'Đỏ son'),
          ('grove', 'Grove', 'Tán lá'),
          ('ochre', 'Ochre', 'Vàng đất'),
        ]),
        choices('layout', t('Today layout', 'Bố cục Hôm nay'), [
          ('rows', 'Open rows', 'Hàng mở'),
          ('cards', 'Framed cards', 'Thẻ có khung'),
        ]),
        choices('spacing', t('Card spacing', 'Khoảng cách thẻ'), [
          ('normal', 'Everyday', 'Hằng ngày'),
          ('airy', 'Room to breathe', 'Thoáng hơn'),
        ]),
        choices('runner', t('Routine runner', 'Màn chạy quy trình'), [
          ('beads', 'Progress track', 'Dải tiến độ'),
          ('quiet', 'Quiet timer', 'Đồng hồ tĩnh'),
        ]),
        const SizedBox(height: 16),
        Text(
          t('Extra habit icons', 'Biểu tượng bổ sung'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.scope.state.liveHabits.isEmpty)
          Text(
            t(
              'Create a habit to assign an extra icon.',
              'Tạo thói quen để chọn biểu tượng bổ sung.',
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final h in widget.scope.state.liveHabits)
              ChoiceChip(
                label: Text(h.title),
                selected:
                    (habit ?? widget.scope.state.liveHabits.firstOrNull?.id) ==
                    h.id,
                onSelected: (_) => setState(() => habit = h.id),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in studioExtraIcons.entries)
              IconButton.outlined(
                key: Key('studio-icon-${e.key}'),
                tooltip: t(
                  studioIconLabels[e.key]!.$1,
                  studioIconLabels[e.key]!.$2,
                ),
                isSelected:
                    style.icons[habit ??
                        widget.scope.state.liveHabits.firstOrNull?.id] ==
                    e.key,
                icon: Icon(e.value),
                onPressed: saving || widget.scope.state.liveHabits.isEmpty
                    ? null
                    : () => setState(
                        () => draft = {
                          ...draft,
                          'icons': <String, String>{
                            ...style.icons,
                            (habit ?? widget.scope.state.liveHabits.first.id):
                                e.key,
                          },
                        },
                      ),
              ),
          ],
        ),
        TextButton(
          onPressed: () =>
              setState(() => draft = {...draft, 'icons': <String, String>{}}),
          child: Text(t('Use original habit icons', 'Dùng biểu tượng gốc')),
        ),
        const SizedBox(height: 16),
        Text(
          t(
            'Home-screen widgets follow system light/dark and your studio palette with Pro. Choose a habit or routine in Settings › Widgets.',
            'Tiện ích màn hình chính theo sáng/tối hệ thống và bảng màu xưởng khi có Pro. Chọn thói quen hoặc quy trình trong Cài đặt › Tiện ích.',
          ),
        ),
      ],
    );
    final preview = Theme(
      data: habitTheme(Theme.of(context), style: style),
      child: StudioPreview(
        style: style,
        habit: widget.scope.habit(
          habit ?? widget.scope.state.liveHabits.firstOrNull?.id,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Personalization studio', 'Xưởng giao diện')),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            children: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: Text(t('Cancel', 'Hủy')),
              ),
              FilledButton(
                key: const Key('studio-apply'),
                onPressed: saving ? null : apply,
                child: Text(
                  pro
                      ? t('Apply look', 'Áp dụng diện mạo')
                      : t('Get Pro to apply', 'Mở Pro để áp dụng'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HandyContent(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Make room for your day.', 'Dành chỗ cho ngày của bạn.'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                t(
                  'Preview freely. Your habits and their history keep their identity.',
                  'Xem trước tự do. Thói quen và lịch sử giữ nguyên bản sắc.',
                ),
              ),
              if (!pro)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: HabitProBadge(feature: HabitProFeature.studio),
                ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (c, box) => box.maxWidth >= 800
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: preview),
                          const SizedBox(width: 24),
                          Expanded(child: controls),
                        ],
                      )
                    : Column(children: [preview, controls]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
