import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../view/library_view.dart';

/// The words for where the person is looking.
String placeTitle(BuildContext c, SaveLibrary l, Place p, String? id) =>
    switch (p) {
      Place.inbox => tr(c, 'Not sorted', 'Chưa xếp'),
      Place.all => tr(c, 'All links', 'Tất cả link'),
      Place.favorites => tr(c, 'Favourites', 'Yêu thích'),
      Place.unread => tr(c, 'Not read yet', 'Chưa đọc'),
      Place.archive => tr(c, 'Archive', 'Lưu trữ'),
      Place.collection =>
        l.collections.where((x) => x.id == id).firstOrNull?.name ?? '',
      Place.smart =>
        l.smartCollections.where((x) => x.id == id).firstOrNull?.name ?? '',
      Place.tag => '#$id',
    };

IconData placeIcon(Place p) => switch (p) {
  Place.inbox => Icons.inbox_outlined,
  Place.all => Icons.bookmarks_outlined,
  Place.favorites => Icons.star_outline,
  Place.unread => Icons.mark_email_unread_outlined,
  Place.archive => Icons.archive_outlined,
  Place.collection => Icons.folder_outlined,
  Place.smart => Icons.auto_awesome_outlined,
  Place.tag => Icons.tag,
};
