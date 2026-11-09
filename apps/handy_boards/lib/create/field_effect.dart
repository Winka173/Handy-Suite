import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../board/key_dates.dart' show keyDateLine;

/// What a Smart Setup answer puts on the new board, in plain words and
/// with the answer as it stands, so each field explains itself: the title
/// at the top, one group per chip, the key date under the title with its
/// days left, the columns a switch or a choice brings.
String fieldEffect(
  BuildContext context,
  BoardTemplate t,
  SetupField f,
  Object? value,
  DateTime now,
) {
  final vi = Localizations.localeOf(context).languageCode == 'vi';
  String names(List<TemplateColumn> columns) =>
      columns.map((c) => c.name.of(vi)).join(' → ');
  DateTime? day(Object? v) => v is String && v.isNotEmpty ? localDate(v) : null;
  switch (f.role) {
    case FieldRole.title:
      final v = value is String && value.trim().isNotEmpty
          ? value.trim()
          : f.label.of(vi);
      return tr(
        context,
        'The board’s name, at the top of the board and on Your boards: “$v”.',
        'Tên bảng, ở đầu bảng và ở Bảng của bạn: “$v”.',
      );
    case FieldRole.categories:
      final chips = [for (final c in value is List ? value : const []) '$c'];
      final list = chips.isEmpty
          ? ''
          : tr(
              context,
              ' Now: ${chips.join(', ')}.',
              ' Hiện có: ${chips.join(', ')}.',
            );
      return tr(
        context,
        'Each one becomes a group: a coloured tile above the columns with how many of its cards are done, and a tape label on its cards.$list',
        'Mỗi mục thành một nhóm: một ô màu phía trên các cột ghi số thẻ đã xong, và nhãn băng keo trên các thẻ của nhóm.$list',
      );
    case FieldRole.milestone:
      if (f.kind == FieldKind.dateRange) {
        final pair = value is List ? value : const [];
        final end = day(pair.length > 1 ? pair[1] : null);
        final line = end == null
            ? ''
            : ' ${tr(context, 'For example', 'Ví dụ')}: “${keyDateLine(context, (f.endLabel ?? f.label).of(vi), end, now)}”.';
        return tr(
          context,
          'Two key dates (the start and the end), shown under the board’s name with the days left; example cards take their due dates from them.$line',
          'Hai ngày quan trọng (bắt đầu và kết thúc), hiện dưới tên bảng kèm số ngày còn lại; thẻ ví dụ lấy hạn theo hai ngày này.$line',
        );
      }
      final d = day(value);
      final line = d == null
          ? ''
          : ' ${tr(context, 'It will read', 'Sẽ hiện')}: “${keyDateLine(context, f.label.of(vi), d, now)}”.';
      return tr(
        context,
        'A key date, shown under the board’s name with the days left (you can add more, with a time, later); example cards take their due dates from it.$line',
        'Một ngày quan trọng, hiện dưới tên bảng kèm số ngày còn lại (sau này thêm được ngày khác, có giờ); thẻ ví dụ lấy hạn theo ngày này.$line',
      );
    case FieldRole.optionalColumns:
      final extra = [
        for (final c in t.columns)
          if (c.onlyWith == f.id) c,
      ];
      final on = value == true;
      return on
          ? tr(
              context,
              'On: the board has the column ${names(extra)}. Columns: ${names([for (final c in t.columns)
                if (c.onlyWith == null || c.onlyWith == f.id) c])}.',
              'Bật: bảng có thêm cột ${names(extra)}. Các cột: ${names([for (final c in t.columns)
                if (c.onlyWith == null || c.onlyWith == f.id) c])}.',
            )
          : tr(
              context,
              'Off: no ${names(extra)} column. Columns: ${names([for (final c in t.columns)
                if (c.onlyWith == null) c])}.',
              'Tắt: không có cột ${names(extra)}. Các cột: ${names([for (final c in t.columns)
                if (c.onlyWith == null) c])}.',
            );
    case FieldRole.columnSet:
      final option = f.options.where((o) => o.id == value).firstOrNull;
      final columns = option?.columns ?? t.columns;
      return tr(
        context,
        'Sets the board’s columns, left to right: ${names(columns)}.',
        'Chọn các cột của bảng, từ trái sang phải: ${names(columns)}.',
      );
    case FieldRole.presentation:
      return tr(
        context,
        'How cards look: compact (title, label, subtasks as 1/3) or detailed (each subtask listed to tick). Changeable later in the board menu.',
        'Thẻ trông thế nào: gọn (tiêu đề, nhãn, việc con dạng 1/3) hay chi tiết (liệt kê từng việc con để tích). Đổi được sau trong menu bảng.',
      );
    case FieldRole.timeRange:
      return tr(
        context,
        'The board opens on this span of time (a week, a month…), with arrows under its name to go to the next or the last.',
        'Bảng mở theo khoảng thời gian này (tuần, tháng…), có mũi tên dưới tên bảng để sang kỳ sau hay kỳ trước.',
      );
    case FieldRole.sampleSet:
      return tr(
        context,
        'Which example cards are added when Add a few example cards is on; delete them any time.',
        'Chọn bộ thẻ ví dụ được thêm khi bật Thêm vài thẻ ví dụ; xoá lúc nào cũng được.',
      );
  }
}
