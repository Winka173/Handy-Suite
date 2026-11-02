import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import 'data/library.dart';
import 'data/store.dart';
import 'editor/studio_page.dart';
import 'home/home_page.dart';
import 'profiles/profiles_page.dart';
import 'scope.dart';

class CardApp extends StatefulWidget {
  final CardStore? store;
  final HandyFiles files;
  final DateTime Function()? clock;
  const CardApp({
    super.key,
    this.store,
    this.files = const SystemHandyFiles(),
    this.clock,
  });
  @override
  State<CardApp> createState() => _CardAppState();
}

class _CardAppState extends State<CardApp> {
  CardScope? scope;
  Object? error;
  final navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    open();
  }

  Future<void> open() async {
    try {
      final store = widget.store ?? await openCardStore();
      final library = CardLibrary(
        store,
        ElementRegistry.standard(),
        clock: widget.clock,
      );
      await library.load();
      if (library.error != null) throw library.error!;
      // Pictures nothing uses any more go now, before any design opens.
      await library.collectUnused();
      setState(() {
        scope = CardScope(
          library: library,
          images: CardImages(library),
          files: widget.files,
        );
        error = null;
      });
    } catch (e) {
      setState(() => error = e);
    }
  }

  void settings() => navigator.currentState?.push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/settings'),
      builder: (context) => _Settings(scope: scope!),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = scope;
    return ListenableBuilder(
      listenable: s?.library ?? ValueNotifier(0),
      builder: (context, _) => HandyApp(
        brand: HandyBrand.handyCard,
        app: 'card',
        title: 'Handy Card',
        accent: const Color(0xff1450f5),
        theme: s?.library.setting('theme', 'system') ?? 'system',
        locale: s?.library.setting('locale', 'system') ?? 'system',
        adsVisible: s?.adsVisible,
        navigatorKey: navigator,
        home: s == null
            ? HandyLoading(error: error, retry: error == null ? null : open)
            : HomePage(scope: s, openSettings: settings),
        onGenerateRoute: (route) {
          final parts = (route.name ?? '/').split('/');
          if (s == null) return null;
          if (parts.length == 3 && parts[1] == 'design') {
            return MaterialPageRoute<void>(
              settings: route,
              builder: (_) => StudioPage(scope: s, designId: parts[2]),
            );
          }
          if (route.name == '/settings') {
            return MaterialPageRoute<void>(
              settings: route,
              builder: (_) => _Settings(scope: s),
            );
          }
          if (route.name == '/profiles') {
            return MaterialPageRoute<void>(
              settings: route,
              builder: (_) => ProfilesPage(scope: s),
            );
          }
          return null;
        },
      ),
    );
  }
}

class _Settings extends StatelessWidget {
  final CardScope scope;
  const _Settings({required this.scope});

  @override
  Widget build(BuildContext context) {
    final lib = scope.library;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) => HandySettingsPage(
        appName: 'Handy Card',
        theme: lib.setting('theme', 'system'),
        locale: lib.setting('locale', 'system'),
        onTheme: (v) => lib.setSetting('theme', v),
        onLocale: (v) => lib.setSetting('locale', v),
        sections: [
          const LifetimeSettings(),
          HandySection(
            title: tr(context, 'Backup', 'Sao lưu'),
            children: [
              HandyTile(
                key: const Key('settings-backup'),
                icon: Icons.archive_outlined,
                title: tr(
                  context,
                  'Save everything to a file',
                  'Lưu tất cả ra file',
                ),
                subtitle: tr(
                  context,
                  '${lib.designs.length} designs, ${lib.profiles.length} profiles and their pictures, editable in Handy Card on any device.',
                  '${lib.designs.length} thiết kế, ${lib.profiles.length} hồ sơ và ảnh, sửa tiếp được trong Handy Card trên máy khác.',
                ),
                onTap: () async {
                  try {
                    final bytes = await lib.exportProject();
                    final uri = await scope.files.exportBytes(
                      'handy-card-backup.zip',
                      bytes,
                      mimeType: 'application/zip',
                    );
                    if (uri != null && context.mounted)
                      showHandyMessage(
                        context,
                        tr(context, 'Backup saved.', 'Đã lưu bản sao lưu.'),
                      );
                  } catch (e) {
                    if (context.mounted)
                      showHandyMessage(context, errorText(context, e));
                  }
                },
              ),
            ],
          ),
          HandySection(
            title: tr(context, 'Fonts', 'Phông chữ'),
            children: [
              HandyTile(
                icon: Icons.text_fields,
                title:
                    'Hanken Grotesk, Literata, Bricolage Grotesque, Geist Mono',
                subtitle: tr(
                  context,
                  'Open Font License: they are embedded in the PDFs you export.',
                  'Giấy phép Open Font License: được nhúng vào PDF bạn xuất.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
