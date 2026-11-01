import 'package:handy_ui/kit.dart';
import 'editor_controller.dart';
import 'film_frame.dart';

/// The guide's steps as a strip of film: a column beside the picture on
/// wide screens, a row under it on phones. The last frame adds pictures.
class StepStrip extends StatelessWidget {
  final EditorController c;
  final bool busy, vertical;
  final VoidCallback onAdd;
  final VoidCallback? onCamera;
  const StepStrip({
    super.key,
    required this.c,
    required this.busy,
    required this.vertical,
    required this.onAdd,
    this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final steps = c.project.steps;
    final width = vertical ? 132.0 : 84.0;
    final items = [
      for (final (i, s) in steps.indexed)
        FilmFrame(
          key: ValueKey('step-frame-${s.id}'),
          number: i + 1,
          width: width,
          picture: c.assets[s.imageUri],
          step: s,
          selected: i == c.stepIndex,
          label: s.title,
          onTap: busy ? null : () => c.showStep(i),
        ),
      _AddFrame(
        key: const Key('capture-import-images'),
        width: width,
        icon: Icons.add_photo_alternate_outlined,
        label: tr(context, 'Add screenshots', 'Thêm ảnh chụp'),
        onTap: busy ? null : onAdd,
      ),
      if (onCamera != null)
        _AddFrame(
          key: const Key('capture-camera'),
          width: width,
          icon: Icons.photo_camera_outlined,
          label: tr(context, 'Take a photo', 'Chụp ảnh'),
          onTap: busy ? null : onCamera,
        ),
    ];
    return ListView.separated(
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      padding: const EdgeInsets.all(HandySpace.m),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const SizedBox(width: HandySpace.s, height: HandySpace.m),
      itemBuilder: (_, i) => Align(
        alignment: vertical ? Alignment.topCenter : Alignment.centerLeft,
        child: items[i],
      ),
    );
  }
}

class _AddFrame extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _AddFrame({
    super.key,
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: c.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: width,
            height: width * .62,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
