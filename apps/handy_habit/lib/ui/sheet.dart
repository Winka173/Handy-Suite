import 'package:handy_ui/kit.dart';

/// Opens a form: a full page on a phone, a 560px dialog on a wide screen.
/// (Ads are off on every route above the home; see `HabitApp`.)
Future<T?> openSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (MediaQuery.sizeOf(context).width >= HandySpace.wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: builder(context),
        ),
      ),
    );
  }
  return Navigator.push<T>(
    context,
    MaterialPageRoute(fullscreenDialog: true, builder: builder),
  );
}

/// The frame of a form: title and menu, a scrolling body, then the error
/// and the one primary action. Back is held while [busy].
class SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget primary;
  final String error;
  final bool busy;
  final List<Widget> actions;
  const SheetFrame({
    super.key,
    required this.title,
    required this.children,
    required this.primary,
    this.error = '',
    this.busy = false,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final dialog = ModalRoute.of(context) is PopupRoute;
    final cancel = TextButton(
      key: const Key('sheet-cancel'),
      onPressed: busy ? null : () => Navigator.maybePop(context),
      child: Text(tr(context, 'Cancel', 'Hủy')),
    );
    final foot = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: HandySpace.s),
            child: Semantics(
              liveRegion: true,
              child: Text(
                error,
                key: const Key('sheet-error'),
                style: theme.textTheme.bodyMedium?.copyWith(color: c.negative),
              ),
            ),
          ),
        Row(
          children: [
            if (dialog) ...[const Spacer(), cancel] else cancel,
            const SizedBox(width: HandySpace.s),
            if (dialog) primary else Expanded(child: primary),
          ],
        ),
      ],
    );
    final body = ListView(
      shrinkWrap: dialog,
      padding: EdgeInsets.fromLTRB(
        HandySpace.l,
        dialog ? 0 : HandySpace.l,
        HandySpace.l,
        HandySpace.xl,
      ),
      children: [
        for (final child in children)
          dialog ? child : HandyContent(maxWidth: 560, child: child),
      ],
    );
    return PopScope(
      canPop: !busy,
      child: dialog
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.xl,
                    HandySpace.l,
                    HandySpace.s,
                    HandySpace.s,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: theme.textTheme.titleLarge),
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                Flexible(child: body),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HandySpace.l,
                    HandySpace.s,
                    HandySpace.l,
                    HandySpace.l,
                  ),
                  child: foot,
                ),
              ],
            )
          : Scaffold(
              appBar: AppBar(title: Text(title), actions: actions),
              body: SafeArea(bottom: false, child: body),
              bottomNavigationBar: HandyBottomBar(child: foot),
            ),
    );
  }
}
