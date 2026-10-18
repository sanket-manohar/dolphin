import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'pointer_style.dart';
import 'dolphin_theme.dart';

enum TooltipSlot { tooltip, pointer }

/// Where the pointer ended up after layout. Painted by [PointerPainter].
@immutable
class PointerPlacement {
  const PointerPlacement(this.direction);

  /// Direction the pointer points to (towards the target).
  final AxisDirection direction;

  @override
  bool operator ==(Object other) =>
      other is PointerPlacement && other.direction == direction;
  @override
  int get hashCode => direction.hashCode;
}

double _finite(double v, double fallback) => v.isFinite ? v : fallback;

/// Places the tooltip next to the hole and aligns the pointer with the
/// target's centre in the same layout pass, using the tooltip's real size.
/// Nothing here is estimated, so the pointer stays aligned on every screen
/// size, and every value is clamped so bad input can never throw.
class TooltipLayoutDelegate extends MultiChildLayoutDelegate {
  TooltipLayoutDelegate({
    required this.hole,
    required this.position,
    required this.margin,
    required this.gap,
    required this.pointer,
    required this.maxWidth,
    required this.placement,
    this.pointerMode = PointerMode.auto,
    this.manualOffset,
    this.manualFraction,
    this.pinnedToEdge = false,
  });

  /// Bounds of the highlighted hole, or null for a centred tooltip.
  final Rect? hole;
  final TooltipPosition position;
  final EdgeInsets margin;
  final double gap;
  final PointerStyle pointer;
  final double maxWidth;
  final ValueNotifier<PointerPlacement?> placement;
  final PointerMode pointerMode;
  final double? manualOffset;
  final double? manualFraction;
  final bool pinnedToEdge;

  static const double _minSideWidth = 140;

