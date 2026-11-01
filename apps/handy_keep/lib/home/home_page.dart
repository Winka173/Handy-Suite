import 'package:flutter/services.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../deep_links.dart';
import '../labels.dart';
import '../scope.dart';
import 'detail_pane.dart';
import 'filter_bar.dart';
import 'list_pane.dart';

/// Keep's one screen. Wide: the places on the left, the chosen item on the
/// right. Phone: the places, and an item opens as its own page.
class KeepHome extends StatefulWidget {
  final KeepScope scope;
  const KeepHome({super.key, required this.scope});
  @override
  State<KeepHome> createState() => _KeepHomeState();
}

class _KeepHomeState extends State<KeepHome> {
  final query = TextEditingController();
  final searchFocus = FocusNode();
  final links = KeepDeepLinks();
  KeepFilter filter = KeepFilter.all;
  String? box, selected, pending;
  bool opening = false;
  KeepScope get scope => widget.scope;

  @override
  void initState() {
    super.initState();
    query.addListener(() => setState(() {}));
    links.start(receive).catchError((Object _) {});
  }

  @override
  void dispose() {
    links.dispose();
    query.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  bool get wide => MediaQuery.sizeOf(context).width >= 900;

  void open(String id) => wide
      ? setState(() => selected = id)
      : Navigator.pushNamed(context, '/item/$id');

  void showBox(String? id) => setState(() {
    box = id;
    filter = KeepFilter.all;
    query.clear();
  });

  /// A label from the OS: keeps only the latest, opens only a local record.
  void receive(String value) {
    pending = value;
    openPending();
  }

  Future<void> openPending() async {
    if (!mounted || opening || pending == null || !scope.store.loaded) return;
    final value = pending!;
    pending = null;
    opening = true;
    try {
      // Wait until anything open on top (an editor, a dialog) has closed.
      if (ModalRoute.of(context)?.isCurrent == false) {
        pending ??= value;
        return;
      }
      go(InventoryLabel.parse(value));
    } on FormatException catch (e) {
      if (mounted) showHandyMessage(context, errorText(context, e));
    } finally {
      opening = false;
    }
  }

  /// Opens what a label points at; throws when it is not on this device.
  void go(InventoryLabel label) {
    final record = label.resolve(scope.state);
    record is InventoryAsset ? open(record.id) : showBox(label.id);
  }

  Future<void> scan() async {
    final label = await showDialog<InventoryLabel>(
      context: context,
      builder: (_) => OpenInventoryLabel(inventory: scope.state),
    );
    if (label != null && mounted) go(label);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => openPending());
    final wide = this.wide;
    final item = scope.state.assets.where((a) => a.id == selected).firstOrNull;
    final scanButton = IconButton(
      key: const Key('keep-open-label'),
      tooltip: tr(context, 'Open a label', 'Mở nhãn'),
      icon: const Icon(Icons.qr_code_scanner),
      onPressed: scan,
    );
    final list = ListPane(
      scope: scope,
      query: query,
      searchFocus: searchFocus,
      filter: filter,
      box: box,
      selected: wide ? selected : null,
      wide: wide,
      onFilter: (f) => setState(() => filter = f),
      onBox: showBox,
      onOpen: open,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            scope.edit(context, box: box ?? ''),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            setState(() => selected = null),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: HandyTopBar(
            mark: Icons.inventory_2_outlined,
            name: 'Handy Keep',
            nameIsTitle: false,
            actions: [if (wide) scanButton],
          ),
          bottomNavigationBar: wide
              ? null
              : HandyBottomBar(
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('keep-scan-bottom'),
                        onPressed: scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(tr(context, 'Label', 'Quét nhãn')),
                      ),
                      const SizedBox(width: HandySpace.m),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('item-new'),
                          onPressed: () => scope.edit(context, box: box ?? ''),
                          icon: const Icon(Icons.add),
                          label: Text(tr(context, 'Add item', 'Thêm đồ')),
                        ),
                      ),
                    ],
                  ),
                ),
          body: !wide
              ? list
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 520, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: DetailPane(
                        scope: scope,
                        item: item,
                        onClosed: () => setState(() => selected = null),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
