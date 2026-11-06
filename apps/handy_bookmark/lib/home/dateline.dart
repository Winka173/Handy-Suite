import '../controller.dart';

/// The library's own name when the person gave it one, else the app's.
/// (The home's dateline that lived here was dropped on 2026-11-06: the
/// "Recently saved" shelf already says how much waits to be sorted.)
String libraryName(SaveController c) {
  final name = (c.preferences['libraryName'] as String? ?? '').trim();
  return name.isEmpty ? 'Handy Bookmark' : name;
}
