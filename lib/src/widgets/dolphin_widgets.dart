import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/registry.dart';
import '../core/dolphin_controller.dart';
import '../models/dolphin_config.dart';
import '../models/dolphin_step.dart';
import '../ui/dolphin_theme.dart';

/// Makes a [DolphinController] available to every page. Put it above
/// your `MaterialApp` (or use `MaterialApp.builder`). It calls
/// `controller.init()` for you.
class Dolphin extends StatefulWidget {
  const Dolphin({super.key, required this.controller, required this.child});

  final DolphinController controller;
  final Widget child;

  static DolphinController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_DolphinInherited>()?.controller;

  static DolphinController of(BuildContext context) {
    final c = maybeOf(context);
    assert(c != null, 'No Dolphin widget found above this context.');
    return c!;
  }

  @override
  State<Dolphin> createState() => _DolphinState();
}

class _DolphinState extends State<Dolphin> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  void didUpdateWidget(Dolphin old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) widget.controller.init();
  }

  @override
  Widget build(BuildContext context) =>
      _DolphinInherited(controller: widget.controller, child: widget.child);
}

class _DolphinInherited extends InheritedWidget {
  const _DolphinInherited({required this.controller, required super.child});
  final DolphinController controller;
  @override
  bool updateShouldNotify(_DolphinInherited old) =>
      old.controller != controller;
}

/// Marks a page (or any section) as a walkthrough scope. Targets below it
/// belong to it, progress is tracked per scope, and "skip all" only affects
/// this scope.
///
/// When the page becomes visible and has pending steps, its walkthrough
/// starts automatically (unless [autoStart] is false or walkthroughs are
/// disabled). When another page is pushed on top it pauses, and it resumes
/// from where it stopped when the user comes back.
class DolphinScope extends StatefulWidget {
  const DolphinScope({
    super.key,
    required this.id,
    required this.child,
    this.autoStart,
    this.steps,
    this.sequence,
    this.exclude,
    this.theme,
    this.startDelay,
    this.controller,
  });

  final String id;
  final Widget child;

  /// Overrides the controller's and the central config's autoStart.
  final bool? autoStart;

  /// On-page step data (alternative to the central config or to data on each
  /// `DolphinTarget`).
  final List<DolphinStep>? steps;

  /// Custom order for this page.
  final List<String>? sequence;

  /// Steps to never show on this page.
  final Set<String>? exclude;
  final DolphinTheme? theme;
  final Duration? startDelay;

  /// Defaults to `Dolphin.of(context)`.
  final DolphinController? controller;

  static String? scopeIdOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ScopeMarker>()?.id;

  @override
  State<DolphinScope> createState() => _DolphinScopeState();
}

class _DolphinScopeState extends State<DolphinScope> implements ScopeHandle {
  DolphinController? _controller;
  ModalRoute<dynamic>? _route;
  ValueListenable<bool>? _tickerMode;
  bool _registered = false;
  bool _lastVisible = false;

  @override
  String get id => widget.id;

  @override
  ScopeConfig get inlineConfig => ScopeConfig(
        id: widget.id,
        steps: {for (final s in widget.steps ?? const <DolphinStep>[]) s.id: s},
        sequence: widget.sequence,
        exclude: widget.exclude ?? const {},
        autoStart: widget.autoStart,
        startDelay: widget.startDelay,
        theme: widget.theme,
      );

  @override
  bool get isVisible {
    if (!mounted) return false;
    if (_tickerMode != null && !_tickerMode!.value) return false;
    final r = _route;
    if (r == null) return true;
    try {
      if (!r.isActive || !r.isCurrent) return false;
      final a = r.animation;
      if (a != null && a.status != AnimationStatus.completed) return false;
      final s = r.secondaryAnimation;
      if (s != null && s.status != AnimationStatus.dismissed) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = widget.controller ?? Dolphin.maybeOf(context);
    if (c != _controller) {
      _unregister();
      _controller = c;
      if (c == null) {
        debugPrint('dolphin: DolphinScope "${widget.id}" has no controller. '
            'Wrap your app in Dolphin(...) or pass controller:.');
      }
    }
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeStatusListener(_onRouteAnimation);
      _route?.secondaryAnimation?.removeStatusListener(_onRouteAnimation);
      _route = route;
      route?.animation?.addStatusListener(_onRouteAnimation);
      route?.secondaryAnimation?.addStatusListener(_onRouteAnimation);
    }
    // getNotifier keeps compatibility with Flutter < 3.35.
    // ignore: deprecated_member_use
    final tm = TickerMode.getNotifier(context);
    if (tm != _tickerMode) {
      _tickerMode?.removeListener(_visibilityMaybeChanged);
      _tickerMode = tm;
      tm.addListener(_visibilityMaybeChanged);
    }
    _register();
    _visibilityMaybeChanged();
  }

