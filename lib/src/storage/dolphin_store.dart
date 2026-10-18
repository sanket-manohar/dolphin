import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/dolphin_progress.dart';

/// What changed since the last save. Stores that write row by row (SQL) use
/// it to avoid rewriting everything; key-value stores can ignore it.
class ProgressDelta {
  ProgressDelta({
    Set<String>? steps,
    Set<String>? scopes,
    Set<String>? journeys,
    this.full = false,
  })  : steps = steps ?? {},
        scopes = scopes ?? {},
        journeys = journeys ?? {};

  ProgressDelta.full() : this(full: true);

  /// Keys whose record was written or deleted (look them up in the snapshot:
  /// missing means deleted).
  final Set<String> steps;
  final Set<String> scopes;
  final Set<String> journeys;

  /// Replace everything.
  bool full;

  bool get isEmpty =>
      !full && steps.isEmpty && scopes.isEmpty && journeys.isEmpty;

  void addAll(ProgressDelta other) {
    steps.addAll(other.steps);
    scopes.addAll(other.scopes);
    journeys.addAll(other.journeys);
    full = full || other.full;
  }
}

/// Persistence for walkthrough state. Small flags (enabled, disabled pages)
/// and the progress snapshot are stored separately so they can live in
/// different backends (see [HybridDolphinStore]).
///
/// Implement this to keep progress in your own database, cloud storage,
/// or a REST API. Every method may throw; the controller catches and
/// reports errors through `onError` and keeps working from memory.
abstract class DolphinStore {
  const DolphinStore();

  Future<void> init() async {}

  Future<DolphinProgress> loadProgress();
  Future<void> saveProgress(DolphinProgress progress, ProgressDelta delta);
  Future<void> clearProgress();

  /// Values are `bool`, `int`, `double`, `String` or `List<String>`.
  Future<Map<String, Object?>> loadFlags();
  Future<void> setFlag(String key, Object? value);

  Future<void> dispose() async {}
}

/// Keeps everything in memory. Handy for tests and for apps that persist
/// progress only through their own server.
class MemoryDolphinStore extends DolphinStore {
  MemoryDolphinStore({DolphinProgress? initial, Map<String, Object?>? flags})
      : _progress = initial ?? DolphinProgress.empty,
        _flags = {...?flags};

  DolphinProgress _progress;
  final Map<String, Object?> _flags;
  int saveCount = 0;

  DolphinProgress get progress => _progress;

  @override
  Future<DolphinProgress> loadProgress() async => _progress;

  @override
  Future<void> saveProgress(
      DolphinProgress progress, ProgressDelta delta) async {
    saveCount++;
    _progress = progress;
  }

  @override
  Future<void> clearProgress() async => _progress = DolphinProgress.empty;

  @override
  Future<Map<String, Object?>> loadFlags() async => Map.of(_flags);

  @override
  Future<void> setFlag(String key, Object? value) async {
    if (value == null) {
      _flags.remove(key);
    } else {
      _flags[key] = value;
    }
  }
}

/// Uses one store for flags and another for progress. The default is
/// SharedPreferences for flags and SQLite for progress.
class HybridDolphinStore extends DolphinStore {
  const HybridDolphinStore({required this.flags, required this.progress});

  final DolphinStore flags;
  final DolphinStore progress;

  @override
  Future<void> init() async {
    await flags.init();
    if (!identical(flags, progress)) await progress.init();
  }

  @override
  Future<DolphinProgress> loadProgress() => progress.loadProgress();

  @override
  Future<void> saveProgress(DolphinProgress p, ProgressDelta delta) =>
      progress.saveProgress(p, delta);

  @override
  Future<void> clearProgress() => progress.clearProgress();

  @override
  Future<Map<String, Object?>> loadFlags() => flags.loadFlags();

  @override
  Future<void> setFlag(String key, Object? value) => flags.setFlag(key, value);

  @override
  Future<void> dispose() async {
    await flags.dispose();
    if (!identical(flags, progress)) await progress.dispose();
  }
}

/// Encodes a progress snapshot for key-value stores.
String encodeProgress(DolphinProgress p) => jsonEncode(p.toJson());

DolphinProgress decodeProgress(String? raw) {
  if (raw == null || raw.isEmpty) return DolphinProgress.empty;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return DolphinProgress.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (e) {
    debugPrint('dolphin: stored progress unreadable, starting fresh ($e)');
  }
  return DolphinProgress.empty;
}

/// Uses [primary]; if it fails to initialise (e.g. SQLite unavailable),
/// transparently switches to [fallback] for the rest of the session.
class FallbackDolphinStore extends DolphinStore {
  FallbackDolphinStore({required this.primary, required this.fallback});

  final DolphinStore primary;
  final DolphinStore fallback;
  late DolphinStore _active = primary;

  DolphinStore get active => _active;

  @override
  Future<void> init() async {
    try {
      await primary.init();
    } catch (e) {
      debugPrint('dolphin: primary store failed ($e), using fallback');
      _active = fallback;
      await fallback.init();
    }
  }

  @override
  Future<DolphinProgress> loadProgress() => _active.loadProgress();
  @override
  Future<void> saveProgress(DolphinProgress p, ProgressDelta d) =>
      _active.saveProgress(p, d);
  @override
  Future<void> clearProgress() => _active.clearProgress();
  @override
  Future<Map<String, Object?>> loadFlags() => _active.loadFlags();
  @override
  Future<void> setFlag(String key, Object? value) =>
      _active.setFlag(key, value);
  @override
  Future<void> dispose() => _active.dispose();
}
