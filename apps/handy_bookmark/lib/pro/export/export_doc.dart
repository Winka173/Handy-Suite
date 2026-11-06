import 'dart:typed_data';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../../controller.dart';

/// One save as an export shows it. Pictures are the stored previews
/// (generated, without camera data), never the originals.
class ExportItem {
  final String title, source, date;
  final String? url, note, description;
  final List<String> tags;
  final Uint8List? image;
  const ExportItem({
    required this.title,
    required this.source,
    required this.date,
    this.url,
    this.note,
    this.description,
    this.tags = const [],
    this.image,
  });
}

/// What the person chose to include; notes stay out unless asked for.
class ExportOptions {
  final String title, subtitle;
  final bool notes, descriptions, sources, dates, images;
  final bool letter;
  const ExportOptions({
    required this.title,
    this.subtitle = '',
    this.notes = false,
    this.descriptions = true,
    this.sources = true,
    this.dates = true,
    this.images = true,
    this.letter = false,
  });
  ExportOptions copyWith({
    String? title,
    String? subtitle,
    bool? notes,
    bool? descriptions,
    bool? sources,
    bool? dates,
    bool? images,
    bool? letter,
  }) => ExportOptions(
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    notes: notes ?? this.notes,
    descriptions: descriptions ?? this.descriptions,
    sources: sources ?? this.sources,
    dates: dates ?? this.dates,
    images: images ?? this.images,
    letter: letter ?? this.letter,
  );
}

/// A designed export: its look (shared by the web page and the PDF) and
/// what it can do. Both formats exist for every template.
class ExportTemplate {
  final String id, en, vi, tagEn, tagVi;
  final int ink, paper, accent, muted;
  final bool serifTitles, usesImages;

  /// Whether this design has room for the person's notes.
  final bool showsNotes;
  const ExportTemplate({
    required this.id,
    required this.en,
    required this.vi,
    required this.tagEn,
    required this.tagVi,
    required this.ink,
    required this.paper,
    required this.accent,
    required this.muted,
    this.serifTitles = true,
    this.usesImages = true,
    this.showsNotes = true,
  });
}

const exportTemplates = <ExportTemplate>[
  ExportTemplate(
    id: 'catalog',
    en: 'Collection catalog',
    vi: 'Danh mục bộ sưu tập',
    tagEn: 'A clean grid of cards with pictures and sources',
    tagVi: 'Lưới thẻ gọn với ảnh và nguồn',
    ink: 0xFF1C2627,
    paper: 0xFFFFFFFF,
    accent: 0xFF0E7490,
    muted: 0xFF5B6767,
    serifTitles: false,
  ),
  ExportTemplate(
    id: 'travel',
    en: 'Travel journal',
    vi: 'Nhật ký chuyến đi',
    tagEn: 'A cover picture, then each place large with your notes',
    tagVi: 'Ảnh bìa, rồi từng nơi ảnh lớn kèm ghi chú',
    ink: 0xFF1F2A24,
    paper: 0xFFFBF8F1,
    accent: 0xFF2F5D46,
    muted: 0xFF5A6458,
  ),
  ExportTemplate(
    id: 'recipes',
    en: 'Recipe book',
    vi: 'Sổ công thức',
    tagEn: 'One dish at a time: picture, name, your notes, the source',
    tagVi: 'Mỗi lần một món: ảnh, tên, ghi chú của bạn, nguồn',
    ink: 0xFF2B1E17,
    paper: 0xFFFFFCF8,
    accent: 0xFF9C4A2B,
    muted: 0xFF6B5649,
  ),
  ExportTemplate(
    id: 'bibliography',
    en: 'Research bibliography',
    vi: 'Danh mục tài liệu',
    tagEn: 'Numbered references with site, date and address',
    tagVi: 'Tài liệu đánh số với trang, ngày và địa chỉ',
    ink: 0xFF111111,
    paper: 0xFFFFFFFF,
    accent: 0xFF1F5F8B,
    muted: 0xFF555555,
    usesImages: false,
  ),
  ExportTemplate(
    id: 'magazine',
    en: 'Reading list magazine',
    vi: 'Tạp chí danh sách đọc',
    tagEn: 'A cover page, then two columns of features',
    tagVi: 'Trang bìa, rồi hai cột bài',
    ink: 0xFF171717,
    paper: 0xFFFBFAF6,
    accent: 0xFFA6533C,
    muted: 0xFF5E5B55,
  ),
  ExportTemplate(
    id: 'wishlist',
    en: 'Wishlist',
    vi: 'Danh sách mong muốn',
    tagEn: 'Things you want, each with your reason and its link',
    tagVi: 'Món bạn muốn, kèm lý do và đường dẫn',
    ink: 0xFF2A1F22,
    paper: 0xFFFFFFFF,
    accent: 0xFFA83E62,
    muted: 0xFF6A5559,
    serifTitles: false,
  ),
  ExportTemplate(
    id: 'moodboard',
    en: 'Moodboard',
    vi: 'Bảng cảm hứng',
    tagEn: 'Pictures first, in a collage, short captions',
    tagVi: 'Ảnh là chính, ghép thành mảng, chú thích ngắn',
    ink: 0xFF15120F,
    paper: 0xFFF6F2EA,
    accent: 0xFF15120F,
    muted: 0xFF6B6259,
    serifTitles: false,
    showsNotes: false,
  ),
  ExportTemplate(
    id: 'print',
    en: 'Minimal print list',
    vi: 'Danh sách in tối giản',
    tagEn: 'Text only, little ink, every address written out',
    tagVi: 'Chỉ chữ, ít mực, ghi đủ mọi địa chỉ',
    ink: 0xFF000000,
    paper: 0xFFFFFFFF,
    accent: 0xFF000000,
    muted: 0xFF555555,
    serifTitles: false,
    usesImages: false,
  ),
];

ExportTemplate? exportTemplateById(String? id) =>
    exportTemplates.where((t) => t.id == id).firstOrNull;

/// Only web addresses become links; anything else is left as text.
String? safeLink(String? url) {
  final u = Uri.tryParse(url ?? '');
  return u != null &&
          (u.scheme == 'http' || u.scheme == 'https') &&
          u.host.isNotEmpty
      ? u.toString()
      : null;
}

/// The saves of [collectionId] in the list's order, as export items.
Future<List<ExportItem>> exportItems(
  SaveController c,
  List<Bookmark> rows, {
  bool images = true,
}) async {
  final out = <ExportItem>[];
  for (final b in rows) {
    Uint8List? picture;
    if (images) {
      try {
        picture = b.media != null
            ? await c.mediaPreview(b.media!.id)
            : await c.thumbnail(b.id);
      } catch (_) {
        picture = null;
      }
    }
    out.add(
      ExportItem(
        title: b.title.isNotEmpty ? b.title : b.sourceDomain,
        source: b.isImage
            ? ''
            : b.sourceDomain.replaceFirst(RegExp(r'^www\.'), ''),
        date: b.savedAt.length >= 10 ? b.savedAt.substring(0, 10) : b.savedAt,
        url: b.hasUrl ? safeLink(b.originalUrl) : null,
        note: b.note.trim().isEmpty ? null : b.note.trim(),
        description: (b.description ?? '').trim().isEmpty
            ? null
            : b.description!.trim(),
        tags: b.tags,
        image: picture,
      ),
    );
  }
  return out;
}
