import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../models/dolphin_config.dart';
import '../models/dolphin_progress.dart';
import '../models/dolphin_step.dart';
import '../storage/default_store.dart';
import '../storage/dolphin_store.dart';
import '../ui/dolphin_overlay.dart';
import '../ui/dolphin_theme.dart';
import 'registry.dart';
import 'scope_summary.dart';
import 'target_geometry.dart';
import 'dolphin_event.dart';

/// When a step has data both inline (on the widget) and in the central
/// config, which one wins field by field.
enum DataPrecedence { centralWins, inlineWins }

/// How the "1/3" counter counts.
enum CounterMode {
  /// Position among all steps of the page, seen ones included (resume shows
  /// "3/5").
  wholeScope,

  /// Position among the steps still pending when this run started ("1/3").
  remainingOnly,
}

/// What "skip" inside a journey leg does to the journey.
enum JourneySkipBehavior { stopJourney, continueJourney }

/// Opens the page of a journey leg. Return when navigation was triggered.
typedef JourneyNavigator = Future<void> Function(
    BuildContext? context, JourneyLeg leg, DolphinJourney journey);

/// The step currently on screen. Read by the overlay and by custom UIs.
@immutable
class ActiveStep {
  const ActiveStep({
    required this.scope,
    required this.step,
    required this.theme,
    DolphinTheme? darkTheme,
    required this.index,
    required this.total,
    required this.counterText,
    required this.isFirst,
    required this.isLast,
    required this.serial,
    this.targetKey,
    this.fallbackRect,
    this.centered = false,
  }) : darkTheme = darkTheme ?? theme;

  final String scope;
  final DolphinStep step;

  /// The fully merged light theme.
  final DolphinTheme theme;

  /// The fully merged dark theme (same as [theme] when nothing differs).
  final DolphinTheme darkTheme;

  DolphinTheme themeFor({required bool isDark}) => isDark ? darkTheme : theme;

  /// 1-based.
  final int index;
  final int total;
  final String counterText;
  final bool isFirst;
  final bool isLast;

  /// Unique per presentation; used to ignore stale callbacks.
  final int serial;
  final GlobalKey? targetKey;
  final FractionalRect? fallbackRect;

  /// No target: tooltip centred, no hole.
  final bool centered;
}

class _PlanItem {
  _PlanItem(this.step, {required this.counted});
  final DolphinStep step;
  final bool counted;
}

class _Run {
  _Run(this.scope, this.items,
      {this.replay = false,
      this.journeyId,
      this.legIndex,
      this.pendingAtStart = const {}});
  final String scope;
  final List<_PlanItem> items;
  final bool replay;
  final String? journeyId;
  final int? legIndex;
  final Set<String> pendingAtStart;
  int index = -1;
  int maxIndex = -1;
  bool paused = false;
}

class _Resolution {
  _Resolution({this.key, this.fallback, this.centered = false});
  final GlobalKey? key;
  final FractionalRect? fallback;
  final bool centered;
}

/// Brain of the walkthrough: knows every page (scope) and target, decides
/// what to show, persists what was seen, and exposes progress for syncing.
///
/// Create one for the whole app, call [init] (or let `Dolphin` do it),
/// and put a `Dolphin` widget above your `MaterialApp`'s navigator.
class DolphinController extends ChangeNotifier {
  DolphinController({
    DolphinStore? store,
    DolphinConfig config = DolphinConfig.empty,
    this.theme,
    this.darkTheme,
    this.themeMode = DolphinThemeMode.app,
    this.dataPrecedence = DataPrecedence.centralWins,
    this.counterMode = CounterMode.wholeScope,
    this.autoStart = true,
    bool enabled = true,
    this.startDelay = const Duration(milliseconds: 350),
    this.waitForTarget = const Duration(milliseconds: 600),
    this.scrollIntoView = true,
    this.missingTarget = MissingTargetBehavior.skip,
    this.navigatorKey,
    this.journeyNavigator,
    this.journeySkipBehavior = JourneySkipBehavior.stopJourney,
    this.onEvent,
    this.onProgressChanged,
    this.onError,
    this.debugLogging = false,
  })  : _store = store,
        _config = config,
        _enabledDefault = enabled;

  DolphinStore? _store;
  DolphinStore get store => _store ??= defaultDolphinStore();

  /// App-wide look. Merged over `DolphinTheme.fallback`.
  DolphinTheme? theme;

  /// App-wide dark-mode overrides, applied over [theme] when the overlay is
  /// dark. Unset fields fall back to `DolphinTheme.fallbackDark`.
  DolphinTheme? darkTheme;

  /// Decides when [darkTheme] is used. Read whenever the overlay builds, so a
  /// light / dark switch of the app or phone restyles the step on screen.
  DolphinThemeMode themeMode;
  DataPrecedence dataPrecedence;
  CounterMode counterMode;

  /// Start pages automatically when they become visible with pending steps.
  bool autoStart;
  Duration startDelay;

  /// Default wait for targets that mount late.
  Duration waitForTarget;
  bool scrollIntoView;
  MissingTargetBehavior missingTarget;

  /// Used by the default journey navigator (`pushNamed(leg.route)`).
  GlobalKey<NavigatorState>? navigatorKey;
  JourneyNavigator? journeyNavigator;
  JourneySkipBehavior journeySkipBehavior;

  void Function(DolphinEvent event)? onEvent;

  /// Called after every change of progress. Save it wherever you like.
  void Function(DolphinProgress progress)? onProgressChanged;
  void Function(Object error, StackTrace stack)? onError;
  bool debugLogging;

  final bool _enabledDefault;
  bool? _enabledStored;
  DolphinConfig _config;
  DolphinProgress _local = DolphinProgress.empty;
  DolphinProgress? _overlayProgress;
  MergeStrategy _overlayStrategy = MergeStrategy.union;
  DolphinProgress? _effectiveCache;
  late final ValueNotifier<DolphinProgress> _progressNotifier =
      ValueNotifier(progress);
  final StreamController<DolphinEvent> _events =
      StreamController<DolphinEvent>.broadcast();

  final Map<String, List<ScopeHandle>> _scopes = {};
  final Map<String, List<TargetHandle>> _targets = {};
  final Map<String, List<String>> _sequences = {};
  final Map<String, Set<String>> _excludes = {};
  final Set<String> _disabledScopes = {};
  final Set<String> _dismissed = {};
  final Map<String, DolphinTooltipBuilder> _tooltipBuilders = {};
  final Map<String, bool Function()> _conditions = {};
  final Map<String, DolphinJourney> _journeys = {};
  final Map<String, Timer> _startTimers = {};
  final Map<String, _Run> _runs = {};

