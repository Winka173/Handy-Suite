# Repository audit - 2026-11-02

Nine Flutter apps / twenty shared packages before Trip. Flutter 3.44.9, Dart 3.12.2,
plain controllers, Navigator and Handy UI kit; no framework replacement. Existing
apps are concurrently edited: preserve their working tree and evidence. No AGENTS.md
found in workspace. Core baseline tests and workspace analyze passed before Trip;
baseline Habit Web build was checked. Later concurrent edits require scoped evidence.

Reuse HandyApp/theme/fonts/commit dialog/date picker, HandyFiles and camera adapter,
portable ZIP guards, SQLite worker/CAS and IndexedDB transaction patterns, native
notifications and official Ads/Pro adapters. New app owns its data and domain engine.
No map/location dependency existed before Trip. Added foreground-only geolocator to Trip, not shared
UI, so other apps do not load its native plugin. No geocoding, scraping or tile backend.

No backend, AI, paid APIs or publisher accounts. iOS requires Mac/Xcode unavailable
here; physical-device and official-store verification cannot be claimed from Windows.
