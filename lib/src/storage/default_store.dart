import 'package:flutter/foundation.dart';

import 'shared_preferences_store.dart';
import 'sqflite_store_web.dart' if (dart.library.io) 'sqflite_store.dart';
import 'dolphin_store.dart';

/// SharedPreferences for flags + SQLite for progress on Android, iOS and
/// macOS. On web, Windows and Linux (where plain sqflite is unavailable)
/// SharedPreferences holds both.
DolphinStore defaultDolphinStore() {
  final prefs = SharedPreferencesDolphinStore();
  final sqliteSupported = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (!sqliteSupported) return prefs;
  return HybridDolphinStore(
    flags: prefs,
    progress: FallbackDolphinStore(
      primary: SqfliteDolphinStore(),
      fallback: SharedPreferencesDolphinStore(),
    ),
  );
}
