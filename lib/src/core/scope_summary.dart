import '../models/dolphin_progress.dart';

/// Read-only report of one scope (page): what is seen and what is pending.
class ScopeSummary {
  const ScopeSummary({
    required this.scope,
    required this.status,
    required this.stepIds,
    required this.seen,
    required this.pending,
    this.completedAt,
  });

  final String scope;
  final ScopeStatus status;

  /// Ordered steps that apply to this scope (after sequence / exclude).
  final List<String> stepIds;
  final List<String> seen;
  final List<String> pending;
  final DateTime? completedAt;

  int get total => stepIds.length;
  double get fraction => total == 0 ? 0 : seen.length / total;

  Map<String, dynamic> toJson() => {
        'scope': scope,
        'status': status.name,
        'steps': stepIds,
        'seen': seen,
        'pending': pending,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  @override
  String toString() =>
      'ScopeSummary($scope, ${status.name}, ${seen.length}/$total)';
}
