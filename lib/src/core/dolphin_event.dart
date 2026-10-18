import '../models/dolphin_progress.dart';
import 'target_geometry.dart';

enum DolphinEventType {
  scopeStarted,
  stepShown,
  stepCompleted,
  stepSkippedMissingTarget,
  scopeCompleted,
  scopeSkipped,
  dismissed,
  paused,
  resumed,
  journeyLegStarted,
  journeyCompleted,
  journeyStopped,
  reset,
  progressImported,
}

/// Analytics-friendly description of what just happened.
class DolphinEvent {
  const DolphinEvent(
    this.type, {
    this.scope,
    this.step,
    this.index,
    this.total,
    this.status,
    this.problem,
    this.journey,
    this.legIndex,
  });

  final DolphinEventType type;
  final String? scope;
  final String? step;
  final int? index;
  final int? total;
  final StepStatus? status;
  final TargetProblem? problem;
  final String? journey;
  final int? legIndex;

  @override
  String toString() => 'DolphinEvent(${type.name}'
      '${scope != null ? ', scope: $scope' : ''}'
      '${step != null ? ', step: $step' : ''}'
      '${index != null ? ', $index/$total' : ''}'
      '${problem != null ? ', problem: ${problem!.name}' : ''}'
      '${journey != null ? ', journey: $journey#$legIndex' : ''})';
}
