import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../core/target_geometry.dart';
import '../core/dolphin_controller.dart';
import '../models/dolphin_step.dart';
import 'highlight_shape.dart';
import 'pointer_style.dart';
import 'tooltip_layout.dart';
import 'tooltip_presets.dart';
import 'dolphin_theme.dart';

/// The barrier, highlight and tooltip. Inserted into the root [Overlay] by
/// the controller; you never build it yourself.
class DolphinOverlay extends StatefulWidget {
  const DolphinOverlay({super.key, required this.controller});
  final DolphinController controller;

  @override
  State<DolphinOverlay> createState() => _DolphinOverlayState();
}

class _DolphinOverlayState extends State<DolphinOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fade = AnimationController(vsync: this);
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _enter = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(vsync: this);
  final ValueNotifier<PointerPlacement?> _placement = ValueNotifier(null);

  ActiveStep? _step;
  int? _serial;
  Rect? _from;
  Rect? _to;
  Timer? _lostTimer;
  bool _tracking = false;

  DolphinController get _c => widget.controller;

  static bool _close(Rect a, Rect b) =>
      (a.left - b.left).abs() < 0.05 &&
      (a.top - b.top).abs() < 0.05 &&
      (a.right - b.right).abs() < 0.05 &&
      (a.bottom - b.bottom).abs() < 0.05;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.addListener(_sync);
    _move.addListener(_rebuild);
    _sync();
    _startTracking();
  }

  @override
  void didUpdateWidget(DolphinOverlay old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_sync);
    _lostTimer?.cancel();
    _tracking = false;
    _fade.dispose();
    _move.dispose();
    _enter.dispose();
    _pulse.dispose();
    _placement.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Future<bool> didPopRoute() async =>
      mounted && _c.isShowing && _c.handleBack();

  void _sync() {
    if (!mounted) return;
    final a = _c.activeStep;
    if (a == null) {
      if (_step == null) return;
      _lostTimer?.cancel();
      _fade.reverse().whenCompleteOrCancel(() {
        if (mounted && _c.activeStep == null) _c.overlayHidden();
      });
      return;
    }
    if (a.serial == _serial) return;
    final anim = a.theme.animation ?? const DolphinAnimation();
    _fade.duration = anim.effectiveFade;
    _move.duration = anim.effectiveMove;
    _enter.duration = anim.enabled ? anim.fadeDuration : Duration.zero;
    _serial = a.serial;
    final previousRect = _currentRect;
    _step = a;
    final rect = _measure(a);
    if (rect != null &&
        previousRect != null &&
        anim.enabled &&
        _fade.value > 0) {
      _from = previousRect;
      _to = rect;
      _move.forward(from: 0);
    } else {
      _from = null;
      _to = rect;
      _move.value = 1;
    }
    _enter.forward(from: 0);
    if (rect != null || a.centered) _fade.forward();
    if (anim.enabled && anim.pulse) {
      _pulse.duration = anim.pulseDuration;
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
    _rebuild();
  }

  Rect? get _currentRect {
    if (_to == null) return null;
    if (_from == null || !_move.isAnimating) return _to;
    final a = _step?.theme.animation ?? const DolphinAnimation();
    return Rect.lerp(_from, _to, a.curve.transform(_move.value));
  }

  RenderBox? get _box {
    final ro = context.findRenderObject();
    return ro is RenderBox && ro.attached && ro.hasSize ? ro : null;
  }

  Rect? _measure(ActiveStep a) {
    if (a.centered) return null;
    final box = _box;
    final key = a.targetKey;
    if (key != null) {
      final m = TargetGeometry.measure(key.currentContext, box,
          requireOnScreen: false);
      if (m.isOk) return m.rect;
    }
    final f = a.fallbackRect ?? a.step.fallbackRect;
    if (f != null) {
      final size = box?.size ?? MediaQuery.maybeSizeOf(context);
      if (size != null) return f.resolve(size);
    }
    return null;
  }

  /// Re-measures after every frame so the highlight follows scrolling,
  /// keyboard, rotation and animations. Costs nothing while idle because it
  /// never schedules frames itself.
  void _startTracking() {
    if (_tracking) return;
    _tracking = true;
    void tick(Duration _) {
      if (!mounted || !_tracking) return;
      _onFrame();
      SchedulerBinding.instance.addPostFrameCallback(tick);
    }

    SchedulerBinding.instance.addPostFrameCallback(tick);
  }

  void _onFrame() {
    final a = _step;
    if (a == null ||
        _c.activeStep == null ||
        a.serial != _c.activeStep!.serial) {
      return;
    }
    if (a.centered) {
      if (_fade.status == AnimationStatus.dismissed) _fade.forward();
      return;
    }
    final rect = _measure(a);
    if (rect == null) {
      _lostTimer ??= Timer(const Duration(milliseconds: 300), () {
        _lostTimer = null;
        if (!mounted) return;
        final again = _step == null ? null : _measure(_step!);
        if (again == null && _step != null) {
          _c.targetLost(_step!.serial);
        } else if (again != null) {
          _to = again;
          _rebuild();
        }
      });
      return;
    }
    _lostTimer?.cancel();
    _lostTimer = null;
    if (_fade.status == AnimationStatus.dismissed ||
        _fade.status == AnimationStatus.reverse) {
      _fade.forward();
    }
    // Ignore sub-pixel jitter so a still target costs no rebuilds.
    final old = _to;
    if (old == null || !_close(old, rect)) {
      _to = rect;
      _rebuild();
    }
  }

  bool _isDark(BuildContext context) {
    switch (_c.themeMode) {
      case DolphinThemeMode.light:
        return false;
      case DolphinThemeMode.dark:
        return true;
      case DolphinThemeMode.system:
        return MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;
      case DolphinThemeMode.app:
        return Theme.of(context).brightness == Brightness.dark;
    }
  }

  DolphinTooltipContext _tooltipContext(ActiveStep a, DolphinTheme t) =>
      DolphinTooltipContext(
        step: a.step,
        scopeId: a.scope,
        index: a.index,
        total: a.total,
        counterText: a.counterText,
        theme: t,
        isFirst: a.isFirst,
        isLast: a.isLast,
        next: _c.next,
        previous: _c.previous,
        skipScope: _c.skipScope,
        dismiss: _c.dismiss,
      );

  @override
  Widget build(BuildContext context) {
    final a = _step;
    if (a == null) return const SizedBox.shrink();
    final t = a.themeFor(isDark: _isDark(context));
    final rect = _currentRect;
    var hole = rect == null
        ? null
        : (t.highlightPadding ?? EdgeInsets.zero).inflateRect(rect);
    final nudge = t.highlightOffset;
    if (hole != null && nudge != null && nudge.isFinite) {
      hole = hole.shift(nudge);
    }
    final shape = t.shape ?? const HighlightShape.rounded();
    Path? holePath;
    if (hole != null) {
      try {
        holePath = shape.getPath(hole);
      } catch (_) {
        holePath = Path()..addRect(hole);
      }
    }

    final tapBehavior = t.targetTapBehavior ?? TargetTapBehavior.advance;
    final passThrough = tapBehavior == TargetTapBehavior.passThrough ||
        tapBehavior == TargetTapBehavior.passThroughAndAdvance;

    // Tooltip widget
    final ctx = _tooltipContext(a, t);
    final preset = presetByName(t.tooltipStyle);
    final custom =
        a.step.tooltipBuilder ?? _c.tooltipBuilderNamed(t.tooltipStyle);
    final spec = preset != null && custom == null
        ? specFor(preset, t)
        : TooltipSpec(color: t.tooltipBackgroundColor ?? Colors.white);
    Widget tooltip;
    try {
      tooltip = custom != null
          ? custom(context, ctx)
          : buildPresetTooltip(context, preset ?? TooltipPreset.card, ctx);
    } catch (e) {
      tooltip = buildPresetTooltip(context, TooltipPreset.card, ctx);
    }
    tooltip = Semantics(
      container: true,
      liveRegion: true,
      label: a.step.semanticsLabel,
      child: tooltip,
    );
    tooltip =
        _enterTransition(t.animation ?? const DolphinAnimation(), tooltip);

    final pointer = t.pointer ?? const PointerStyle();
    final pointerColor = pointer.color ?? spec.color;
    final dotColor = pointer.dotColor ?? pointer.color ?? spec.color;

    var margin = t.screenMargin ?? const EdgeInsets.all(12);
    if (t.respectSafeArea != false) margin += MediaQuery.paddingOf(context);
    margin += EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom);

    var barrierColor = t.barrierColor ?? const Color(0xB3000000);
    final opacity = t.barrierOpacity;
    if (opacity != null && opacity.isFinite) {
      barrierColor = barrierColor.withValues(alpha: opacity.clamp(0.0, 1.0));
    }
    final blur = t.barrierBlur ?? 0;

    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _fade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (blur > 0)
              IgnorePointer(
                child: ClipPath(
                  clipper: _InverseClipper(holePath),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            _HoleHitTest(
              hole: holePath,
              passThrough: passThrough,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  if (holePath != null && holePath.contains(d.localPosition)) {
                    _c.handleHoleTap();
                  } else {
                    _c.handleBarrierTap();
                  }
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _BarrierPainter(hole: holePath, color: barrierColor),
                ),
              ),
            ),
            if (holePath != null)
              IgnorePointer(
                // Own layer: the pulse repaints only this, not the page.
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _HighlightPainter(
                      hole: holePath,
                      pulse: _pulse,
                      borderColor: t.highlightBorderColor ?? Colors.transparent,
                      borderWidth: t.highlightBorderWidth ?? 0,
                      glowColor: t.highlightGlowColor ?? Colors.transparent,
                      glowBlur: t.highlightGlowBlur ?? 0,
                      pulseColor: t.pulseColor ?? const Color(0x66FFFFFF),
                      pulseEnabled:
                          (t.animation ?? const DolphinAnimation()).pulse &&
                              (t.animation ?? const DolphinAnimation()).enabled,
                      borderDash: t.highlightBorderDash,
                      borderGradient: t.highlightBorderGradient,
                    ),
                  ),
                ),
              ),
            CustomMultiChildLayout(
              delegate: TooltipLayoutDelegate(
                hole: hole == null ? null : shape.getBounds(hole),
                position: t.tooltipPosition ?? TooltipPosition.auto,
                margin: margin,
                gap: t.targetGap ?? 4,
                pointer: pointer,
                maxWidth: t.tooltipMaxWidth ?? 340,
                placement: _placement,
                pointerMode: a.step.pointerMode ?? PointerMode.auto,
                manualOffset: a.step.pointerOffset,
                manualFraction: a.step.pointerX,
                pinnedToEdge: spec.pinnedToEdge,
              ),
              children: [
                LayoutId(
                    id: TooltipSlot.tooltip,
                    child: RepaintBoundary(child: tooltip)),
                LayoutId(
                  id: TooltipSlot.pointer,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: PointerPainter(
                        placement: _placement,
                        style: pointer,
                        arrowColor: pointerColor,
                        dotColor: dotColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _enterTransition(DolphinAnimation anim, Widget child) {
    if (!anim.enabled) return child;
    final curved = CurvedAnimation(parent: _enter, curve: anim.curve);
    switch (anim.transition) {
      case TooltipTransition.none:
        return child;
      case TooltipTransition.fade:
        return FadeTransition(opacity: curved, child: child);
      case TooltipTransition.scale:
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(curved),
              child: child),
        );
      case TooltipTransition.slide:
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                .animate(curved),
            child: child,
          ),
        );
    }
  }
}

