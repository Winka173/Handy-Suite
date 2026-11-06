import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../ui/words.dart';

/// The library's own name when the person gave it one, else the app's.
String libraryName(SaveController c) {
  final name = (c.preferences['libraryName'] as String? ?? '').trim();
  return name.isEmpty ? 'Handy Bookmark' : name;
}

/// The home's first line, like a front page's dateline: today's date and
/// the day's one finding (how much waits to be sorted, and how fresh).
class HomeDateline extends StatelessWidget {
  final SaveController controller;
  const HomeDateline({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final l = controller.library!;
    final waiting = [
      for (final b in l.bookmarks)
        if (b.collectionId == null && !b.isArchived) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final date = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());
    final finding = l.bookmarks.isEmpty
        ? tr(context, 'Nothing saved yet', 'Chưa lưu gì')
        : waiting.isEmpty
        ? tr(context, 'Everything has a place', 'Mọi thứ đã có chỗ')
        : tr(
            context,
            '${waiting.length} not sorted · newest ${ago(context, waiting.first.savedAt)}',
            '${waiting.length} chưa xếp · mới nhất ${ago(context, waiting.first.savedAt)}',
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.m),
      child: Text(
        '$date · $finding',
        key: const Key('home-dateline'),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: HandyColors.of(context).muted),
      ),
    );
  }
}
