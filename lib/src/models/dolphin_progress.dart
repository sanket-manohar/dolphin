import 'package:flutter/foundation.dart';

import '../core/json_utils.dart';

enum StepStatus { unseen, seen, skipped }

/// Status of a whole scope (page).
enum ScopeStatus { notStarted, inProgress, completed }

/// How remote progress is combined with local progress.
enum MergeStrategy {
  /// A step seen on either side counts as seen; newest record wins on ties.
  /// Resets made after a record was written are respected.
  union,

  /// Remote data replaces local data completely.
  remoteWins,

  /// Local data is kept; remote only fills in records that are missing.
  localWins,
}

String stepKey(String scope, String step) => '$scope/$step';

@immutable
class StepRecord {
  const StepRecord({
    required this.scope,
    required this.step,
    required this.status,
    required this.updatedAt,
    this.version = 0,
  });

  final String scope;
  final String step;
  final StepStatus status;
  final DateTime updatedAt;

  /// Content version the user saw.
  final int version;

  String get key => stepKey(scope, step);
  bool get isDone => status != StepStatus.unseen;

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'step': step,
        'status': status.name,
        'version': version,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static StepRecord? fromJson(Object? json) {
    final m = WJson.map(json);
    if (m == null || m['scope'] == null || m['step'] == null) return null;
    return StepRecord(
      scope: m['scope'].toString(),
      step: m['step'].toString(),
      status:
          WJson.enumByName(StepStatus.values, m['status']) ?? StepStatus.seen,
      version: WJson.integer(m['version']) ?? 0,
      updatedAt: WJson.date(m['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

@immutable
class ScopeRecord {
  const ScopeRecord({
    required this.scope,
    this.knownSteps = const [],
    this.lastStepId,
    this.updatedAt,
    this.completedAt,
    this.resetAt,
  });

  final String scope;

  /// Step ids last seen for this scope, so status can be reported for pages
  /// the user has not opened in this session.
  final List<String> knownSteps;
  final String? lastStepId;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  /// Step records written before this moment are ignored when merging.
  final DateTime? resetAt;

  ScopeRecord copyWith({
    List<String>? knownSteps,
    String? lastStepId,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompleted = false,
    DateTime? resetAt,
  }) =>
      ScopeRecord(
        scope: scope,
        knownSteps: knownSteps ?? this.knownSteps,
        lastStepId: lastStepId ?? this.lastStepId,
        updatedAt: updatedAt ?? this.updatedAt,
        completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
        resetAt: resetAt ?? this.resetAt,
      );

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'knownSteps': knownSteps,
        if (lastStepId != null) 'lastStepId': lastStepId,
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        if (completedAt != null)
          'completedAt': completedAt!.toUtc().toIso8601String(),
        if (resetAt != null) 'resetAt': resetAt!.toUtc().toIso8601String(),
      };

  static ScopeRecord? fromJson(Object? json) {
    final m = WJson.map(json);
    if (m == null || m['scope'] == null) return null;
    return ScopeRecord(
      scope: m['scope'].toString(),
      knownSteps: WJson.strList(m['knownSteps']) ?? const [],
      lastStepId: WJson.str(m['lastStepId']),
      updatedAt: WJson.date(m['updatedAt']),
      completedAt: WJson.date(m['completedAt']),
      resetAt: WJson.date(m['resetAt']),
    );
  }

  static DateTime? _latest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  ScopeRecord mergeWith(ScopeRecord other) {
    final newer =
        (other.updatedAt ?? DateTime(0)).isAfter(updatedAt ?? DateTime(0))
            ? other
            : this;
    return ScopeRecord(
      scope: scope,
      knownSteps: {...knownSteps, ...other.knownSteps}.toList(),
      lastStepId: newer.lastStepId ?? lastStepId ?? other.lastStepId,
      updatedAt: _latest(updatedAt, other.updatedAt),
      completedAt: _latest(completedAt, other.completedAt),
      resetAt: _latest(resetAt, other.resetAt),
    );
  }
}

@immutable
class JourneyRecord {
  const JourneyRecord({
    required this.id,
    required this.legIndex,
    this.completed = false,
    this.active = false,
    required this.updatedAt,
  });

  final String id;
  final int legIndex;
  final bool completed;

  /// True while the journey is running (survives app restarts).
  final bool active;
  final DateTime updatedAt;

  JourneyRecord copyWith({int? legIndex, bool? completed, bool? active}) =>
      JourneyRecord(
        id: id,
        legIndex: legIndex ?? this.legIndex,
        completed: completed ?? this.completed,
        active: active ?? this.active,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'legIndex': legIndex,
        'completed': completed,
        'active': active,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static JourneyRecord? fromJson(Object? json) {
    final m = WJson.map(json);
    if (m == null || m['id'] == null) return null;
    return JourneyRecord(
      id: m['id'].toString(),
      legIndex: WJson.integer(m['legIndex']) ?? 0,
      completed: WJson.boolean(m['completed']) ?? false,
      active: WJson.boolean(m['active']) ?? false,
      updatedAt: WJson.date(m['updatedAt']) ?? DateTime.now().toUtc(),
    );
  }
}

/// Everything the user has seen. Immutable snapshot: serialise it with
/// [toJson] to save it in your own DB or send it to your server, and give it
/// back with `controller.importProgress`.
@immutable
class DolphinProgress {
  const DolphinProgress({
    this.steps = const {},
    this.scopes = const {},
    this.journeys = const {},
    this.resetAt,
    this.updatedAt,
  });

  static const schemaVersion = 1;
  static const empty = DolphinProgress();

  /// Keyed by `scope/step`.
  final Map<String, StepRecord> steps;
  final Map<String, ScopeRecord> scopes;
  final Map<String, JourneyRecord> journeys;

  /// Global reset marker: anything older is ignored when merging.
  final DateTime? resetAt;
  final DateTime? updatedAt;

  bool get isEmpty => steps.isEmpty && scopes.isEmpty && journeys.isEmpty;

  StepRecord? step(String scope, String step) => steps[stepKey(scope, step)];

  bool isSeen(String scope, String step, {int version = 0}) {
    final r = this.step(scope, step);
    return r != null && r.isDone && r.version >= version;
  }

  /// Seen step ids of a scope.
  List<String> seenSteps(String scope) => [
        for (final r in steps.values)
          if (r.scope == scope && r.isDone) r.step
      ];

  /// Status of a scope. Pass [stepIds] when you know the exact list;
  /// otherwise the last known list is used.
  ScopeStatus scopeStatus(String scope, {Iterable<String>? stepIds}) {
    final ids = stepIds?.toList() ?? scopes[scope]?.knownSteps ?? const [];
    final seen = seenSteps(scope).toSet();
    if (ids.isEmpty) {
      if (scopes[scope]?.completedAt != null) return ScopeStatus.completed;
      return seen.isEmpty ? ScopeStatus.notStarted : ScopeStatus.inProgress;
    }
    final done = ids.where(seen.contains).length;
    if (done == 0) return ScopeStatus.notStarted;
    if (done >= ids.length) return ScopeStatus.completed;
    return ScopeStatus.inProgress;
  }

  DolphinProgress copyWith({
    Map<String, StepRecord>? steps,
    Map<String, ScopeRecord>? scopes,
    Map<String, JourneyRecord>? journeys,
    DateTime? resetAt,
    DateTime? updatedAt,
  }) =>
      DolphinProgress(
        steps: steps ?? this.steps,
        scopes: scopes ?? this.scopes,
        journeys: journeys ?? this.journeys,
        resetAt: resetAt ?? this.resetAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        if (resetAt != null) 'resetAt': resetAt!.toUtc().toIso8601String(),
        if (updatedAt != null)
          'updatedAt': updatedAt!.toUtc().toIso8601String(),
        'steps': [for (final s in steps.values) s.toJson()],
        'scopes': [for (final s in scopes.values) s.toJson()],
        'journeys': [for (final j in journeys.values) j.toJson()],
      };

  /// Tolerant parser: bad entries are dropped instead of throwing.
  factory DolphinProgress.fromJson(Map<String, dynamic> json) {
    final steps = <String, StepRecord>{};
    final scopes = <String, ScopeRecord>{};
    final journeys = <String, JourneyRecord>{};
    Iterable<Object?> list(Object? v) =>
        v is List ? v : (v is Map ? v.values : const []);
    for (final s in list(json['steps'])) {
      final r = StepRecord.fromJson(s);
      if (r != null) steps[r.key] = r;
    }
    for (final s in list(json['scopes'])) {
      final r = ScopeRecord.fromJson(s);
      if (r != null) scopes[r.scope] = r;
    }
    for (final s in list(json['journeys'])) {
      final r = JourneyRecord.fromJson(s);
      if (r != null) journeys[r.id] = r;
    }
    return DolphinProgress(
      steps: steps,
      scopes: scopes,
      journeys: journeys,
      resetAt: WJson.date(json['resetAt']),
      updatedAt: WJson.date(json['updatedAt']),
    );
  }

  /// Combines this (local) progress with [remote].
  DolphinProgress merge(DolphinProgress remote,
      {MergeStrategy strategy = MergeStrategy.union}) {
    switch (strategy) {
      case MergeStrategy.remoteWins:
        return remote;
      case MergeStrategy.localWins:
        return DolphinProgress(
          steps: {...remote.steps, ...steps},
          scopes: {...remote.scopes, ...scopes},
          journeys: {...remote.journeys, ...journeys},
          resetAt: resetAt ?? remote.resetAt,
          updatedAt: DateTime.now().toUtc(),
        );
      case MergeStrategy.union:
        break;
    }

    final globalReset = ScopeRecord._latest(resetAt, remote.resetAt);
    final scopesOut = <String, ScopeRecord>{...scopes};
    remote.scopes.forEach((k, v) {
      scopesOut[k] = scopesOut[k]?.mergeWith(v) ?? v;
    });

    bool alive(StepRecord r) {
      final scopeReset = scopesOut[r.scope]?.resetAt;
      final cut = ScopeRecord._latest(globalReset, scopeReset);
      return cut == null || r.updatedAt.isAfter(cut);
    }

    final stepsOut = <String, StepRecord>{};
    for (final r in [...steps.values, ...remote.steps.values]) {
      if (!alive(r)) continue;
      final existing = stepsOut[r.key];
      if (existing == null) {
        stepsOut[r.key] = r;
      } else if (r.isDone != existing.isDone) {
        if (r.isDone) stepsOut[r.key] = r;
      } else if (r.version > existing.version ||
          r.updatedAt.isAfter(existing.updatedAt)) {
        stepsOut[r.key] = r;
      }
    }

    // A completion older than a reset no longer counts.
    scopesOut.updateAll((k, v) {
      final cut = ScopeRecord._latest(globalReset, v.resetAt);
      if (v.completedAt != null &&
          cut != null &&
          !v.completedAt!.isAfter(cut)) {
        return v.copyWith(clearCompleted: true);
      }
      return v;
    });

    final journeysOut = <String, JourneyRecord>{...journeys};
    remote.journeys.forEach((k, v) {
      final l = journeysOut[k];
      if (l == null ||
          (v.completed && !l.completed) ||
          (v.completed == l.completed && v.legIndex > l.legIndex)) {
        journeysOut[k] = v;
      }
    });

    return DolphinProgress(
      steps: stepsOut,
      scopes: scopesOut,
      journeys: journeysOut,
      resetAt: globalReset,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}
