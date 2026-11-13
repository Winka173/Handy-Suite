import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../bookmark/remind_sheet.dart';
import '../design/theme.dart';

/// The moment a save is waiting to be read, when that is still ahead.
DateTime? readLaterAt(Bookmark b, DateTime now) {
  final at = b.reminderAt == null
      ? null
      : DateTime.tryParse(b.reminderAt!)?.toLocal();
  return at != null && at.isAfter(now) ? at : null;
}

/// A ribbon bookmark hanging from the top of a picture: this save is put
/// aside to read later. It names the moment for screen readers and on a
/// long press.
class ReadLaterRibbon extends StatelessWidget {
  final DateTime at;

  /// The 12 × 22 ribbon of a row's picture, else 16 × 30.
  final bool small;
  const ReadLaterRibbon(this.at, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final when = RemindChoices.when(context, at, DateTime.now());
    final label = tr(context, 'Read later: $when', 'Đọc sau: $when');
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: CustomPaint(
          size: small ? const Size(12, 22) : const Size(16, 30),
          // The palette's gold: the same as the Save action.
          painter: _Ribbon(BookmarkPalette.of(context).gold),
        ),
      ),
    );
  }
}

class _Ribbon extends CustomPainter {
  final Color color;
  const _Ribbon(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final notch = s.width * .45;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width / 2, s.height - notch)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Ribbon old) => old.color != color;
}