  @override
  void performLayout(Size size) {
    final area = margin.deflateRect(Offset.zero & size);
    final safeArea =
        area.width > 0 && area.height > 0 ? area : Offset.zero & size;
    final drawPointer = pointer.kind != PointerKind.none && !pinnedToEdge;
    final extent = drawPointer ? pointer.extent : 0.0;
    final g = math.max(0.0, gap) + extent;
    final width = math.max(0.0, math.min(maxWidth, safeArea.width));

    Size layoutTooltip(double maxW) => layoutChild(
        TooltipSlot.tooltip,
        BoxConstraints(
          maxWidth: math.max(0.0, maxW),
          maxHeight: math.max(0.0, safeArea.height),
        ));

    void hidePointer() {
      layoutChild(TooltipSlot.pointer, BoxConstraints.tight(Size.zero));
      positionChild(TooltipSlot.pointer, Offset.zero);
      placement.value = null;
    }

    final h = hole;
    final validHole = h != null && h.isFinite && !h.isEmpty;

    // Banner: full width at the edge away from the target.
    if (pinnedToEdge) {
      final ts = layoutChild(
          TooltipSlot.tooltip,
          BoxConstraints(
              minWidth: safeArea.width,
              maxWidth: safeArea.width,
              maxHeight: safeArea.height));
      final atTop = validHole && h.center.dy > size.height / 2;
      positionChild(
          TooltipSlot.tooltip,
          Offset(safeArea.left,
              atTop ? safeArea.top : safeArea.bottom - ts.height));
      hidePointer();
      return;
    }

    if (!validHole || position == TooltipPosition.center) {
      final ts = layoutTooltip(width);
      positionChild(TooltipSlot.tooltip,
          safeArea.center - Offset(ts.width / 2, ts.height / 2));
      hidePointer();
      return;
    }

    final spaceAbove = h.top - safeArea.top - g;
    final spaceBelow = safeArea.bottom - h.bottom - g;
    final spaceLeft = h.left - safeArea.left - g;
    final spaceRight = safeArea.right - h.right - g;

    var side = position;
    if (side == TooltipPosition.left && spaceLeft < _minSideWidth) {
      side = TooltipPosition.auto;
    }
    if (side == TooltipPosition.right && spaceRight < _minSideWidth) {
      side = TooltipPosition.auto;
    }

    late Size ts;
    late Offset origin;
    if (side == TooltipPosition.left || side == TooltipPosition.right) {
      final avail = side == TooltipPosition.left ? spaceLeft : spaceRight;
      ts = layoutTooltip(math.min(width, avail));
      final left =
          side == TooltipPosition.left ? h.left - g - ts.width : h.right + g;
      final top = _clamp(h.center.dy - ts.height / 2, safeArea.top,
          safeArea.bottom - ts.height);
      origin = Offset(left, top);
    } else {
      ts = layoutTooltip(width);
      if (side == TooltipPosition.auto) {
        if (ts.height <= spaceBelow) {
          side = TooltipPosition.below;
        } else if (ts.height <= spaceAbove) {
          side = TooltipPosition.above;
        } else {
          side = spaceBelow >= spaceAbove
              ? TooltipPosition.below
              : TooltipPosition.above;
        }
      }
      final left = _clamp(
          h.center.dx - ts.width / 2, safeArea.left, safeArea.right - ts.width);
      var top =
          side == TooltipPosition.below ? h.bottom + g : h.top - g - ts.height;
      top = _clamp(top, safeArea.top, safeArea.bottom - ts.height);
      origin = Offset(left, top);
    }
    positionChild(TooltipSlot.tooltip, origin);

    if (!drawPointer) {
      hidePointer();
      return;
    }

    final vertical =
        side == TooltipPosition.above || side == TooltipPosition.below;
    final cross = pointer.crossExtent;
    final length = vertical ? ts.width : ts.height;

    // Position along the tooltip edge, relative to the tooltip's start.
    double? manual() {
      if (manualOffset != null && manualOffset!.isFinite) return manualOffset;
      if (manualFraction != null && manualFraction!.isFinite) {
        return manualFraction!.clamp(0.0, 1.0) * length;
      }
      return null;
    }

    double along;
    if (pointerMode == PointerMode.manual) {
      along = manual() ?? length / 2;
    } else {
      final measured =
          vertical ? h.center.dx - origin.dx : h.center.dy - origin.dy;
      along = measured.isFinite ? measured : (manual() ?? length / 2);
    }
    final halfArrow = cross / 2;
    final minA = pointer.edgeInset + halfArrow;
    final maxA = length - pointer.edgeInset - halfArrow;
    along = minA <= maxA ? _clamp(along, minA, maxA) : length / 2;

    final AxisDirection dir;
    late Offset pointerOrigin;
    late Size pointerSize;
    switch (side) {
      case TooltipPosition.below:
        dir = AxisDirection.up;
        pointerSize = Size(cross, extent);
        pointerOrigin =
            Offset(origin.dx + along - cross / 2, origin.dy - extent);
      case TooltipPosition.above:
        dir = AxisDirection.down;
        pointerSize = Size(cross, extent);
        pointerOrigin =
            Offset(origin.dx + along - cross / 2, origin.dy + ts.height);
      case TooltipPosition.right:
        dir = AxisDirection.left;
        pointerSize = Size(extent, cross);
        pointerOrigin =
            Offset(origin.dx - extent, origin.dy + along - cross / 2);
      default:
        dir = AxisDirection.right;
        pointerSize = Size(extent, cross);
        pointerOrigin =
            Offset(origin.dx + ts.width, origin.dy + along - cross / 2);
    }
    layoutChild(TooltipSlot.pointer, BoxConstraints.tight(pointerSize));
    positionChild(TooltipSlot.pointer,
        Offset(_finite(pointerOrigin.dx, 0), _finite(pointerOrigin.dy, 0)));
    placement.value = PointerPlacement(dir);
  }

  static double _clamp(double v, double lo, double hi) {
    if (!v.isFinite) return lo.isFinite ? lo : 0;
    if (hi < lo) return lo;
    return v.clamp(lo, hi);
  }

