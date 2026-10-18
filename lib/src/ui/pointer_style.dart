import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/json_utils.dart';

enum PointerKind { none, arrow, dots, arrowAndDots, line, custom }

/// Shape of each dot.
enum DotShape { circle, square, roundedSquare, diamond }

/// Draws a fully custom pointer.
///
/// [size] is the box between the tooltip edge and the target. [direction] is
/// the way the pointer must point (towards the target): `up` means the
/// tooltip is below and the target above. Draw from the tooltip edge, which
/// is the bottom of the box for `up`, the top for `down`, the right for
/// `left` and the left for `right`.
typedef PointerPaintCallback = void Function(
    Canvas canvas, Size size, AxisDirection direction, PointerStyle style);

/// How the tooltip points at its target.
///
/// The default is an arrow followed by three dots travelling towards the
/// target. Every dot size is configurable through [dotSizes]; the first value
/// is the dot closest to the tooltip.
@immutable
class PointerStyle {
  const PointerStyle({
    this.kind = PointerKind.arrowAndDots,
    this.arrowWidth = 18,
    this.arrowHeight = 9,
    this.dotSizes = const [8, 6, 4],
    this.dotSpacing = 5,
    this.color,
    this.dotColor,
    this.lineWidth = 2,
    this.lineLength = 24,
    this.edgeInset = 18,
    this.dotColors,
    this.dotShape = DotShape.circle,
    this.painter,
    this.customLength = 24,
    this.customWidth = 18,
  });

  const PointerStyle.none() : this(kind: PointerKind.none);

  const PointerStyle.arrow({double width = 18, double height = 9, Color? color})
      : this(
            kind: PointerKind.arrow,
            arrowWidth: width,
            arrowHeight: height,
            color: color);

  /// Only dots. [sizes] decides how many dots there are and how big each is.
  const PointerStyle.dots({
    List<double> sizes = const [8, 6, 4],
    double spacing = 5,
    Color? color,
  }) : this(
            kind: PointerKind.dots,
            dotSizes: sizes,
            dotSpacing: spacing,
            dotColor: color);

  const PointerStyle.arrowAndDots({
    List<double> sizes = const [8, 6, 4],
    double spacing = 5,
    Color? arrowColor,
    Color? dotColor,
  }) : this(
            kind: PointerKind.arrowAndDots,
            dotSizes: sizes,
            dotSpacing: spacing,
            color: arrowColor,
            dotColor: dotColor);

  const PointerStyle.line({double width = 2, double length = 24, Color? color})
      : this(
            kind: PointerKind.line,
            lineWidth: width,
            lineLength: length,
            color: color);

  /// Draw the pointer yourself. [length] is the space it takes between the
  /// tooltip and the target, [width] its size across.
  const PointerStyle.custom({
    required PointerPaintCallback painter,
    double length = 24,
    double width = 18,
    Color? color,
  }) : this(
            kind: PointerKind.custom,
            painter: painter,
            customLength: length,
            customWidth: width,
            color: color);

  final PointerKind kind;
  final double arrowWidth;
  final double arrowHeight;

  /// One entry per dot, nearest-to-tooltip first. `[8, 6, 4]` = 3 dots.
  final List<double> dotSizes;
  final double dotSpacing;

  /// Arrow / line colour. Defaults to the tooltip background.
  final Color? color;

  /// Dot colour. Defaults to [color], then the tooltip background.
  final Color? dotColor;
  final double lineWidth;
  final double lineLength;

  /// Minimum distance between the arrow and the tooltip's rounded corners.
  final double edgeInset;

  /// One colour per dot, nearest-to-tooltip first. Missing entries use
  /// [dotColor].
  final List<Color>? dotColors;
  final DotShape dotShape;

  /// Used when [kind] is [PointerKind.custom].
  final PointerPaintCallback? painter;
  final double customLength;
  final double customWidth;

  bool get hasArrow =>
      kind == PointerKind.arrow || kind == PointerKind.arrowAndDots;
  bool get hasDots =>
      (kind == PointerKind.dots || kind == PointerKind.arrowAndDots) &&
      dotSizes.isNotEmpty;

