import 'package:handy_tools_engine/handy_tools_engine.dart';
import 'package:handy_ui/kit.dart';

/// A password is ready the moment the panel opens; every option change makes
/// a new one. Nothing here is stored.
class PasswordPage extends StatefulWidget {
  /// Builds the bench header around this panel's own actions.
  final Widget Function(BuildContext, List<Widget>)? header;
  const PasswordPage({super.key, this.header});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  double length = 20;
  bool upper = true, lower = true, digits = true, symbols = true;
  bool avoidLookalikes = false;
  String password = '', error = '';

  @override
  void initState() {
    super.initState();
    generate();
  }

  void generate() {
    try {
      password = generatePassword(
        PasswordOptions(
          length: length.round(),
          upper: upper,
          lower: lower,
          digits: digits,
          symbols: symbols,
          excludeAmbiguous: avoidLookalikes,
        ),
      );
      error = '';
    } catch (_) {
      password = '';
      error = 'none';
    }
  }

  void update(void Function() change) => setState(() {
    change();
    generate();
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget set(String label, bool value, void Function(bool) onChanged) =>
        FilterChip(
          label: Text(label),
          selected: value,
          avatar: value ? const Icon(Icons.check, size: 16) : null,
          onSelected: (v) => update(() => onChanged(v)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          widget.header!(context, [
            IconButton(
              key: const Key('password-clear'),
              tooltip: tr(context, 'Hide from screen', 'Ẩn khỏi màn hình'),
              icon: const Icon(Icons.visibility_off_outlined),
              onPressed: password.isEmpty
                  ? null
                  : () => setState(() => password = ''),
            ),
          ]),
        Card(
          color: c.lead,
          child: Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error.isNotEmpty)
                  Text(
                    tr(
                      context,
                      'Choose at least one kind of character.',
                      'Chọn ít nhất một loại ký tự.',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: c.negative,
                    ),
                  )
                else
                  SelectionArea(
                    child: Text(
                      password.isEmpty ? '••••••••' : password,
                      key: const Key('password-value'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'GeistMono',
                        package: 'handy_ui',
                        fontWeight: FontWeight.w400,
                        fontSize: 22,
                        color: password.isEmpty ? c.muted : c.accent,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: HandySpace.l),
                Wrap(
                  spacing: HandySpace.s,
                  runSpacing: HandySpace.s,
                  children: [
                    FilledButton.icon(
                      key: const Key('password-copy'),
                      onPressed: password.isEmpty
                          ? null
                          : () => copyToClipboard(context, password),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(tr(context, 'Copy', 'Sao chép')),
                    ),
                    OutlinedButton.icon(
                      key: const Key('password-new'),
                      onPressed: () => update(() {}),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(tr(context, 'Another one', 'Tạo cái khác')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        HandyLabel(
          tr(context, 'Length', 'Độ dài'),
          trailing: Text(
            '${length.round()}',
            style: theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular),
          ),
        ),
        Slider.adaptive(
          value: length,
          min: 8,
          max: 128,
          divisions: 120,
          label: '${length.round()}',
          onChanged: (v) => update(() => length = v),
        ),
        HandyLabel(tr(context, 'Characters', 'Ký tự')),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            set('A–Z', upper, (v) => upper = v),
            set('a–z', lower, (v) => lower = v),
            set('0–9', digits, (v) => digits = v),
            set('!@#', symbols, (v) => symbols = v),
          ],
        ),
        const SizedBox(height: HandySpace.l),
        HandyGroup(
          children: [
            SwitchListTile.adaptive(
              title: Text(
                tr(context, 'Avoid look-alikes', 'Tránh ký tự dễ nhầm'),
              ),
              subtitle: Text(tr(context, 'No 0/O, 1/l/I', 'Bỏ 0/O, 1/l/I')),
              value: avoidLookalikes,
              onChanged: (v) => update(() => avoidLookalikes = v),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.s),
        Text(
          tr(
            context,
            'Made on this device with a secure random source. Not saved.',
            'Tạo trên thiết bị bằng nguồn ngẫu nhiên an toàn. Không được lưu.',
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