  @override
  bool shouldRelayout(TooltipLayoutDelegate old) =>
      old.hole != hole ||
      old.position != position ||
      old.margin != margin ||
      old.gap != gap ||
      old.pointer != pointer ||
      old.maxWidth != maxWidth ||
      old.pointerMode != pointerMode ||
      old.manualOffset != manualOffset ||
      old.manualFraction != manualFraction ||
      old.pinnedToEdge != pinnedToEdge;
}

/// Draws the arrow, the dots, or the line. The canvas box spans from the
/// tooltip edge to the target; "along" grows from the tooltip towards the
/// target.
class PointerPainter extends CustomPainter {
  PointerPainter({
    required this.placement,
    required this.style,
    required this.arrowColor,
    required this.dotColor,
  }) : super(repaint: placement);

  final ValueNotifier<PointerPlacement?> placement;
  final PointerStyle style;
  final Color arrowColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = placement.value;
    if (p == null || size.isEmpty) return;
    final vertical =
        p.direction == AxisDirection.up || p.direction == AxisDirection.down;
    final extent = vertical ? size.height : size.width;
    final crossSize = vertical ? size.width : size.height;
    final c = crossSize / 2;

    Offset map(double cross, double along) {
      switch (p.direction) {
        case AxisDirection.up:
          return Offset(cross, extent - along);
        case AxisDirection.down:
          return Offset(cross, along);
        case AxisDirection.left:
          return Offset(extent - along, cross);
        case AxisDirection.right:
          return Offset(along, cross);
      }
    }

    var along = 0.0;
    if (style.hasArrow) {
      final path = Path()
        ..moveTo(map(c - style.arrowWidth / 2, -0.5).dx,
            map(c - style.arrowWidth / 2, -0.5).dy)
        ..lineTo(map(c + style.arrowWidth / 2, -0.5).dx,
            map(c + style.arrowWidth / 2, -0.5).dy)
        ..lineTo(map(c, style.arrowHeight).dx, map(c, style.arrowHeight).dy)
        ..close();
      canvas.drawPath(path, Paint()..color = arrowColor);
      along += style.arrowHeight;
    }
    if (style.hasDots) {
      final paint = Paint();
      final colors = style.dotColors;
      along += style.dotSpacing;
      for (var i = 0; i < style.dotSizes.length; i++) {
        final r = style.dotSizes[i].clamp(0.0, 200.0) / 2;
        paint.color =
            colors != null && i < colors.length ? colors[i] : dotColor;
        _drawDot(canvas, map(c, along + r), r, paint);
        along += r * 2 + style.dotSpacing;
      }
    }
    if (style.kind == PointerKind.custom) {
      final draw = style.painter;
      if (draw != null) {
        canvas.save();
        try {
          draw(canvas, size, p.direction, style);
        } catch (_) {
          // A broken custom pointer must never break the page.
        }
        canvas.restore();
      }
    }
    if (style.kind == PointerKind.line) {
      canvas.drawLine(
        map(c, 0),
        map(c, math.min(style.lineLength, extent)),
        Paint()
          ..color = arrowColor
          ..strokeWidth = style.lineWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawDot(Canvas canvas, Offset center, double r, Paint paint) {
    switch (style.dotShape) {
      case DotShape.circle:
        canvas.drawCircle(center, r, paint);
      case DotShape.square:
        canvas.drawRect(Rect.fromCircle(center: center, radius: r), paint);
      case DotShape.roundedSquare:
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCircle(center: center, radius: r),
                Radius.circular(r * 0.45)),
            paint);
      case DotShape.diamond:
        canvas.drawPath(
            Path()
              ..moveTo(center.dx, center.dy - r)
              ..lineTo(center.dx + r, center.dy)
              ..lineTo(center.dx, center.dy + r)
              ..lineTo(center.dx - r, center.dy)
              ..close(),
            paint);
    }
  }

  @override
  bool shouldRepaint(PointerPainter old) =>
      old.style != style ||
      old.arrowColor != arrowColor ||
      old.dotColor != dotColor;
}
