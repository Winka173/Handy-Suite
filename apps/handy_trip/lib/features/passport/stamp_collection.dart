import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../../scope.dart';
import 'stamp_design.dart';
import 'stamp_studio.dart';
import 'stamp_styles.dart';

/// The design a saved stamp was kept with, for [v]; [photo] is drawn in
/// its window when given.
StampDesign savedDesign(TripState s, Visit v, {ui.Image? photo}) {
  final st = v.stamp!, data = stampData(s, v.key);
  final place = st['place'] as String;
  return StampDesign(
        place: place.isEmpty ? data['place'] as String : place,
        day: data['day'] as String,
        seed: v.key.hashCode,
      )
      .withStyle(stampStyle(st['style'] as String))
      .copyWith(
        ink: st['ink'] as int,
        trip: st['trip'] == true ? data['trip'] as String : '',
        zoom: (st['zoom'] as num).toDouble(),
        offset: Offset(
          (st['dx'] as num).toDouble(),
          (st['dy'] as num).toDouble(),
        ),
        rotation: (st['rotation'] as num).toDouble(),
        wear: (st['wear'] as num).toDouble(),
        photo: photo,
      );
}

/// The bytes of a saved stamp's photo (its preview unless [full]).
Uint8List? stampPhotoBytes(TripState s, Visit v, {bool full = false}) {
  final key = v.stamp?['photo'];
  if (key == null) return null;
  final a = s.assets.where((a) => a.key == key).firstOrNull;
  if (a == null) return null;
  return full
      ? s.files[a.path] ?? s.files[a.data['preview']]
      : s.files[a.data['preview'] ?? a.path] ?? s.files[a.path];
}

Future<ui.Image?> _decode(Uint8List? bytes, int width) async {
  if (bytes == null) return null;
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
  return (await codec.getNextFrame()).image;
}

/// Every kept stamp on one A4 sheet or more, twelve to a page, to cut out.
Future<Uint8List> stampsSheetPdf(List<Uint8List> pngs, String label) async {
  final font = pw.Font.ttf(
    await rootBundle.load(
      'packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
    ),
  );
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font));
  for (var page = 0; page < pngs.length; page += 12) {
    final batch = pngs.skip(page).take(12).toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        build: (_) => pw.Column(
          children: [
            for (var row = 0; row < 4; row++)
              pw.Expanded(
                child: pw.Row(
                  children: [
                    for (var col = 0; col < 3; col++)
                      pw.Expanded(
                        child: row * 3 + col < batch.length
                            ? pw.Padding(
                                padding: const pw.EdgeInsets.all(
                                  3 * PdfPageFormat.mm,
                                ),
                                child: pw.Image(
                                  pw.MemoryImage(batch[row * 3 + col]),
                                  fit: pw.BoxFit.contain,
                                ),
                              )
                            : pw.SizedBox(),
                      ),
                  ],
                ),
              ),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      ),
    );
  }
  return doc.save();
}

/// The Passport's stamps: what the person kept, grouped by trip, newest
/// first. A stamp opens in the workshop as it was saved.
class StampCollection extends StatelessWidget {
  final TripScope scope;
  const StampCollection({super.key, required this.scope});

  Future<void> printAll(BuildContext context, List<Visit> visits) =>
      scope.run(context, () async {
        final s = scope.state, pngs = <Uint8List>[];
        for (final v in visits) {
          final photo = await _decode(stampPhotoBytes(s, v, full: true), 1400);
          pngs.add(
            await renderStampPng(savedDesign(s, v, photo: photo), side: 900),
          );
          photo?.dispose();
        }
        final pdf = await stampsSheetPdf(
          pngs,
          'Personal travel memory — not an official document',
        );
        await scope.files.exportBytes(
          'handy-trip-stamps.pdf',
          pdf,
          mimeType: 'application/pdf',
        );
      });

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final visits = stampedVisits(s);
    final groups = <String, List<Visit>>{};
    for (final v in visits) {
      final trip = v.trip == null ? '' : s.trip(v.trip!).title;
      groups.putIfAbsent(trip, () => []).add(v);
    }
    return Column(
      key: const Key('stamp-collection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  visits.isEmpty
                      ? tr(context, 'Your stamps', 'Tem của bạn')
                      : tr(
                          context,
                          'Your stamps · ${visits.length}',
                          'Tem của bạn · ${visits.length}',
                        ),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
            if (visits.isNotEmpty)
              TextButton.icon(
                key: const Key('stamps-print'),
                onPressed: () => printAll(context, visits),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(tr(context, 'A4 sheet', 'In tờ A4')),
              ),
          ],
        ),
        if (visits.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.s),
            child: Text(
              tr(
                context,
                'Make one from a confirmed visit: tap the stamp beside a place below.',
                'Làm tem từ một lượt ghé đã xác nhận: chạm biểu tượng tem cạnh một nơi bên dưới.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ),
        for (final MapEntry(key: trip, value: list) in groups.entries) ...[
          if (groups.length > 1 || trip.isNotEmpty)
            HandyLabel(
              trip.isEmpty ? tr(context, 'No trip', 'Ngoài chuyến') : trip,
            ),
          Wrap(
            spacing: HandySpace.m,
            runSpacing: HandySpace.m,
            children: [
              for (final v in list)
                _StampTile(
                  key: Key('stamp-tile-${v.key}'),
                  state: s,
                  visit: v,
                  onTap: () => openStampStudio(context, scope, v.key),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StampTile extends StatefulWidget {
  final TripState state;
  final Visit visit;
  final VoidCallback onTap;
  const _StampTile({
    super.key,
    required this.state,
    required this.visit,
    required this.onTap,
  });
  @override
  State<_StampTile> createState() => _StampTileState();
}

class _StampTileState extends State<_StampTile> {
  ui.Image? photo;

  @override
  void initState() {
    super.initState();
    _decode(stampPhotoBytes(widget.state, widget.visit), 360).then((img) {
      if (mounted) {
        setState(() => photo = img);
      } else {
        img?.dispose();
      }
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    photo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = savedDesign(widget.state, widget.visit, photo: photo);
    return Semantics(
      button: true,
      label: tr(
        context,
        'Stamp: ${d.place}, ${d.day}',
        'Tem: ${d.place}, ${d.day}',
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 112,
          child: CustomPaint(painter: StampPainter(d)),
        ),
      ),
    );
  }
}
