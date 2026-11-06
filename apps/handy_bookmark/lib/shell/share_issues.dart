import 'package:handy_ui/kit.dart';
import '../controller.dart';

/// Links and pictures shared to Save that could not be saved. Each can be dismissed; the
/// system's share queue keeps them until then.
class ShareIssues extends StatelessWidget {
  final SaveController controller;
  const ShareIssues({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final bad = controller.invalidShares;
    return HandyReveal(
      child: bad.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: HandyNotice(
                tr(
                  context,
                  '${bad.length} shared items could not be saved.',
                  '${bad.length} mục được chia sẻ không lưu được.',
                ),
                tone: HandyTone.warning,
                action: TextButton(
                  key: const Key('share-discard'),
                  onPressed: () async {
                    final ok = await confirmHandy(
                      context,
                      title: tr(context, 'Dismiss them?', 'Bỏ các mục này?'),
                      message: [
                        for (final s in bad.take(3))
                          s.text.trim().isNotEmpty
                              ? s.text
                              : [for (final i in s.images) i.name].join(', '),
                      ].join('\n'),
                      confirmLabel: tr(context, 'Dismiss', 'Bỏ'),
                    );
                    if (ok) {
                      for (final s in [...bad]) {
                        await controller.discardShare(s);
                      }
                    }
                  },
                  child: Text(tr(context, 'Dismiss', 'Bỏ')),
                ),
              ),
            ),
    );
  }
}
