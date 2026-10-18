import '../models/dolphin_progress.dart';
import 'dolphin_store.dart';

/// SQLite is not available on the web. This stand-in keeps the same name so
/// apps compile for every platform; [defaultDolphinStore] never uses it on
/// the web, and calling it throws [UnsupportedError].
class SqfliteDolphinStore extends DolphinStore {
  SqfliteDolphinStore(
      {this.databaseName = 'dolphin.db', Object? databaseFactory});

  final String databaseName;

  Never _unsupported() => throw UnsupportedError(
      'SqfliteDolphinStore is not available on the web.');

  @override
  Future<void> init() async => _unsupported();

  @override
  Future<DolphinProgress> loadProgress() async => _unsupported();

  @override
  Future<void> saveProgress(DolphinProgress p, ProgressDelta delta) async =>
      _unsupported();

  @override
  Future<void> clearProgress() async => _unsupported();

  @override
  Future<Map<String, Object?>> loadFlags() async => _unsupported();

  @override
  Future<void> setFlag(String key, Object? value) async => _unsupported();
}