  /// Space this pointer needs between the tooltip and the target.
  double get extent {
    var e = 0.0;
    if (hasArrow) e += arrowHeight;
    if (hasDots) {
      for (final s in dotSizes) {
        e += s.clamp(0, 200) + dotSpacing;
      }
      e += dotSpacing;
    }
    if (kind == PointerKind.line) e += lineLength;
    if (kind == PointerKind.custom) e += customLength;
    return e;
  }

  /// Size across the pointer, used to keep it clear of rounded corners.
  double get crossExtent {
    var c = hasArrow ? arrowWidth : 0.0;
    if (hasDots) {
      for (final s in dotSizes) {
        if (s > c) c = s;
      }
    } else if (kind == PointerKind.line && lineWidth > c) {
      c = lineWidth;
    }
    if (kind == PointerKind.custom && customWidth > c) c = customWidth;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      other is PointerStyle &&
      other.kind == kind &&
      other.arrowWidth == arrowWidth &&
      other.arrowHeight == arrowHeight &&
      listEquals(other.dotSizes, dotSizes) &&
      other.dotSpacing == dotSpacing &&
      other.color == color &&
      other.dotColor == dotColor &&
      other.lineWidth == lineWidth &&
      other.lineLength == lineLength &&
      other.edgeInset == edgeInset &&
      listEquals(other.dotColors, dotColors) &&
      other.dotShape == dotShape &&
      other.painter == painter &&
      other.customLength == customLength &&
      other.customWidth == customWidth;

  @override
  int get hashCode => Object.hash(
      kind,
      arrowWidth,
      arrowHeight,
      Object.hashAll(dotSizes),
      dotSpacing,
      color,
      dotColor,
      lineWidth,
      lineLength,
      edgeInset,
      dotColors == null ? null : Object.hashAll(dotColors!),
      dotShape,
      painter,
      customLength,
      customWidth);

  PointerStyle copyWith({
    PointerKind? kind,
    double? arrowWidth,
    double? arrowHeight,
    List<double>? dotSizes,
    double? dotSpacing,
    Color? color,
    Color? dotColor,
    double? lineWidth,
    double? lineLength,
    double? edgeInset,
    List<Color>? dotColors,
    DotShape? dotShape,
    PointerPaintCallback? painter,
    double? customLength,
    double? customWidth,
  }) =>
      PointerStyle(
        kind: kind ?? this.kind,
        arrowWidth: arrowWidth ?? this.arrowWidth,
        arrowHeight: arrowHeight ?? this.arrowHeight,
        dotSizes: dotSizes ?? this.dotSizes,
        dotSpacing: dotSpacing ?? this.dotSpacing,
        color: color ?? this.color,
        dotColor: dotColor ?? this.dotColor,
        lineWidth: lineWidth ?? this.lineWidth,
        lineLength: lineLength ?? this.lineLength,
        edgeInset: edgeInset ?? this.edgeInset,
        dotColors: dotColors ?? this.dotColors,
        dotShape: dotShape ?? this.dotShape,
        painter: painter ?? this.painter,
        customLength: customLength ?? this.customLength,
        customWidth: customWidth ?? this.customWidth,
      );

  static PointerStyle? fromJson(Object? json) {
    if (json == null) return null;
    final m = WJson.map(json) ?? {'kind': json};
    final kind = WJson.enumByName(PointerKind.values, m['kind'] ?? m['type']);
    const d = PointerStyle();
    return PointerStyle(
      kind: kind ?? d.kind,
      arrowWidth: WJson.dbl(m['arrowWidth']) ?? d.arrowWidth,
      arrowHeight: WJson.dbl(m['arrowHeight']) ?? d.arrowHeight,
      dotSizes: WJson.dblList(m['dotSizes']) ?? d.dotSizes,
      dotSpacing: WJson.dbl(m['dotSpacing']) ?? d.dotSpacing,
      color: WJson.color(m['color']),
      dotColor: WJson.color(m['dotColor']),
      lineWidth: WJson.dbl(m['lineWidth']) ?? d.lineWidth,
      lineLength: WJson.dbl(m['lineLength']) ?? d.lineLength,
      edgeInset: WJson.dbl(m['edgeInset']) ?? d.edgeInset,
      dotColors: m['dotColors'] is List
          ? [for (final c in m['dotColors'] as List) WJson.color(c)]
              .whereType<Color>()
              .toList()
          : null,
      dotShape: WJson.enumByName(DotShape.values, m['dotShape']) ?? d.dotShape,
    );
  }
}
