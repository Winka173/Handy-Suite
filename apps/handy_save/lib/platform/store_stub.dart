import 'store.dart';

Future<void> preserveAndResetStore() =>
    Future.error(UnsupportedError('Storage recovery unavailable'));

Future<BookmarkStore> openStore() =>
    Future.error(UnsupportedError('Local storage is unavailable'));
