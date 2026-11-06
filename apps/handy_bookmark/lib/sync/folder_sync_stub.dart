import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

/// The browser has no folder a cloud client keeps in step.
bool folderSyncSupported(String kind) => false;

SyncProvider? folderSyncProvider(String kind, String ref) => null;