  @override
  void didUpdateWidget(DolphinScope old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.controller != widget.controller) {
      _unregister();
      _controller = widget.controller ?? Dolphin.maybeOf(context);
      _register();
    }
  }

  void _register() {
    if (_registered || _controller == null) return;
    _controller!.registerScope(this);
    _registered = true;
  }

  void _unregister() {
    if (!_registered) return;
    _controller?.unregisterScope(this);
    _registered = false;
  }

  void _onRouteAnimation(AnimationStatus _) => _visibilityMaybeChanged();

  void _visibilityMaybeChanged() {
    final v = isVisible;
    if (v == _lastVisible) return;
    _lastVisible = v;
    if (_registered) _controller?.scopeVisibilityChanged(this);
  }

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_onRouteAnimation);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteAnimation);
    _tickerMode?.removeListener(_visibilityMaybeChanged);
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // isCurrent changes without a route animation for dialogs/popups; the
    // dependency on ModalRoute above re-runs didChangeDependencies.
    return _ScopeMarker(id: widget.id, child: widget.child);
  }
}

class _ScopeMarker extends InheritedWidget {
  const _ScopeMarker({required this.id, required super.child});
  final String id;
  @override
  bool updateShouldNotify(_ScopeMarker old) => old.id != id;
}

/// Wraps the widget to highlight. Only [id] is required; content can come
/// from the central config, from the enclosing [DolphinScope.steps], or
/// from the parameters here.
///
/// If the controller is missing or anything goes wrong, the child is still
/// rendered untouched.
class DolphinTarget extends StatefulWidget {
  const DolphinTarget({
    super.key,
    required this.id,
    required this.child,
    this.scope,
    this.title,
    this.description,
    this.order,
    this.theme,
    this.tooltipBuilder,
    this.step,
    this.enabled = true,
    this.controller,
  });

  final String id;
  final Widget child;

  /// Defaults to the nearest [DolphinScope]. Needed only when there is
  /// none, or to attach this target to another scope.
  final String? scope;
  final String? title;
  final String? description;
  final int? order;
  final DolphinTheme? theme;
  final DolphinTooltipBuilder? tooltipBuilder;

  /// Full inline data; merged with the convenience fields above.
  final DolphinStep? step;

  /// False removes this target from the walkthrough (the child still shows).
  final bool enabled;
  final DolphinController? controller;

  @override
  State<DolphinTarget> createState() => _DolphinTargetState();
}

class _DolphinTargetState extends State<DolphinTarget> {
  final GlobalKey _key = GlobalKey(debugLabel: 'walkthrough target');
  DolphinController? _controller;
  TargetHandle? _handle;
  Offset? _down;
  Duration? _downTime;

  DolphinStep? get _inline {
    final hasConvenience = widget.title != null ||
        widget.description != null ||
        widget.order != null ||
        widget.theme != null ||
        widget.tooltipBuilder != null;
    final convenience = hasConvenience
        ? DolphinStep(
            id: widget.id,
            title: widget.title,
            description: widget.description,
            order: widget.order,
            theme: widget.theme,
            tooltipBuilder: widget.tooltipBuilder,
          )
        : null;
    if (widget.step == null) return convenience;
    return widget.step!.merge(convenience);
  }

  String? get _scopeId => widget.scope ?? DolphinScope.scopeIdOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DolphinTarget old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final c = widget.controller ?? Dolphin.maybeOf(context);
    final scope = _scopeId;
    final h = _handle;
    final same = h != null &&
        c == _controller &&
        h.id == widget.id &&
        h.scope == scope &&
        widget.enabled;
    if (same) {
      h.inline = _inline;
      return;
    }
    _unregister();
    _controller = c;
    if (c == null || scope == null || !widget.enabled) return;
    _handle = c.registerTarget(
        id: widget.id, scope: scope, key: _key, inline: _inline);
  }

  void _unregister() {
    final h = _handle;
    if (h != null) _controller?.unregisterTarget(h);
    _handle = null;
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  void _onUp(PointerUpEvent e) {
    final down = _down, t0 = _downTime;
    _down = null;
    if (down == null || t0 == null) return;
    final moved = (e.position - down).distance;
    final held = e.timeStamp - t0;
    if (moved > 18 || held > const Duration(milliseconds: 700)) return;
    final h = _handle;
    if (h != null) _controller?.targetTapped(h);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _downTime = e.timeStamp;
      },
      onPointerUp: _onUp,
      onPointerCancel: (_) => _down = null,
      child: KeyedSubtree(key: _key, child: widget.child),
    );
  }
}
