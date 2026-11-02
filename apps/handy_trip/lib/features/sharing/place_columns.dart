import 'package:handy_ui/kit.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import '../../ui/form.dart';

Future<TripState?> mapPlaceColumns(
  BuildContext context,
  TripState state,
  List<List<String>> rows,
) async {
  TripState? proposed;
  final columns = {
    for (var i = 0; i < rows.first.length; i++) '$i': rows.first[i],
  };
  await tripForm(
    context,
    tr(context, 'Map place CSV columns', 'Chọn cột CSV địa điểm'),
    [
      for (final (key, en, vi) in [
        ('name', 'Place name', 'Tên địa điểm'),
        ('url', 'Source URL', 'Link nguồn'),
        ('lat', 'Latitude', 'Vĩ độ'),
        ('lon', 'Longitude', 'Kinh độ'),
        ('city', 'City label', 'Tên thành phố'),
        ('country', 'Country label', 'Tên quốc gia'),
      ])
        TripField(
          key,
          en,
          vi,
          kind: 'choice',
          optional: key != 'name',
          choices: {
            if (key != 'name') '': tr(context, 'Not included', 'Không có'),
            ...columns,
          },
        ),
    ],
    {'name': '0', 'url': '', 'lat': '', 'lon': '', 'city': '', 'country': ''},
    (v) async {
      int? column(String key) => v[key] == '' ? null : int.parse(v[key]);
      proposed = importPlacesTable(
        state,
        rows,
        nameColumn: column('name')!,
        urlColumn: column('url'),
        latitudeColumn: column('lat'),
        longitudeColumn: column('lon'),
        cityColumn: column('city'),
        countryColumn: column('country'),
      );
    },
  );
  return proposed;
}
