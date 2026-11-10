import 'package:handy_ui/kit.dart';
import 'palette.dart';

const studioPalettes = ['vermilion', 'grove', 'ochre'];
const studioExtraIcons = <String, IconData>{
  'leaf': Icons.eco_outlined,
  'music': Icons.music_note_outlined,
  'sun': Icons.wb_sunny_outlined,
  'coffee': Icons.coffee_outlined,
  'cycle': Icons.directions_bike_outlined,
  'brush': Icons.brush_outlined,
};
const studioIconLabels = <String, (String, String)>{
  'leaf': ('Leaf', 'Lá'),
  'music': ('Music', 'Âm nhạc'),
  'sun': ('Sun', 'Nắng'),
  'coffee': ('Coffee', 'Cà phê'),
  'cycle': ('Cycling', 'Đạp xe'),
  'brush': ('Art', 'Vẽ'),
};

@immutable
class StudioStyle extends ThemeExtension<StudioStyle> {
  final String palette, layout, spacing, runner;
  final Map<String, String> icons;
  const StudioStyle({
    this.palette = 'vermilion',
    this.layout = 'rows',
    this.spacing = 'normal',
    this.runner = 'beads',
    this.icons = const {},
  });
  factory StudioStyle.read(Map<String, dynamic> settings, {required bool pro}) {
    if (!pro) return const StudioStyle();
    final raw = settings['studio'];
    if (raw is! Map) return const StudioStyle();
    String value(String key, List<String> allowed) =>
        allowed.contains(raw[key]) ? raw[key] as String : allowed.first;
    final icons = raw['icons'];
    return StudioStyle(
      palette: value('palette', studioPalettes),
      layout: value('layout', ['rows', 'cards']),
      spacing: value('spacing', ['normal', 'airy']),
      runner: value('runner', ['beads', 'quiet']),
      icons: Map.unmodifiable(
        icons is Map
            ? <String, String>{
                for (final e in icons.entries)
                  if (e.key is String && studioExtraIcons.containsKey(e.value))
                    e.key as String: e.value as String,
              }
            : <String, String>{},
      ),
    );
  }
  Map<String, dynamic> toJson() => {
    'palette': palette,
    'layout': layout,
    'spacing': spacing,
    'runner': runner,
    'icons': icons,
  };
  static StudioStyle of(BuildContext c) =>
      Theme.of(c).extension<StudioStyle>() ?? const StudioStyle();
  @override
  StudioStyle copyWith() => this;
  @override
  StudioStyle lerp(StudioStyle? other, double t) =>
      other == null || t < .5 ? this : other;
}

HabitPalette studioPalette(String name, bool dark) {
  if (name == 'vermilion' || !studioPalettes.contains(name))
    return dark ? HabitPalette.dark : HabitPalette.light;
  if (name == 'grove')
    return dark
        ? const HabitPalette(
            canvas: Color(0xff121612),
            surface: Color(0xff1a221c),
            raised: Color(0xff27342a),
            ink: Color(0xfff1f8ee),
            muted: Color(0xffb6cbb8),
            line: Color(0xff405044),
            control: Color(0xff91a895),
            anchor: Color(0xffb6d7b7),
            onAnchor: Color(0xff193421),
            vermilion: Color(0xff92cb99),
            onVermilion: Color(0xff172b1a),
            tint: Color(0xff223d29),
            ochre: Color(0xffe6be70),
            ochreField: Color(0xff382d18),
          )
        : const HabitPalette(
            canvas: Color(0xfff4f7f1),
            surface: Color(0xffffffff),
            raised: Color(0xffe5ecdf),
            ink: Color(0xff18291c),
            muted: Color(0xff485a4b),
            line: Color(0xffd4dfd0),
            control: Color(0xff738b75),
            anchor: Color(0xff264c36),
            onAnchor: Color(0xfff5fff5),
            vermilion: Color(0xff27643f),
            onVermilion: Color(0xffffffff),
            tint: Color(0xffdcebdc),
            ochre: Color(0xff805500),
            ochreField: Color(0xfff5ebcf),
          );
  return dark
      ? const HabitPalette(
          canvas: Color(0xff19150f),
          surface: Color(0xff241e15),
          raised: Color(0xff342c1d),
          ink: Color(0xfffff4df),
          muted: Color(0xffcdbb9c),
          line: Color(0xff51442d),
          control: Color(0xffa28d6c),
          anchor: Color(0xffe7c58a),
          onAnchor: Color(0xff3a2910),
          vermilion: Color(0xffe0b563),
          onVermilion: Color(0xff33230b),
          tint: Color(0xff42341b),
          ochre: Color(0xffe0b563),
          ochreField: Color(0xff382d18),
        )
      : const HabitPalette(
          canvas: Color(0xfffaf7ef),
          surface: Color(0xffffffff),
          raised: Color(0xffeee7d5),
          ink: Color(0xff302617),
          muted: Color(0xff61543d),
          line: Color(0xffe1d7bf),
          control: Color(0xff958164),
          anchor: Color(0xff584020),
          onAnchor: Color(0xfffff5df),
          vermilion: Color(0xff805500),
          onVermilion: Color(0xffffffff),
          tint: Color(0xfff1e5c7),
          ochre: Color(0xff805500),
          ochreField: Color(0xfff5ebcf),
        );
}
