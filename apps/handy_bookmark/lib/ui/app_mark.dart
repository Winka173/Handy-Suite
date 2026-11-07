import 'package:flutter/widgets.dart';

/// The app's own icon, where a guide or mock share sheet shows where Handy
/// Bookmark appears in the system.
class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size, this.radius, this.ring});

  final double size;
  final double? radius;

  /// A border drawn around it, as Android does for a badge on a shortcut.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * .22;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
      ),
    );
    if (ring == null) return image;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: ring!, width: 2),
      ),
      child: image,
    );
  }
}
