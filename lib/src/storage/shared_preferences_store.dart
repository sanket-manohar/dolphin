import 'package:shared_preferences/shared_preferences.dart';

import '../models/dolphin_progress.dart';
import 'dolphin_store.dart';

/// Stores flags as individual preferences and progress as one JSON string.
/// Works on every platform, including web and desktop.
class SharedPreferencesDolphinStore extends DolphinStore {
  SharedPreferencesDolphinStore({this.prefix = 'dolphin.'});

  final String prefix;
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  String get _progressKey => '${prefix}progress';
  String get _flagPrefix => '${prefix}flag.';

  @override
  Future<void> init() async => _p;

  @override
  Future<DolphinProgress> loadProgress() async =>
      decodeProgress((await _p).getString(_progressKey));

  @override
  Future<void> saveProgress(
      DolphinProgress progress, ProgressDelta delta) async {
    await (await _p).setString(_progressKey, encodeProgress(progress));
  }

  @override
  Future<void> clearProgress() async => (await _p).remove(_progressKey);

  @override
  Future<Map<String, Object?>> loadFlags() async {
    final p = await _p;
    return {
      for (final k in p.getKeys())
        if (k.startsWith(_flagPrefix))
          k.substring(_flagPrefix.length): p.get(k),
    };
  }

  @override
  Future<void> setFlag(String key, Object? value) async {
    final p = await _p;
    final k = '$_flagPrefix$key';
    if (value == null) {
      await p.remove(k);
    } else if (value is bool) {
      await p.setBool(k, value);
    } else if (value is int) {
      await p.setInt(k, value);
    } else if (value is double) {
      await p.setDouble(k, value);
    } else if (value is List<String>) {
      await p.setStringList(k, value);
    } else {
      await p.setString(k, value.toString());
    }
  }
}
