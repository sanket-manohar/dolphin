import 'package:flutter/widgets.dart';

/// Why a target could not be measured.
enum TargetProblem {
  notRegistered,
  notMounted,
  noRenderBox,
  notLaidOut,
  zeroSize,
  offscreen,
  error,
}

/// Result of measuring a target. Never throws.
class TargetMeasurement {
  const TargetMeasurement.ok(Rect this.rect) : problem = null;
  const TargetMeasurement.fail(TargetProblem this.problem) : rect = null;

  final Rect? rect;
  final TargetProblem? problem;
  bool get isOk => rect != null;
}

/// Safe RenderBox geometry. Every RenderBox access is guarded so a target
/// that is being rebuilt, disposed, or laid out never throws into the page.
class TargetGeometry {
  const TargetGeometry._();

  static TargetMeasurement measure(
    BuildContext? target,
    RenderBox? ancestor, {
    bool requireOnScreen = true,
  }) {
    try {
      if (target == null) {
        return const TargetMeasurement.fail(TargetProblem.notMounted);
      }
      if (target is Element && !target.mounted) {
        return const TargetMeasurement.fail(TargetProblem.notMounted);
      }
      final ro = target.findRenderObject();
      if (ro is! RenderBox) {
        return const TargetMeasurement.fail(TargetProblem.noRenderBox);
      }
      if (!ro.attached || !ro.hasSize) {
        return const TargetMeasurement.fail(TargetProblem.notLaidOut);
      }
      if (ancestor != null && (!ancestor.attached || !ancestor.hasSize)) {
        return const TargetMeasurement.fail(TargetProblem.notLaidOut);
      }
      final size = ro.size;
      if (size.isEmpty || !size.isFinite) {
        return const TargetMeasurement.fail(TargetProblem.zeroSize);
      }
      final transform = ro.getTransformTo(ancestor);
      final rect = MatrixUtils.transformRect(transform, Offset.zero & size);
      if (!rect.isFinite || rect.isEmpty) {
        return const TargetMeasurement.fail(TargetProblem.zeroSize);
      }
      if (requireOnScreen && ancestor != null) {
        final bounds = Offset.zero & ancestor.size;
        if (!rect.overlaps(bounds)) {
          return const TargetMeasurement.fail(TargetProblem.offscreen);
        }
      }
      return TargetMeasurement.ok(rect);
    } catch (_) {
      return const TargetMeasurement.fail(TargetProblem.error);
    }
  }

  /// True when the target is fully inside [ancestor]'s bounds.
  static bool isFullyVisible(Rect rect, Size bounds) =>
      (Offset.zero & bounds).inflate(0.5).contains(rect.topLeft) &&
      (Offset.zero & bounds).inflate(0.5).contains(rect.bottomRight);
}
