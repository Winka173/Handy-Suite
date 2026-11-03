import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'frame_page.dart';
import 'stitch_page.dart';

/// Screenshots, one entry: one picture is framed for sharing, several are
/// joined into one long picture. What happens follows from what is picked,
/// so there is no mode to choose first.
/// Picks screenshots and opens what fits them: one is framed, several are
/// joined. Nothing opens when the picker is closed. [replace] swaps the
/// current page (the web entry page) instead of stacking on it.
Future<void> openScreenshots(
  BuildContext context,
  HandyFiles files, {
  bool replace = false,
}) async {
  final picked = files is BatchHandyFiles
      ? await (files as BatchHandyFiles).importManyBytes(
          extensions: const ['png', 'jpg', 'jpeg', 'webp'],
          maxFiles: 20,
        )
      : [
          ?await files.importBytes(
            extensions: const ['png', 'jpg', 'jpeg', 'webp'],
            maxBytes: 20000000,
          ),
        ];
  if (picked.isEmpty || !context.mounted) return;
  final route = MaterialPageRoute<void>(
    builder: (_) => picked.length == 1
        ? FramePage(files: files, initial: picked.single.bytes)
        : StitchPage(files: files, initial: picked.take(20).toList()),
  );
  await (replace
      ? Navigator.pushReplacement(context, route)
      : Navigator.push(context, route));
}

class ScreenshotsPage extends StatefulWidget {
  final HandyFiles files;
  const ScreenshotsPage({super.key, required this.files});
  @override
  State<ScreenshotsPage> createState() => _ScreenshotsPageState();
}

class _ScreenshotsPageState extends State<ScreenshotsPage> {
  String? error;

  Future<void> pick() async {
    try {
      await openScreenshots(context, widget.files, replace: true);
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) => HandyPage(
    title: tr(context, 'Screenshots', 'Ảnh chụp màn hình'),
    children: [
      HandyEmpty(
        title: tr(
          context,
          'Frame one, or join several',
          'Một ảnh để đóng khung, nhiều ảnh để nối',
        ),
        message: tr(
          context,
          'Pick one screenshot to put it on a ground with rounded corners and a shadow. Pick several of one long page, top to bottom, to join them.',
          'Chọn một ảnh để đặt lên nền, bo góc, đổ bóng. Chọn nhiều ảnh của một trang dài, theo thứ tự từ trên xuống, để nối thành một.',
        ),
        action: FilledButton(
          key: const Key('screenshots-pick'),
          onPressed: pick,
          child: Text(tr(context, 'Choose screenshots', 'Chọn ảnh chụp')),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.m),
          child: HandyNotice(error!, tone: HandyTone.error),
        ),
    ],
  );
}