class _BarrierPainter extends CustomPainter {
  _BarrierPainter({required this.hole, required this.color});
  final Path? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_outside(size, hole), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BarrierPainter old) =>
      old.hole != hole || old.color != color;
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.hole,
    required this.pulse,
    required this.borderColor,
    required this.borderWidth,
    required this.glowColor,
    required this.glowBlur,
    required this.pulseColor,
    required this.pulseEnabled,
    this.borderDash,
    this.borderGradient,
  }) : super(repaint: pulse);

  final Path hole;
  final Animation<double> pulse;
  final Color borderColor;
  final double borderWidth;
  final Color glowColor;
  final double glowBlur;
  final Color pulseColor;
  final bool pulseEnabled;
  final List<double>? borderDash;
  final Gradient? borderGradient;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Never paint over the target itself.
    canvas.clipPath(_outside(size, hole));
    if (glowBlur > 0 && glowColor.a > 0) {
      canvas.drawPath(
          hole,
          Paint()
            ..color = glowColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = glowBlur
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur / 2));
    }
    if (pulseEnabled) {
      final v = pulse.value;
      canvas.drawPath(
          hole,
          Paint()
            ..color = pulseColor.withValues(alpha: pulseColor.a * (1 - v))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + 16 * v);
    }
    canvas.restore();
    if (borderWidth > 0 && (borderColor.a > 0 || borderGradient != null)) {
      final paint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      if (borderGradient != null) {
        try {
          paint.shader = borderGradient!.createShader(hole.getBounds());
        } catch (_) {}
      }
      canvas.drawPath(_dashed(hole, borderDash), paint);
    }
  }

  /// [source] cut into dashes. Returns [source] when the pattern is unusable.
  static Path _dashed(Path source, List<double>? pattern) {
    if (pattern == null || pattern.isEmpty) return source;
    final steps = [for (final v in pattern) v.isFinite && v > 0 ? v : 0.0];
    if (steps.every((v) => v <= 0)) return source;
    final out = Path();
    var guard = 0;
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var i = 0;
      while (distance < metric.length && guard++ < 20000) {
        final len = steps[i % steps.length];
        if (i.isEven && len > 0) {
          out.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        i++;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.hole != hole ||
      old.borderColor != borderColor ||
      old.borderWidth != borderWidth ||
      old.glowColor != glowColor ||
      old.pulseEnabled != pulseEnabled ||
      old.borderGradient != borderGradient ||
      !listEquals(old.borderDash, borderDash);
}

class _InverseClipper extends CustomClipper<Path> {
  _InverseClipper(this.hole);
  final Path? hole;

  @override
  Path getClip(Size size) {
    return _outside(size, hole);
  }

  @override
  bool shouldReclip(_InverseClipper old) => old.hole != hole;
}

/// Lets taps inside the hole fall through to the real widget when the step
/// allows it; everything else is absorbed by the barrier.
class _HoleHitTest extends SingleChildRenderObjectWidget {
  const _HoleHitTest(
      {required this.hole, required this.passThrough, super.child});
  final Path? hole;
  final bool passThrough;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHoleHitTest(hole, passThrough);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleHitTest r) {
    r
      ..hole = hole
      ..passThrough = passThrough;
  }
}

class _RenderHoleHitTest extends RenderProxyBox {
  _RenderHoleHitTest(this.hole, this.passThrough);
  Path? hole;
  bool passThrough;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (passThrough && hole != null && hole!.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}

/// Everything except the hole. Built with the even-odd fill rule instead of
/// Path.combine, which leaves the hole filled on Flutter web (CanvasKit).
Path _outside(Size size, Path? hole) {
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size);
  if (hole != null) path.addPath(hole, Offset.zero);
  return path;
}
