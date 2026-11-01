import 'package:handy_ui/kit.dart';

/// A day chosen from the calendar, never typed. Empty means not set.
class DateRow extends StatelessWidget {
  final String id, label, value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const DateRow({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return ListTile(
      key: Key('date-$id'),
      enabled: enabled,
      title: Text(label),
      subtitle: Text(
        value.isEmpty
            ? tr(context, 'Not set', 'Chưa đặt')
            : formatDay(context, value),
        style: value.isEmpty ? TextStyle(color: c.muted) : null,
      ),
      trailing: value.isEmpty
          ? Icon(Icons.calendar_today_outlined, size: 20, color: c.muted)
          : IconButton(
              key: Key('date-clear-$id'),
              tooltip: tr(context, 'Clear $label', 'Xóa $label'),
              icon: const Icon(Icons.close),
              onPressed: enabled ? () => onChanged('') : null,
            ),
      onTap: () async {
        final picked = await pickHandyDate(context, value);
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Where the thing is kept, with the places already in use one tap away.
class LocationField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> known;
  final bool enabled;
  final VoidCallback onChanged;
  const LocationField({
    super.key,
    required this.controller,
    required this.known,
    required this.onChanged,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      final typed = foldAccents(value.text.trim().toLowerCase());
      final options = known
          .where(
            (l) =>
                l != value.text.trim() &&
                foldAccents(l.toLowerCase()).contains(typed),
          )
          .take(6)
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('item-location'),
            controller: controller,
            enabled: enabled,
            maxLength: 500,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: tr(
                context,
                'Kitchen cupboard, attic…',
                'Tủ bếp, gác xép…',
              ),
              counterText: '',
            ),
          ),
          // Suggestions grow in as you type instead of jumping the form.
          HandyReveal(
            child: options.isEmpty
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: HandySpace.s),
                      Wrap(
                        spacing: HandySpace.s,
                        runSpacing: HandySpace.s,
                        children: [
                          for (final o in options)
                            ActionChip(
                              key: Key('place-$o'),
                              label: Text(o),
                              onPressed: enabled
                                  ? () {
                                      controller.text = o;
                                      onChanged();
                                    }
                                  : null,
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      );
    },
  );
}
