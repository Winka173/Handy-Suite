import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_core/csv.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import '../../scope.dart';
import '../../ui/form.dart';
import 'pdf_export.dart';
import 'place_columns.dart';

TripState _restore((Uint8List, bool) input) =>
    readBackup(input.$1, zip: input.$2);
Future<void> showTripData(
  BuildContext context,
  TripScope scope, {
  String? tripId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Export and restore', 'Xuất và khôi phục')),
      ),
      body: ExportPanel(scope: scope, tripId: tripId),
    ),
  ),
);

class ExportPanel extends StatefulWidget {
  final TripScope scope;
  final String? tripId;
  const ExportPanel({super.key, required this.scope, this.tripId});
  @override
  State<ExportPanel> createState() => _ExportState();
}

class _ExportState extends State<ExportPanel> {
  bool busy = false;
  String? error;
  String? selectedDay;
  TripScope get scope => widget.scope;
  Future<void> job(Future<void> Function() work) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Operation failed or data changed. Existing data and source files are preserved. Check format/size and retry.',
            'Thao tác thất bại hoặc dữ liệu đã đổi. Giữ nguyên dữ liệu và tệp nguồn. Kiểm tra định dạng/kích thước rồi thử lại.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export(String kind) async {
    final vietnamese = Localizations.localeOf(context).languageCode == 'vi',
        snapshot = scope.state,
        s = widget.tripId == null
            ? snapshot
            : selectTrip(snapshot, widget.tripId!, on: selectedDay);
    final private =
        kind.startsWith('backup') ||
        kind.startsWith('csv:') ||
        kind.startsWith('private-journal');
    if (!await tripConfirm(
      context,
      private
          ? tr(
              context,
              'Private export includes original photos, booking codes and notes. Keep it safe. No financial sync is performed.',
              'Xuất riêng tư có ảnh gốc, mã đặt chỗ và ghi chú. Hãy giữ an toàn. Không có đồng bộ tài chính.',
            )
          : tr(
              context,
              'Review titles and visible image content before sharing. Public reports omit booking codes, private notes/addresses, photo EXIF and precise GPS.',
              'Kiểm tra tên và nội dung hiển thị trên ảnh trước khi chia sẻ. Bản công khai bỏ mã đặt chỗ, ghi chú/địa chỉ riêng, EXIF ảnh và GPS chính xác.',
            ),
    ))
      return;
    Uint8List bytes;
    String ext, mime;
    if (kind == 'backup-json' || kind == 'backup-zip') {
      ext = kind == 'backup-zip' ? 'zip' : 'json';
      mime = ext == 'zip' ? 'application/zip' : 'application/json';
      bytes = fullBackup(s, zip: ext == 'zip');
    } else if (kind.startsWith('csv:')) {
      ext = 'csv';
      mime = 'text/csv';
      bytes = Uint8List.fromList(
        utf8.encode(exportCsv(s, kind.split(':').last)),
      );
    } else if (kind == 'album') {
      ext = 'zip';
      mime = 'application/zip';
      bytes = await compute(photoAlbum, s);
    } else if (kind == 'private-journal-json' || kind == 'private-journal-md') {
      ext = kind.endsWith('json') ? 'json' : 'md';
      mime = ext == 'json' ? 'application/json' : 'text/markdown';
      bytes = Uint8List.fromList(
        utf8.encode(
          ext == 'json'
              ? jsonEncode(journalDocument(s, privateText: true))
              : journalMarkdown(s, privateText: true),
        ),
      );
    } else if (kind == 'pdf' || kind == 'journal-pdf') {
      ext = 'pdf';
      mime = 'application/pdf';
      bytes = await tripPdf(
        s,
        journal: kind == 'journal-pdf',
        vietnamese: vietnamese,
      );
    } else {
      ext = kind;
      mime = kind == 'json'
          ? 'application/json'
          : kind == 'ics'
          ? 'text/calendar'
          : 'text/markdown';
      bytes = Uint8List.fromList(
        utf8.encode(
          kind == 'json'
              ? jsonEncode(publicDocument(s))
              : kind == 'ics'
              ? exportIcs(s)
              : markdownItinerary(s, vietnamese: vietnamese),
        ),
      );
    }
    if (bytes.length > portableLimit)
      throw const FormatException('Export exceeds 30 MB');
    final saved = await scope.files.exportBytes(
      'handy-trip-${day(scope.clock())}.$ext',
      bytes,
      mimeType: mime,
    );
    if (saved != null && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? tr(
                    context,
                    'Download requested. Verify the downloaded file.',
                    'Đã yêu cầu tải xuống. Hãy kiểm tra tệp đã tải.',
                  )
                : tr(
                    context,
                    'Export copy saved. Original files unchanged.',
                    'Đã lưu bản sao xuất. Tệp gốc không đổi.',
                  ),
          ),
        ),
      );
  }

  Future<void> restoreFile([ImportedBytes? dropped]) async {
    final file =
        dropped ??
        await scope.files.importBytes(
          extensions: ['json', 'zip', 'csv', 'ics'],
          maxBytes: portableLimit,
        );
    if (file == null) return;
    final revision = scope.state.revision,
        extension = file.name.split('.').last.toLowerCase();
    TripState? imported;
    TripState? proposed;
    if (extension == 'zip' || extension == 'json') {
      imported = await compute(_restore, (file.bytes, extension == 'zip'));
    } else if (extension == 'ics') {
      final trip = scope.trip;
      if (trip == null)
        throw const FormatException(
          'Choose an existing target trip before calendar import',
        );
      proposed = importIcs(scope.state, trip.key, utf8.decode(file.bytes));
    } else if (extension == 'csv') {
      final text = utf8.decode(file.bytes), rows = csvParse(text);
      if (rows.length < 2) throw const FormatException('CSV has no data');
      if (rows.first.contains('record_b64')) {
        final kind = rows[1].first;
        if (![
          'stops',
          'places',
          'expenses',
          'packing',
          'visits',
          'notes',
        ].contains(kind))
          throw const FormatException('Unsupported own CSV kind');
        proposed = importOwnCsv(scope.state, text, kind);
      } else {
        if (!mounted) return;
        final type = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(tr(context, 'CSV destination', 'Nhập CSV vào')),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'itinerary'),
                child: Text(
                  tr(
                    context,
                    'Itinerary for selected trip',
                    'Lịch trình chuyến đang chọn',
                  ),
                ),
              ),
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'places'),
                child: Text(
                  tr(context, 'Saved places / wishlist', 'Địa điểm / wishlist'),
                ),
              ),
            ],
          ),
        );
        if (type == null || !mounted) return;
        if (type == 'places') {
          proposed = await mapPlaceColumns(context, scope.state, rows);
        } else {
          final trip = scope.trip;
          if (trip == null)
            throw const FormatException(
              'Select an existing target trip for mapped itinerary CSV',
            );
          if (!mounted) return;
          final columns = {
            for (var i = 0; i < rows.first.length; i++) '$i': rows.first[i],
          };
          await tripForm(
            context,
            tr(context, 'Map itinerary CSV columns', 'Chọn cột CSV lịch trình'),
            [
              TripField(
                'title',
                'Title column',
                'Cột tên',
                kind: 'choice',
                choices: columns,
              ),
              TripField(
                'day',
                'YYYY-MM-DD day column',
                'Cột ngày YYYY-MM-DD',
                kind: 'choice',
                choices: columns,
              ),
              TripField(
                'time',
                'HH:mm time (optional)',
                'Giờ HH:mm (tùy chọn)',
                kind: 'choice',
                optional: true,
                choices: {
                  '': tr(context, 'Not included', 'Không có'),
                  ...columns,
                },
              ),
              TripField(
                'place',
                'Existing place name (optional)',
                'Tên địa điểm đã lưu (tùy chọn)',
                kind: 'choice',
                optional: true,
                choices: {
                  '': tr(context, 'Not included', 'Không có'),
                  ...columns,
                },
              ),
            ],
            {
              'title': '0',
              'day': rows.first.length > 1 ? '1' : '0',
              'time': '',
              'place': '',
            },
            (v) async {
              proposed = importItineraryTable(
                scope.state,
                trip.key,
                rows,
                titleColumn: int.parse(v['title']),
                dayColumn: int.parse(v['day']),
                timeColumn: v['time'] == '' ? null : int.parse(v['time']),
                placeColumn: v['place'] == '' ? null : int.parse(v['place']),
              );
            },
          );
          if (proposed == null) return;
        }
      }
    }
    if (!mounted) return;
    if (imported != null) {
      final restore = imported;
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'Backup preview', 'Xem trước backup')),
          content: Text(
            '${restore.trips.length} ${tr(context, 'trips', 'chuyến')} · ${restore.visits.length} ${tr(context, 'visits', 'lượt ghé')} · ${restore.assets.length} ${tr(context, 'attachments', 'đính kèm')}\n${tr(context, 'Merge remaps all incoming IDs. Imported reminders stay disabled. Replacement overwrites this device.', 'Hợp nhất đổi mọi ID nhập vào. Nhắc nhập vào vẫn tắt. Thay thế ghi đè dữ liệu thiết bị.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel', 'Hủy')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'merge'),
              child: Text(tr(context, 'Merge', 'Hợp nhất')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'replace'),
              child: Text(tr(context, 'Replace', 'Thay thế')),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;
      if (mode == 'replace' &&
          !await tripConfirm(
            context,
            tr(
              context,
              'Replace all Trip data on this device? Keep a private backup first.',
              'Thay toàn bộ dữ liệu Trip trên thiết bị? Hãy có backup riêng trước.',
            ),
          ))
        return;
      await scope.controller.change((s) {
        if (s.revision != revision)
          throw StateError('Data changed during preview');
        final next = mode == 'merge'
            ? mergeBackup(
                s,
                restore,
                digest: sha256.convert(file.bytes).toString(),
              )
            : restore;
        return next.copy({
          'settings': {...next.settings, 'notifications': false},
          'alarms': next.alarms
              .map((a) => a.copy({'enabled': false}).toJson())
              .toList(),
        });
      });
    } else if (proposed != null) {
      final next = proposed!;
      if (!await tripConfirm(
        context,
        tr(
          context,
          'Apply validated import? ${next.stops.length - scope.state.stops.length} new stops; ${next.places.length - scope.state.places.length} new places. Existing matching IDs stay unchanged; conflicts are refused.',
          'Áp dụng dữ liệu đã kiểm tra? ${next.stops.length - scope.state.stops.length} điểm dừng mới; ${next.places.length - scope.state.places.length} địa điểm mới. Giữ ID trùng khớp; từ chối xung đột.',
        ),
      ))
        return;
      await scope.controller.change((s) {
        if (s.revision != revision)
          throw StateError('Data changed during preview');
        return next;
      });
    }
    await scope.reminders.sync(scope.state);
  }

  @override
  Widget build(BuildContext context) => DropTarget(
    onDragDone: (details) => job(() async {
      if (details.files.length != 1)
        throw const FormatException('Drop one import file at a time');
      final f = details.files.single;
      if (await f.length() > portableLimit)
        throw const FormatException('Import exceeds 30 MB');
      await restoreFile(ImportedBytes(f.name, await f.readAsBytes()));
    }),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          widget.tripId == null
              ? tr(context, 'All saved Trip data', 'Toàn bộ dữ liệu Trip')
              : tr(context, 'Selected trip', 'Chuyến đã chọn'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!),
        if (widget.tripId != null)
          DropdownButtonFormField<String>(
            initialValue: selectedDay ?? '',
            decoration: InputDecoration(
              labelText: tr(context, 'Export dates', 'Ngày xuất'),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(tr(context, 'Entire trip', 'Toàn chuyến')),
              ),
              for (final d in scope.state.trip(widget.tripId!).days)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() => selectedDay = v == '' ? null : v),
          ),
        Text(
          tr(
            context,
            'Full backup restores relational data and managed original files. Public reports are not full backups. Per portable file: at most 30 MB / 998 payload entries. Select a trip/day for larger libraries; nothing is silently removed.',
            'Backup đầy đủ khôi phục quan hệ dữ liệu và tệp gốc được quản lý. Bản công khai không phải backup. Mỗi gói tối đa 30 MB / 998 mục. Chọn chuyến/ngày với thư viện lớn; không tự xóa dữ liệu.',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final (kind, en, vi) in [
              ('backup-zip', 'Private backup ZIP', 'Backup ZIP riêng tư'),
              ('backup-json', 'Private backup JSON', 'Backup JSON riêng tư'),
              (
                'md',
                'Public itinerary Markdown',
                'Lịch trình Markdown công khai',
              ),
              ('pdf', 'Public itinerary PDF', 'Lịch trình PDF công khai'),
              ('json', 'Public itinerary JSON', 'Lịch trình JSON công khai'),
              ('ics', 'Public calendar ICS', 'Lịch ICS công khai'),
              (
                'album',
                'Share photo album ZIP (metadata stripped)',
                'ZIP album chia sẻ (bỏ metadata)',
              ),
              (
                'private-journal-json',
                'Private journal JSON',
                'JSON nhật ký riêng tư',
              ),
              (
                'private-journal-md',
                'Private journal Markdown',
                'Markdown nhật ký riêng tư',
              ),
              (
                'journal-pdf',
                'Journal photo PDF (metadata stripped)',
                'PDF ảnh nhật ký (bỏ metadata)',
              ),
            ])
              TextButton(
                onPressed: busy ? null : () => job(() => export(kind)),
                child: Text(tr(context, en, vi)),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          tr(
            context,
            'Private CSV tables (matching parent IDs required on import)',
            'Bảng CSV riêng tư (cần ID cha khớp khi nhập)',
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final kind in [
              'stops',
              'places',
              'expenses',
              'packing',
              'visits',
              'notes',
            ])
              TextButton(
                onPressed: busy ? null : () => job(() => export('csv:$kind')),
                child: Text(kind.toUpperCase()),
              ),
          ],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: busy ? null : () => job(() => restoreFile()),
          icon: const Icon(Icons.file_open_outlined),
          label: Text(
            tr(
              context,
              'Import / drop one backup, CSV or ICS file here',
              'Nhập / thả một backup, CSV hoặc ICS vào đây',
            ),
          ),
        ),
      ],
    ),
  );
}
