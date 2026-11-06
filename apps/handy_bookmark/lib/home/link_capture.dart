import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../bookmark/add_link.dart';

class LinkCapture extends StatefulWidget {
  final SaveScope scope;
  const LinkCapture({super.key, required this.scope});
  @override
  State<LinkCapture> createState() => _LinkCaptureState();
}

class _LinkCaptureState extends State<LinkCapture> {
  final text = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || text.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final show = await saveCapturedLinks(
        context,
        widget.scope,
        text.text,
        onSaved: () {
          if (mounted) text.clear();
        },
      );
      if (show != null && mounted)
        await Navigator.pushNamed(context, '/bookmark/${show.id}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, 'Keep a link for later', 'Giữ một link để xem sau'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('bookmark-inline-url'),
          controller: text,
          enabled: !busy,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 4096,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => save(),
          decoration: InputDecoration(
            labelText: tr(context, 'Link to save', 'Link cần lưu'),
            hintText: 'https://',
            counterText: '',
            suffixIcon: IconButton(
              key: const Key('bookmark-inline-save'),
              tooltip: tr(context, 'Save link', 'Lưu link'),
              onPressed: busy || text.text.trim().isEmpty ? null : save,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            context,
            'Saved on this device, even offline.',
            'Lưu trên thiết bị, kể cả khi ngoại tuyến.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
