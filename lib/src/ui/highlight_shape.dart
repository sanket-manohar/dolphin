import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/json_utils.dart';

/// The shape of the "hole" cut into the barrier around a target.
///
/// Built-in shapes cover the common cases; [HighlightShape.custom] and
/// [HighlightShape.border] let you use any [Path] or [ShapeBorder].
abstract class HighlightShape {
  const HighlightShape();

  /// A plain rectangle.
  const factory HighlightShape.rect() = RectHighlight;

  /// A rectangle with rounded corners.
  const factory HighlightShape.rounded({double radius}) = RoundedRectHighlight;

  /// A circle centred on the target. When [cover] is true the circle is
  /// big enough to contain the whole target (uses the diagonal).
  const factory HighlightShape.circle({bool cover}) = CircleHighlight;

  /// An ellipse that fits the padded target rectangle.
  const factory HighlightShape.oval() = OvalHighlight;

  /// A pill / stadium shape.
  const factory HighlightShape.stadium() = StadiumHighlight;

  /// A diamond (rhombus) touching the middle of each side of the padded
  /// target rect. Use `highlightPadding` to give the target room inside.
  const factory HighlightShape.diamond() = DiamondHighlight;

  /// Any shape described by a [ShapeBorder] (e.g. `BeveledRectangleBorder`).
  const factory HighlightShape.border(ShapeBorder shape) = ShapeBorderHighlight;

  /// Full control: build the path yourself from the padded target rect.
  const factory HighlightShape.custom(Path Function(Rect rect) builder) =
      CustomHighlight;

  /// Path of the hole for the given (already padded) target rect.
  Path getPath(Rect rect);

  /// Bounding box of the hole, used to place the tooltip.
  Rect getBounds(Rect rect) => getPath(rect).getBounds();

  /// Parses `"circle"`, `"rounded"`, `{"type": "rounded", "radius": 16}` ...
  /// Unknown values return `null` so the theme default is used instead.
  static HighlightShape? fromJson(Object? json) {
    if (json == null) return null;
    final m = WJson.map(json);
    final type = (m?['type'] ?? json).toString().toLowerCase();
    switch (type) {
      case 'rect':
      case 'rectangle':
        return const RectHighlight();
      case 'rounded':
      case 'roundedrect':
      case 'rrect':
        return RoundedRectHighlight(radius: WJson.dbl(m?['radius']) ?? 12);
      case 'circle':
        return CircleHighlight(cover: WJson.boolean(m?['cover']) ?? false);
      case 'oval':
      case 'ellipse':
        return const OvalHighlight();
      case 'stadium':
      case 'pill':
        return const StadiumHighlight();
      case 'diamond':
      case 'rhombus':
        return const DiamondHighlight();
      case 'beveled':
      case 'bevel':
        return ShapeBorderHighlight(BeveledRectangleBorder(
            borderRadius:
                BorderRadius.circular(WJson.dbl(m?['radius']) ?? 10)));
    }
    return null;
  }
}

class RectHighlight extends HighlightShape {
  const RectHighlight();
  @override
  Path getPath(Rect rect) => Path()..addRect(rect);
}

class RoundedRectHighlight extends HighlightShape {
  const RoundedRectHighlight({this.radius = 12});
  final double radius;
  @override
  Path getPath(Rect rect) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
}

class CircleHighlight extends HighlightShape {
  const CircleHighlight({this.cover = false});
  final bool cover;
  @override
  Path getPath(Rect rect) {
    final r = cover
        ? math.sqrt(rect.width * rect.width + rect.height * rect.height) / 2
        : math.max(rect.width, rect.height) / 2;
    return Path()..addOval(Rect.fromCircle(center: rect.center, radius: r));
  }
}

class OvalHighlight extends HighlightShape {
  const OvalHighlight();
  @override
  Path getPath(Rect rect) => Path()..addOval(rect);
}

class StadiumHighlight extends HighlightShape {
  const StadiumHighlight();
  @override
  Path getPath(Rect rect) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        rect, Radius.circular(math.min(rect.width, rect.height) / 2)));
}

class DiamondHighlight extends HighlightShape {
  const DiamondHighlight();
  @override
  Path getPath(Rect rect) => Path()
    ..moveTo(rect.center.dx, rect.top)
    ..lineTo(rect.right, rect.center.dy)
    ..lineTo(rect.center.dx, rect.bottom)
    ..lineTo(rect.left, rect.center.dy)
    ..close();
}

class ShapeBorderHighlight extends HighlightShape {
  const ShapeBorderHighlight(this.shape);
  final ShapeBorder shape;
  @override
  Path getPath(Rect rect) => shape.getOuterPath(rect);
}

class CustomHighlight extends HighlightShape {
  const CustomHighlight(this.builder);
  final Path Function(Rect rect) builder;
  @override
  Path getPath(Rect rect) {
    try {
      return builder(rect);
    } catch (_) {
      // A broken custom path must never break the page.
      return Path()..addRect(rect);
    }
  }
}