  _Run? _active;
  ActiveStep? _activeStep;
  int _serial = 0;
  int _token = 0;
  int _targetSerial = 0;
  String? _journeyId;
  Timer? _autoAdvance;
  OverlayEntry? _entry;
  OverlayState? _entryOverlay;
  bool _evaluateScheduled = false;
  bool _disposed = false;
  Future<void>? _initFuture;
  bool _ready = false;
  Future<void> _saveChain = Future.value();
  ProgressDelta? _pendingDelta;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  bool get isReady => _ready;
  DolphinConfig get config => _config;

  /// Whether walkthroughs auto-start. Persisted.
  bool get enabled => _enabledStored ?? _enabledDefault;

  /// The step on screen, or null.
  ActiveStep? get activeStep => _activeStep;
  bool get isShowing => _activeStep != null;
  String? get activeScope => _active?.scope;
  String? get activeJourney => _journeyId;

  /// Current progress (local, merged with any session-only import).
  DolphinProgress get progress {
    if (_overlayProgress == null) return _local;
    return _effectiveCache ??=
        _local.merge(_overlayProgress!, strategy: _overlayStrategy);
  }

  /// Listen to this to keep your own DB or server in sync.
  ValueListenable<DolphinProgress> get progressListenable => _progressNotifier;
  Stream<DolphinEvent> get events => _events.stream;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Loads stored flags and progress. Safe to call many times.
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      await store.init();
      final flags = await store.loadFlags();
      _applyFlags(flags);
      _local = await store.loadProgress();
    } catch (e, s) {
      _error(e, s);
    }
    _ready = true;
    _progressChanged(notifyStore: false);
    _safeNotify();
    _scheduleEvaluate();
  }

  void _applyFlags(Map<String, Object?> flags) {
    final e = flags['enabled'];
    if (e is bool) _enabledStored = e;
    final d = flags['disabledScopes'];
    if (d is List) _disabledScopes.addAll(d.map((x) => '$x'));
    flags.forEach((k, v) {
      if (v is! List) return;
      final list = v.map((x) => '$x').toList();
      if (k.startsWith('seq.')) _sequences[k.substring(4)] = list;
      if (k.startsWith('exc.')) _excludes[k.substring(4)] = list.toSet();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _token++;
    _autoAdvance?.cancel();
    for (final t in _startTimers.values) {
      t.cancel();
    }
    _removeEntry();
    _events.close();
    _progressNotifier.dispose();
    super.dispose();
  }

  /// Waits until every queued write reached the store.
  Future<void> flush() async {
    await Future<void>.microtask(() {});
    await _saveChain;
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Replaces the central config (e.g. after fetching it from your server).
  void setConfig(DolphinConfig config) {
    _config = config;
    _safeNotify();
    _scheduleEvaluate();
  }

  /// Deep-merges [config] into the current one.
  void mergeConfig(DolphinConfig config) => setConfig(_config.merge(config));

  /// Parses and merges JSON config. Bad JSON is reported, never thrown.
  void loadConfigJson(Map<String, dynamic> json, {bool replace = false}) {
    try {
      final c = DolphinConfig.fromJson(json);
      replace ? setConfig(c) : mergeConfig(c);
    } catch (e, s) {
      _error(e, s);
    }
  }

  /// Makes a builder available by name, so JSON config can say
  /// `"tooltipStyle": "promo"`.
  void registerTooltipBuilder(String name, DolphinTooltipBuilder builder) =>
      _tooltipBuilders[name] = builder;

  DolphinTooltipBuilder? tooltipBuilderNamed(String? name) =>
      name == null ? null : _tooltipBuilders[name];

  /// Makes a condition available by name for JSON config
  /// (`"condition": "isPremium"`).
  void registerCondition(String name, bool Function() test) =>
      _conditions[name] = test;

  void registerJourney(DolphinJourney journey) =>
      _journeys[journey.id] = journey;

  /// Enables or disables automatic walkthroughs everywhere. Persisted.
  Future<void> setEnabled(bool value) async {
    _enabledStored = value;
    if (!value) {
      for (final t in _startTimers.values) {
        t.cancel();
      }
      _startTimers.clear();
    }
    await _setFlag('enabled', value);
    _safeNotify();
    _scheduleEvaluate();
  }

  bool isScopeEnabled(String scope) =>
      !_disabledScopes.contains(scope) &&
      (_scopeConfig(scope)?.enabled ?? true);

  /// Enables or disables auto-start for one page. Persisted.
  Future<void> setScopeEnabled(String scope, bool value) async {
    value ? _disabledScopes.remove(scope) : _disabledScopes.add(scope);
    await _setFlag('disabledScopes', _disabledScopes.toList());
    _scheduleEvaluate();
  }

  /// Custom order of steps for a page. Steps you leave out still run after
  /// the listed ones unless excluded. Pass `persist: true` to remember it.
  Future<void> setSequence(String scope, List<String> stepIds,
      {bool persist = false}) async {
    _sequences[scope] = List.of(stepIds);
    if (persist) await _setFlag('seq.$scope', stepIds);
    _safeNotify();
  }

  Future<void> clearSequence(String scope) async {
    _sequences.remove(scope);
    await _setFlag('seq.$scope', null);
    _safeNotify();
  }

  /// Never show these steps on [scope].
  Future<void> exclude(String scope, Iterable<String> stepIds,
      {bool persist = false}) async {
    (_excludes[scope] ??= {}).addAll(stepIds);
    if (persist) await _setFlag('exc.$scope', _excludes[scope]!.toList());
    _safeNotify();
  }

  /// Undo [exclude].
  Future<void> include(String scope, Iterable<String> stepIds,
      {bool persist = false}) async {
    _excludes[scope]?.removeAll(stepIds);
    if (persist) await _setFlag('exc.$scope', _excludes[scope]?.toList());
    _safeNotify();
    _scheduleEvaluate();
  }

  // ---------------------------------------------------------------------------
  // Registry (called by widgets)
  // ---------------------------------------------------------------------------

  TargetHandle registerTarget({
    required String id,
    required String scope,
    required GlobalKey key,
    DolphinStep? inline,
  }) {
    final h = TargetHandle(
        id: id,
        scope: scope,
        key: key,
        inline: inline,
        serial: _targetSerial++);
    (_targets[stepKey(scope, id)] ??= []).add(h);
    _scheduleEvaluate();
    return h;
  }

  void unregisterTarget(TargetHandle handle) {
    final list = _targets[stepKey(handle.scope, handle.id)];
    list?.remove(handle);
    if (list != null && list.isEmpty) {
      _targets.remove(stepKey(handle.scope, handle.id));
    }
    final a = _activeStep;
    if (a != null && a.targetKey == handle.key) {
      // The target vanished while visible: move on after this frame.
      final serial = a.serial;
      _postFrame(() => targetLost(serial));
    }
  }

  void registerScope(ScopeHandle scope) {
    (_scopes[scope.id] ??= []).add(scope);
    _scheduleEvaluate();
  }

  void unregisterScope(ScopeHandle scope) {
    final list = _scopes[scope.id];
    list?.remove(scope);
    if (list == null || list.isEmpty) {
      _scopes.remove(scope.id);
      _startTimers.remove(scope.id)?.cancel();
      final run = _runs.remove(scope.id);
      if (run != null && identical(run, _active)) {
        _token++;
        _active = null;
        _setActiveStep(null);
        _removeEntry();
      }
    }
    _scheduleEvaluate();
  }

  /// Called by `DolphinScope` when its route visibility changes.
  void scopeVisibilityChanged(ScopeHandle scope) {
    if (!scope.isVisible) {
      if (_active?.scope == scope.id && !_isScopeVisible(scope.id)) {
        _pause(_active!);
      }
      _startTimers.remove(scope.id)?.cancel();
    }
    _scheduleEvaluate();
  }

  /// Called by `DolphinTarget` when the user taps it.
  void targetTapped(TargetHandle handle) {
    final a = _activeStep;
    final run = _active;
    if (a == null || run == null) return;
    if (a.scope != handle.scope || a.step.id != handle.id) return;
    if (a.theme.targetTapBehavior != TargetTapBehavior.passThroughAndAdvance) {
      return;
    }
    _markDone(run.scope, a.step, StepStatus.seen);
    _emit(DolphinEvent(DolphinEventType.stepCompleted,
        scope: run.scope, step: a.step.id, status: StepStatus.seen));
    run.index = run.index + 1;
    run.maxIndex = math.max(run.maxIndex, run.index - 1);
    _token++;
    _autoAdvance?.cancel();
    _setActiveStep(null);
    _removeEntry();
    // The tap may navigate. Look again after the frame.
    final token = _token;
    _postFrame(() {
      if (token != _token || !identical(_active, run)) return;
      if (_isScopeVisible(run.scope)) {
        _advanceTo(run, run.index);
      } else {
        _pause(run);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Running
  // ---------------------------------------------------------------------------

  /// Starts (or resumes) the walkthrough of [scope] from its first pending
  /// step. With [replay] it shows every step again without resetting.
  /// [only] restricts the run to these step ids.
  /// Returns false when there is nothing to show.
  Future<bool> start(
    String scope, {
    bool replay = false,
    List<String>? only,
    bool ignoreDisabled = true,
  }) =>
      _start(scope, replay: replay, only: only, ignoreDisabled: ignoreDisabled);

  Future<bool> _start(
    String scope, {
    bool replay = false,
    List<String>? only,
    bool ignoreDisabled = true,
    String? journeyId,
    int? legIndex,
  }) async {
    await init();
    if (_disposed) return false;
    if (!ignoreDisabled && (!enabled || !isScopeEnabled(scope))) return false;
    _startTimers.remove(scope)?.cancel();

    final current = _active;
    if (current != null) {
      if (current.scope == scope && !replay && only == null) return true;
      _finish(current, completed: false, silent: true);
    }

    final items = _plan(scope, only: only);
    if (items.isEmpty) {
      _log('start($scope): no steps');
      return false;
    }
    _rememberKnownSteps(scope, items);
    final pending = {
      for (final i in items)
        if (!_isDone(scope, i.step)) i.step.id
    };
    if (!replay && pending.isEmpty) {
      _log('start($scope): everything seen');
      return false;
    }
    _dismissed.remove(scope);
    final run = _Run(scope, items,
        replay: replay,
        journeyId: journeyId,
        legIndex: legIndex,
        pendingAtStart: pending);
    _runs[scope] = run;
    _active = run;
    _emit(DolphinEvent(DolphinEventType.scopeStarted, scope: scope));
    await _advanceTo(run, 0);
    return true;
  }

  /// Marks the current step seen and shows the next one.
  void next() {
    final run = _active, a = _activeStep;
    if (run == null || a == null) return;
    _markDone(run.scope, a.step, StepStatus.seen);
    _emit(DolphinEvent(DolphinEventType.stepCompleted,
        scope: run.scope, step: a.step.id, status: StepStatus.seen));
    _advanceTo(run, run.index + 1);
  }

  /// Shows the previous step again (already-seen steps included).
  void previous() {
    final run = _active;
    if (run == null || _activeStep == null || run.index <= 0) return;
    _advanceTo(run, run.index - 1, forward: false);
  }

  /// "Skip all": marks every remaining step of the current page as skipped
  /// (only this page) and closes.
  void skipScope() {
    final run = _active;
    if (run == null) return;
    for (var i = math.max(run.index, 0); i < run.items.length; i++) {
      final s = run.items[i].step;
      if (!_isDone(run.scope, s)) _markDone(run.scope, s, StepStatus.skipped);
    }
    _emit(DolphinEvent(DolphinEventType.scopeSkipped, scope: run.scope));
    _finish(run, completed: true, skipped: true);
  }

  /// Closes without marking the current step. It shows again the next time
  /// the page opens (or when [start] is called).
  void dismiss() {
    final run = _active;
    if (run == null) return;
    _dismissed.add(run.scope);
    _emit(DolphinEvent(DolphinEventType.dismissed,
        scope: run.scope, step: _activeStep?.step.id));
    _finish(run, completed: false);
  }

  /// Hides the walkthrough but keeps its position; [resume] continues.
  void pause() {
    final run = _active;
    if (run != null) _pause(run);
  }

  /// Resumes a paused page, or the active one.
  Future<void> resume([String? scope]) async {
    final run =
        scope != null ? _runs[scope] : (_active ?? _runs.values.firstOrNull);
    if (run == null || _active != null && !identical(_active, run)) return;
    run.paused = false;
    _active = run;
    _emit(DolphinEvent(DolphinEventType.resumed, scope: run.scope));
    await _advanceTo(run, math.max(run.index, 0));
  }

  /// Overlay callback: the target could not be found for a while.
  void targetLost(int serial) {
    final a = _activeStep, run = _active;
    if (a == null || run == null || a.serial != serial) return;
    _log('target lost: ${a.scope}/${a.step.id}');
    _emit(DolphinEvent(DolphinEventType.stepSkippedMissingTarget,
        scope: a.scope, step: a.step.id, problem: TargetProblem.notMounted));
    if ((a.step.missingTarget ?? missingTarget) ==
        MissingTargetBehavior.skipAndMarkSeen) {
      _markDone(run.scope, a.step, StepStatus.skipped);
    }
    _advanceTo(run, run.index + 1);
  }

  /// Overlay callback for a tap on the barrier.
  void handleBarrierTap() {
    final a = _activeStep;
    if (a == null) return;
    switch (a.theme.barrierTapBehavior ?? BarrierTapBehavior.none) {
      case BarrierTapBehavior.none:
        break;
      case BarrierTapBehavior.next:
        next();
      case BarrierTapBehavior.dismiss:
        dismiss();
      case BarrierTapBehavior.skipScope:
        skipScope();
    }
  }

  /// Overlay callback for a tap inside the hole when it absorbs taps.
  void handleHoleTap() {
    final a = _activeStep;
    if (a == null) return;
    if (a.theme.targetTapBehavior == TargetTapBehavior.advance) next();
  }

  /// Overlay callback for the system back button. True = consumed.
  bool handleBack() {
    final a = _activeStep;
    if (a == null) return false;
    switch (a.theme.backButtonBehavior ?? BackButtonBehavior.dismiss) {
      case BackButtonBehavior.dismiss:
        dismiss();
        return true;
      case BackButtonBehavior.previous:
        if (a.isFirst) {
          dismiss();
        } else {
          previous();
        }
        return true;
      case BackButtonBehavior.block:
        return true;
      case BackButtonBehavior.passThrough:
        dismiss();
        return false;
    }
  }

  /// Overlay callback once the fade-out finished.
  void overlayHidden() {
    if (_activeStep == null) _removeEntry();
  }

  Future<void> _advanceTo(_Run run, int from, {bool forward = true}) async {
    final token = ++_token;
    _autoAdvance?.cancel();
    var i = from;
    while (i >= 0 && i < run.items.length) {
      final item = run.items[i];
      final step = item.step;
      final mustShow = !forward ||
          run.replay ||
          i <= run.maxIndex ||
          !_isDone(run.scope, step);
      if (mustShow && _conditionOk(step)) {
        final res = await _resolve(run, step, token);
        if (token != _token || !identical(_active, run) || _disposed) return;
        if (res != null) {
          _present(run, i, res);
          return;
        }
        final behavior = step.missingTarget ?? missingTarget;
        if (behavior == MissingTargetBehavior.skipAndMarkSeen) {
          _markDone(run.scope, step, StepStatus.skipped);
        }
      }
      i += forward ? 1 : -1;
    }
    if (forward) {
      _finish(run, completed: true);
    } else if (run.index >= 0 && run.index < run.items.length) {
      // Nothing earlier can be shown: stay where we are.
      final res = await _resolve(run, run.items[run.index].step, token);
      if (token == _token && res != null) _present(run, run.index, res);
    }
  }

  Future<_Resolution?> _resolve(_Run run, DolphinStep step, int token) async {
    final behavior = step.missingTarget ?? missingTarget;
    final wait = step.waitForTarget ?? waitForTarget;
    final deadline = DateTime.now().add(wait);
    TargetProblem problem = TargetProblem.notRegistered;
    var scrolled = false;
    while (true) {
      if (token != _token) return null;
      final overlayBox = _overlayBox(run.scope);
      final handles = _targets[stepKey(run.scope, step.id)] ?? const [];
      for (final h in handles.reversed) {
        var m = TargetGeometry.measure(h.context, overlayBox);
        final wantsScroll = step.scrollIntoView ?? scrollIntoView;
        if (wantsScroll &&
            !scrolled &&
            h.context != null &&
            overlayBox != null &&
            (m.problem == TargetProblem.offscreen ||
                (m.isOk &&
                    !TargetGeometry.isFullyVisible(
                        m.rect!, overlayBox.size)))) {
          scrolled = true;
          await _ensureVisible(h.context!);
          if (token != _token) return null;
          m = TargetGeometry.measure(h.context, _overlayBox(run.scope));
        }
        if (m.isOk) return _Resolution(key: h.key);
        problem = m.problem ?? problem;
      }
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (step.fallbackRect != null) {
      return _Resolution(fallback: step.fallbackRect);
    }
    if (behavior == MissingTargetBehavior.showCentered) {
      return _Resolution(centered: true);
    }
    _log('skip ${run.scope}/${step.id}: ${problem.name}');
    _emit(DolphinEvent(DolphinEventType.stepSkippedMissingTarget,
        scope: run.scope, step: step.id, problem: problem));
    return null;
  }

  Future<void> _ensureVisible(BuildContext context) async {
    try {
      if (!context.mounted || Scrollable.maybeOf(context) == null) return;
      await Scrollable.ensureVisible(context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut)
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      await _nextFrame();
    } catch (e, s) {
      _error(e, s);
    }
  }

  void _present(_Run run, int i, _Resolution res) {
    run.index = i;
    run.maxIndex = math.max(run.maxIndex, i);
    run.paused = false;
    final item = run.items[i];
    final step = item.step;
    final t = resolveTheme(run.scope, step);
    final dt = resolveTheme(run.scope, step, isDark: true);

    final counting = counterMode == CounterMode.remainingOnly
        ? run.items
            .where((x) => x.counted && run.pendingAtStart.contains(x.step.id))
            .toList()
        : run.items.where((x) => x.counted).toList();
    var pos = counting.indexWhere((x) => identical(x, item));
    if (pos < 0) {
      pos = counting.where((x) => run.items.indexOf(x) < i).length;
    }
    final total = math.max(counting.length, pos + 1);
    final current = pos + 1;
    final counterText = step.counterText ??
        (t.counterFormat ?? '{current}/{total}')
            .replaceAll('{current}', '$current')
            .replaceAll('{total}', '$total');

    bool showable(int j) {
      final s = run.items[j].step;
      return _conditionOk(s) &&
          (run.replay || j <= run.maxIndex || !_isDone(run.scope, s));
    }

    var isLast = true;
    for (var j = i + 1; j < run.items.length; j++) {
      if (showable(j) && run.items[j].counted) {
        isLast = false;
        break;
      }
    }

    _setActiveStep(ActiveStep(
      scope: run.scope,
      step: step,
      theme: t,
      darkTheme: dt,
      index: current,
      total: total,
      counterText: counterText,
      isFirst: i == 0 || !run.items.take(i).any((x) => x.counted),
      isLast: isLast,
      serial: ++_serial,
      targetKey: res.key,
      fallbackRect: res.fallback,
      centered: res.centered,
    ));
    _ensureOverlay(run.scope);
    _updateScopeRecord(run.scope, lastStepId: step.id);
    _emit(DolphinEvent(DolphinEventType.stepShown,
        scope: run.scope, step: step.id, index: current, total: total));
    final delay = step.autoAdvanceAfter;
    if (delay != null) {
      final serial = _serial;
      _autoAdvance = Timer(delay, () {
        if (_activeStep?.serial == serial) next();
      });
    }
  }

  void _pause(_Run run) {
    if (!identical(_active, run)) return;
    _token++;
    _autoAdvance?.cancel();
    run.paused = true;
    _active = null;
    _setActiveStep(null);
    _removeEntry();
    _emit(DolphinEvent(DolphinEventType.paused, scope: run.scope));
    _scheduleEvaluate();
  }

  void _finish(_Run run,
      {required bool completed, bool skipped = false, bool silent = false}) {
    _token++;
    _autoAdvance?.cancel();
    _runs.remove(run.scope);
    if (identical(_active, run)) {
      _active = null;
      _setActiveStep(null);
    }
    if (completed) {
      final allDone = run.items.every((i) => _isDone(run.scope, i.step));
      if (allDone) {
        _updateScopeRecord(run.scope, completedAt: DateTime.now().toUtc());
      }
      if (!skipped) {
        _emit(DolphinEvent(DolphinEventType.scopeCompleted, scope: run.scope));
      }
      final jid = run.journeyId;
      if (jid != null && jid == _journeyId) {
        if (skipped && journeySkipBehavior == JourneySkipBehavior.stopJourney) {
          stopJourney();
        } else {
          _completeLeg(jid, run.legIndex ?? 0);
        }
      }
    }
    if (!silent) _scheduleEvaluate();
  }

  // ---------------------------------------------------------------------------
  // Journeys
  // ---------------------------------------------------------------------------

  DolphinJourney? journeyById(String id) =>
      _journeys[id] ?? _config.journeys[id];

  /// Starts (or resumes) a cross-page journey. With [restart] it starts again
  /// from the first leg and shows its steps even if they were seen.
  Future<bool> startJourney(String id, {bool restart = false}) async {
    await init();
    final j = journeyById(id);
    if (j == null || j.legs.isEmpty) return false;
    final rec = progress.journeys[id];
    if (rec != null && rec.completed && !restart) return false;
    if (restart) {
      for (final leg in j.legs) {
        final ids =
            leg.steps ?? _plan(leg.scope).map((e) => e.step.id).toList();
        _clearSteps(leg.scope, ids);
      }
    }
    final leg = restart ? 0 : (rec?.legIndex ?? 0).clamp(0, j.legs.length - 1);
    _journeyId = id;
    _writeJourney(JourneyRecord(
        id: id,
        legIndex: leg,
        active: true,
        updatedAt: DateTime.now().toUtc()));
    await _enterLeg(j, leg);
    return true;
  }

  /// Stops the running journey; its position is kept for [startJourney].
  void stopJourney() {
    final id = _journeyId;
    if (id == null) return;
    _journeyId = null;
    final rec = progress.journeys[id];
    if (rec != null) _writeJourney(rec.copyWith(active: false));
    _emit(DolphinEvent(DolphinEventType.journeyStopped, journey: id));
  }

  /// Resumes a journey left active in a previous session.
  Future<bool> resumeActiveJourney() async {
    await init();
    final rec = progress.journeys.values
        .where((j) => j.active && !j.completed)
        .firstOrNull;
    if (rec == null) return false;
    return startJourney(rec.id);
  }

  Future<void> _enterLeg(DolphinJourney j, int index) async {
    final leg = j.legs[index];
    _emit(DolphinEvent(DolphinEventType.journeyLegStarted,
        journey: j.id, legIndex: index, scope: leg.scope));
    if (_isScopeVisible(leg.scope)) {
      final ok = await _start(leg.scope,
          only: leg.steps, journeyId: j.id, legIndex: index);
      if (!ok && _journeyId == j.id) _completeLeg(j.id, index);
      return;
    }
    try {
      final nav = journeyNavigator;
      if (nav != null) {
        await nav(navigatorKey?.currentContext ?? _anyContext(), leg, j);
      } else if (leg.route != null) {
        final navigator =
            navigatorKey?.currentState ?? _maybeNavigator(_anyContext());
        if (navigator != null) {
          unawaited(navigator.pushNamed(leg.route!, arguments: leg.arguments));
        } else {
          _log('journey ${j.id}: no navigator to open ${leg.route}');
        }
      }
    } catch (e, s) {
      _error(e, s);
    }
    _scheduleEvaluate();
  }

  void _completeLeg(String journeyId, int legIndex) {
    final j = journeyById(journeyId);
    if (j == null) return;
    final next = legIndex + 1;
    if (next >= j.legs.length) {
      _writeJourney(JourneyRecord(
          id: journeyId,
          legIndex: j.legs.length,
          completed: true,
          updatedAt: DateTime.now().toUtc()));
      _journeyId = null;
      _emit(
          DolphinEvent(DolphinEventType.journeyCompleted, journey: journeyId));
      return;
    }
    _writeJourney(JourneyRecord(
        id: journeyId,
        legIndex: next,
        active: true,
        updatedAt: DateTime.now().toUtc()));
    _postFrame(() {
      if (_journeyId == journeyId) _enterLeg(j, next);
    });
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// "Rewatch walkthrough": forgets everything and restarts visible pages.
  Future<void> resetAll({bool restart = true}) async {
    await init();
    final run = _active;
    if (run != null) _finish(run, completed: false, silent: true);
    _runs.clear();
    _dismissed.clear();
    _journeyId = null;
    final now = DateTime.now().toUtc();
    _overlayProgress = null;
    _local = DolphinProgress(resetAt: now, updatedAt: now);
    _queueSave(ProgressDelta.full());
    _emit(const DolphinEvent(DolphinEventType.reset));
    _progressChanged();
    if (restart) _scheduleEvaluate();
  }

  /// Forgets one page (section) and restarts it if it is visible.
  Future<void> resetScope(String scope, {bool restart = true}) =>
      resetScopes([scope], restart: restart);

  Future<void> resetScopes(Iterable<String> scopes,
      {bool restart = true}) async {
    await init();
    final now = DateTime.now().toUtc();
    final delta = ProgressDelta();
    final steps = Map.of(_local.steps);
    final scopeRecs = Map.of(_local.scopes);
    for (final scope in scopes) {
      final run = _runs[scope];
      if (run != null) _finish(run, completed: false, silent: true);
      _dismissed.remove(scope);
      steps.removeWhere((k, v) {
        final hit = v.scope == scope;
        if (hit) delta.steps.add(k);
        return hit;
      });
      final rec = scopeRecs[scope] ?? ScopeRecord(scope: scope);
      scopeRecs[scope] =
          rec.copyWith(resetAt: now, updatedAt: now, clearCompleted: true);
      delta.scopes.add(scope);
      _emit(DolphinEvent(DolphinEventType.reset, scope: scope));
    }
    _local = _local.copyWith(steps: steps, scopes: scopeRecs, updatedAt: now);
    _effectiveCache = null;
    _queueSave(delta);
    _progressChanged();
    if (restart) _scheduleEvaluate();
  }

  /// Forgets individual steps of a page.
  Future<void> resetSteps(String scope, Iterable<String> stepIds) async {
    await init();
    _clearSteps(scope, stepIds);
    _dismissed.remove(scope);
    _scheduleEvaluate();
  }

  /// Forgets a journey's position (its steps stay seen).
  Future<void> resetJourney(String id) async {
    await init();
    if (_journeyId == id) _journeyId = null;
    final j = Map.of(_local.journeys)..remove(id);
    _local = _local.copyWith(journeys: j, updatedAt: DateTime.now().toUtc());
    _effectiveCache = null;
    _queueSave(ProgressDelta(journeys: {id}));
    _progressChanged();
  }

  /// Shows a page again from the first step without forgetting progress.
  Future<bool> replay(String scope) => start(scope, replay: true);

  // ---------------------------------------------------------------------------
  // Progress queries & sync
  // ---------------------------------------------------------------------------

  /// Ordered step ids that apply to [scope] right now.
  List<String> stepsOf(String scope) =>
      _plan(scope).map((e) => e.step.id).toList();

  bool isSeen(String scope, String stepId) =>
      progress.step(scope, stepId)?.isDone ?? false;

  List<String> pendingSteps(String scope) => [
        for (final i in _plan(scope))
          if (!_isDone(scope, i.step)) i.step.id
      ];

  bool hasPending(String scope) => pendingSteps(scope).isNotEmpty;

  ScopeStatus scopeStatus(String scope) {
    final ids = _reportIds(scope, _plan(scope));
    return progress.scopeStatus(scope, stepIds: ids.isEmpty ? null : ids);
  }

  /// Steps to report for a page: the current plan plus steps remembered from
  /// its last run (inline targets are unknown while the page is closed).
  List<String> _reportIds(String scope, List<_PlanItem> plan) {
    final ids = plan.map((e) => e.step.id).toList();
    final excluded = <String>{
      ...?_scopeConfig(scope)?.exclude,
      ...?_excludes[scope],
    };
    for (final id in progress.scopes[scope]?.knownSteps ?? const <String>[]) {
      if (!ids.contains(id) && !excluded.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// Seen / pending / status of one page.
  ScopeSummary summary(String scope) {
    final plan = _plan(scope);
    final ids = _reportIds(scope, plan);
    final seen = <String>[], pending = <String>[];
    for (final id in ids) {
      final s = plan.where((p) => p.step.id == id).firstOrNull?.step ??
          DolphinStep(id: id);
      (_isDone(scope, s) ? seen : pending).add(id);
    }
    return ScopeSummary(
      scope: scope,
      status: progress.scopeStatus(scope, stepIds: ids.isEmpty ? null : ids),
      stepIds: ids,
      seen: seen,
      pending: pending,
      completedAt: progress.scopes[scope]?.completedAt,
    );
  }

  /// Every page known from config, mounted widgets or stored progress.
  Map<String, ScopeSummary> summaries() {
    final ids = <String>{
      ..._config.scopes.keys,
      ..._scopes.keys,
      ..._targets.values.expand((l) => l).map((h) => h.scope),
      ...progress.scopes.keys,
      ...progress.steps.values.map((s) => s.scope),
    };
    return {for (final id in ids) id: summary(id)};
  }

  /// Progress as JSON for your DB or server.
  Map<String, dynamic> exportProgress() => progress.toJson();

  /// Brings in progress fetched from your server (e.g. after a device change,
  /// so the user only sees what they have not seen yet).
  ///
  /// * [useProvidedData] false: ignore [data] and keep working from local
  ///   storage.
  /// * [updateLocal] true: write the merged result to local storage.
  ///   false: use it for this session only.
  /// * [strategy]: how remote and local combine.
  Future<DolphinProgress> importProgress(
    Map<String, dynamic>? data, {
    bool useProvidedData = true,
    bool updateLocal = true,
    MergeStrategy strategy = MergeStrategy.union,
  }) async {
    await init();
    if (!useProvidedData || data == null) return progress;
    late final DolphinProgress remote;
    try {
      remote = DolphinProgress.fromJson(data);
    } catch (e, s) {
      _error(e, s);
      return progress;
    }
    if (updateLocal) {
      _local = _local.merge(remote, strategy: strategy);
      _overlayProgress = null;
      _queueSave(ProgressDelta.full());
    } else {
      _overlayProgress = remote;
      _overlayStrategy = strategy;
    }
    _effectiveCache = null;
    _emit(const DolphinEvent(DolphinEventType.progressImported));
    _progressChanged(notifyStore: false);
    _scheduleEvaluate();
    return progress;
  }

  /// Fetches remote progress, merges it, and pushes the merged result back.
  Future<DolphinProgress> syncWithServer({
    required Future<Map<String, dynamic>?> Function() fetch,
    Future<void> Function(Map<String, dynamic> merged)? push,
    MergeStrategy strategy = MergeStrategy.union,
  }) async {
    try {
      final remote = await fetch();
      await importProgress(remote, strategy: strategy);
      await push?.call(exportProgress());
    } catch (e, s) {
      _error(e, s);
    }
    return progress;
  }

  // ---------------------------------------------------------------------------
  // Internals: planning
  // ---------------------------------------------------------------------------

  ScopeConfig? _scopeConfig(String scope) => _config.scopes[scope];

  ScopeConfig? _inlineScopeConfig(String scope) {
    final list = _scopes[scope];
    if (list == null || list.isEmpty) return null;
    ScopeConfig? merged;
    for (final h in list) {
      merged = merged == null ? h.inlineConfig : merged.merge(h.inlineConfig);
    }
    return merged;
  }

  bool _hasContent(DolphinStep s) =>
      s.title != null ||
      s.description != null ||
      s.tooltipBuilder != null ||
      s.imageAsset != null ||
      s.imageUrl != null ||
      s.extra.isNotEmpty ||
      s.theme?.tooltipStyle != null;

  List<_PlanItem> _plan(String scope, {List<String>? only}) {
    final central = _scopeConfig(scope);
    final inlineScope = _inlineScopeConfig(scope);
    final natural = <String>[];
    final inlineData = <String, DolphinStep>{};
    void addId(String id) {
      if (!natural.contains(id)) natural.add(id);
    }

    central?.steps.keys.forEach(addId);
    inlineScope?.steps.forEach((id, s) {
      addId(id);
      inlineData[id] = s;
    });
    final handles = _targets.values
        .expand((l) => l)
        .where((h) => h.scope == scope)
        .toList()
      ..sort((a, b) => a.serial.compareTo(b.serial));
    for (final h in handles) {
      addId(h.id);
      if (h.inline != null) {
        inlineData[h.id] = inlineData[h.id]?.merge(h.inline) ?? h.inline!;
      }
    }

    final data = <String, DolphinStep>{};
    for (final id in natural) {
      final c = central?.steps[id];
      final i = inlineData[id];
      DolphinStep s;
      if (c == null) {
        s = i ?? DolphinStep(id: id);
      } else if (i == null) {
        s = c;
      } else {
        s = dataPrecedence == DataPrecedence.centralWins
            ? i.merge(c)
            : c.merge(i);
      }
      if (!_hasContent(s)) {
        _log('$scope/$id has no content in config or inline; ignored');
      } else if (_conditionOk(s)) {
        data[id] = s;
      }
    }

    var ids = data.keys.toList();
    final naturalIndex = {for (var k = 0; k < ids.length; k++) ids[k]: k};
    ids.sort((a, b) {
      final oa = data[a]!.order, ob = data[b]!.order;
      final ka = oa ?? 1000000 + naturalIndex[a]!;
      final kb = ob ?? 1000000 + naturalIndex[b]!;
      return ka.compareTo(kb);
    });

    final seq = _sequences[scope] ?? inlineScope?.sequence ?? central?.sequence;
    if (seq != null) {
      final listed = seq.where(data.containsKey).toList();
      ids = [...listed, ...ids.where((x) => !listed.contains(x))];
    }
    final excluded = <String>{
      ...?central?.exclude,
      ...?inlineScope?.exclude,
      ...?_excludes[scope],
    };
    ids.removeWhere(excluded.contains);
    if (only != null) {
      ids = only.where(ids.contains).toList();
    }

    return [
      for (final id in ids)
        _PlanItem(
          data[id]!,
          counted: _targets.containsKey(stepKey(scope, id)) ||
              data[id]!.fallbackRect != null ||
              (data[id]!.missingTarget ?? missingTarget) ==
                  MissingTargetBehavior.showCentered ||
              (data[id]!.waitForTarget ?? Duration.zero) > Duration.zero,
        )
    ];
  }

  /// Fully merged look for a step.
  /// The theme a step is drawn with: fallback, app, central config, page and
  /// step themes, in that order. In dark mode each level's `dark` overrides
  /// are applied right after that level, so a step's own colours still beat
  /// the app's dark defaults.
  DolphinTheme resolveTheme(String scope, DolphinStep step,
      {bool isDark = false}) {
    final layers = <DolphinTheme?>[
      DolphinTheme.fallback,
      if (isDark) DolphinTheme.fallbackDark,
      theme,
      if (isDark) darkTheme,
      _config.theme,
      _scopeConfig(scope)?.theme,
      _inlineScopeConfig(scope)?.theme,
      step.theme,
    ];
    var t = const DolphinTheme();
    for (final layer in layers) {
      if (layer == null) continue;
      t = t.merge(layer);
      if (isDark && layer.dark != null) t = t.merge(layer.dark);
    }
    return t;
  }

  bool _conditionOk(DolphinStep s) {
    try {
      if (s.condition != null && !s.condition!()) return false;
      final key = s.conditionKey;
      if (key != null) {
        final c = _conditions[key];
        if (c == null) {
          _log('condition "$key" is not registered; step ${s.id} shown');
        } else if (!c()) {
          return false;
        }
      }
      return true;
    } catch (e, s2) {
      _error(e, s2);
      return false;
    }
  }

  bool _isDone(String scope, DolphinStep s) {
    final r = progress.step(scope, s.id);
    return r != null && r.isDone && r.version >= (s.version ?? 0);
  }

  // ---------------------------------------------------------------------------
  // Internals: progress writes
  // ---------------------------------------------------------------------------

  void _markDone(String scope, DolphinStep step, StepStatus status) {
    final now = DateTime.now().toUtc();
    final rec = StepRecord(
        scope: scope,
        step: step.id,
        status: status,
        version: step.version ?? 0,
        updatedAt: now);
    _local =
        _local.copyWith(steps: {..._local.steps, rec.key: rec}, updatedAt: now);
    _effectiveCache = null;
    _queueSave(ProgressDelta(steps: {rec.key}));
    _progressChanged();
  }

  void _clearSteps(String scope, Iterable<String> ids) {
    final steps = Map.of(_local.steps);
    final delta = ProgressDelta();
    for (final id in ids) {
      final k = stepKey(scope, id);
      if (steps.remove(k) != null) delta.steps.add(k);
    }
    final rec = _local.scopes[scope];
    final scopes = Map.of(_local.scopes);
    if (rec?.completedAt != null) {
      scopes[scope] = rec!
          .copyWith(clearCompleted: true, updatedAt: DateTime.now().toUtc());
      delta.scopes.add(scope);
    }
    _local = _local.copyWith(
        steps: steps, scopes: scopes, updatedAt: DateTime.now().toUtc());
    // Also hide the steps from a session-only import.
    final o = _overlayProgress;
    if (o != null) {
      final os = Map.of(o.steps)
        ..removeWhere((k, v) => v.scope == scope && ids.contains(v.step));
      _overlayProgress = o.copyWith(steps: os);
    }
    _effectiveCache = null;
    _queueSave(delta);
    _progressChanged();
  }

  void _rememberKnownSteps(String scope, List<_PlanItem> items) {
    if (items.isEmpty) return;
    final ids = items.map((e) => e.step.id).toList();
    final existing = _local.scopes[scope];
    if (existing != null && listEquals(existing.knownSteps, ids)) return;
    _updateScopeRecord(scope, knownSteps: ids);
  }

  void _updateScopeRecord(String scope,
      {List<String>? knownSteps, String? lastStepId, DateTime? completedAt}) {
    final now = DateTime.now().toUtc();
    final rec = (_local.scopes[scope] ?? ScopeRecord(scope: scope)).copyWith(
        knownSteps: knownSteps,
        lastStepId: lastStepId,
        completedAt: completedAt,
        updatedAt: now);
    _local =
        _local.copyWith(scopes: {..._local.scopes, scope: rec}, updatedAt: now);
    _effectiveCache = null;
    _queueSave(ProgressDelta(scopes: {scope}));
    _progressChanged();
  }

  void _writeJourney(JourneyRecord rec) {
    _local = _local.copyWith(
        journeys: {..._local.journeys, rec.id: rec},
        updatedAt: DateTime.now().toUtc());
    _effectiveCache = null;
    _queueSave(ProgressDelta(journeys: {rec.id}));
    _progressChanged();
  }

  void _queueSave(ProgressDelta delta) {
    final pending = _pendingDelta;
    if (pending != null) {
      pending.addAll(delta);
      return;
    }
    _pendingDelta = delta;
    _saveChain = _saveChain.then((_) async {
      await Future<void>.microtask(() {});
      final d = _pendingDelta;
      _pendingDelta = null;
      if (d == null || d.isEmpty || _disposed) return;
      try {
        await store.saveProgress(_local, d);
      } catch (e, s) {
        _error(e, s);
      }
    });
  }

  Future<void> _setFlag(String key, Object? value) async {
    try {
      await init();
      await store.setFlag(key, value);
    } catch (e, s) {
      _error(e, s);
    }
  }

  void _progressChanged({bool notifyStore = true}) {
    if (_disposed) return;
    final p = progress;
    _progressNotifier.value = p;
    if (notifyStore || _ready) {
      try {
        onProgressChanged?.call(p);
      } catch (e, s) {
        _error(e, s);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internals: auto start / evaluation
  // ---------------------------------------------------------------------------

  bool _isScopeVisible(String scope) =>
      (_scopes[scope] ?? const []).any((h) => h.mounted && h.isVisible);

  void _scheduleEvaluate() {
    if (_evaluateScheduled || _disposed) return;
    _evaluateScheduled = true;
    _postFrame(() {
      _evaluateScheduled = false;
      _evaluate();
    });
  }

  void _evaluate() {
    if (_disposed || !_ready || _active != null) return;

    // 1. Resume a paused page that is visible again.
    for (final run in _runs.values.toList()) {
      if (run.paused && _isScopeVisible(run.scope)) {
        resume(run.scope);
        return;
      }
    }

    // 2. A running journey whose current leg is on screen.
    final jid = _journeyId;
    if (jid != null) {
      final j = journeyById(jid);
      final leg = progress.journeys[jid]?.legIndex ?? 0;
      if (j != null &&
          leg < j.legs.length &&
          _isScopeVisible(j.legs[leg].scope)) {
        final scope = j.legs[leg].scope;
        _scheduleStart(scope, () async {
          final ok = await _start(scope,
              only: j.legs[leg].steps, journeyId: jid, legIndex: leg);
          if (!ok && _journeyId == jid) _completeLeg(jid, leg);
        });
        return;
      }
    }

    // 3. Auto-start visible pages with pending steps.
    if (!enabled) return;
    for (final entry in _scopes.entries) {
      final scope = entry.key;
      if (_dismissed.contains(scope) || !isScopeEnabled(scope)) continue;
      if (!_isScopeVisible(scope)) continue;
      final auto = _inlineScopeConfig(scope)?.autoStart ??
          _scopeConfig(scope)?.autoStart ??
          autoStart;
      if (!auto || !hasPending(scope)) continue;
      _scheduleStart(scope, () => _start(scope, ignoreDisabled: false));
      return;
    }
  }

  void _scheduleStart(String scope, Future<void> Function() run) {
    if (_startTimers.containsKey(scope)) return;
    final delay = _inlineScopeConfig(scope)?.startDelay ??
        _scopeConfig(scope)?.startDelay ??
        startDelay;
    _startTimers[scope] = Timer(delay, () {
      _startTimers.remove(scope);
      if (_disposed || _active != null || !_isScopeVisible(scope)) {
        _scheduleEvaluate();
        return;
      }
      run();
    });
  }

  // ---------------------------------------------------------------------------
  // Internals: overlay & misc
  // ---------------------------------------------------------------------------

  void _setActiveStep(ActiveStep? step) {
    _activeStep = step;
    _safeNotify();
  }

  BuildContext? _hostContext(String scope) {
    for (final h in _scopes[scope] ?? const <ScopeHandle>[]) {
      if (h.mounted) return h.context;
    }
    for (final h in _targets.values.expand((l) => l)) {
      if (h.scope == scope && h.context != null) return h.context;
    }
    return navigatorKey?.currentContext;
  }

  BuildContext? _anyContext() {
    for (final l in _scopes.values) {
      for (final h in l) {
        if (h.mounted) return h.context;
      }
    }
    return navigatorKey?.currentContext;
  }

  NavigatorState? _maybeNavigator(BuildContext? context) {
    if (context == null || !context.mounted) return null;
    return Navigator.maybeOf(context, rootNavigator: true);
  }

  RenderBox? _overlayBox(String scope) {
    try {
      final ctx = _hostContext(scope);
      if (ctx == null || !ctx.mounted) return null;
      final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
      final ro = overlay?.context.findRenderObject();
      return ro is RenderBox && ro.attached && ro.hasSize ? ro : null;
    } catch (_) {
      return null;
    }
  }

  void _ensureOverlay(String scope) {
    try {
      final ctx = _hostContext(scope);
      if (ctx == null || !ctx.mounted) return;
      final overlay = Overlay.maybeOf(ctx, rootOverlay: true);
      if (overlay == null) {
        _log('no Overlay found above scope $scope');
        return;
      }
      if (_entry != null &&
          identical(_entryOverlay, overlay) &&
          _entry!.mounted) {
        return;
      }
      _removeEntry();
      final entry =
          OverlayEntry(builder: (_) => DolphinOverlay(controller: this));
      _entry = entry;
      _entryOverlay = overlay;
      overlay.insert(entry);
    } catch (e, s) {
      _error(e, s);
    }
  }

  void _removeEntry() {
    final e = _entry;
    _entry = null;
    _entryOverlay = null;
    if (e == null) return;
    try {
      if (e.mounted) e.remove();
      e.dispose();
    } catch (_) {
      // Removing during a locked frame: retry after it.
      _postFrame(() {
        try {
          if (e.mounted) e.remove();
          e.dispose();
        } catch (_) {}
      });
    }
  }

  void _postFrame(VoidCallback cb) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) cb();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> _nextFrame() {
    final c = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) => c.complete());
    SchedulerBinding.instance.ensureVisualUpdate();
    return c.future;
  }

  void _safeNotify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      // Never call listeners during build/layout.
      _postFrame(notifyListeners);
    } else {
      notifyListeners();
    }
  }

  void _emit(DolphinEvent e) {
    _log(e.toString());
    try {
      onEvent?.call(e);
    } catch (err, s) {
      _error(err, s);
    }
    if (!_events.isClosed) _events.add(e);
  }

  void _error(Object e, StackTrace s) {
    if (onError != null) {
      onError!(e, s);
    } else {
      debugPrint('dolphin error: $e');
    }
  }

  void _log(String msg) {
    if (debugLogging) debugPrint('dolphin: $msg');
  }
}
