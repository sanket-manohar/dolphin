import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/json_utils.dart';
import '../ui/dolphin_theme.dart';
import 'dolphin_step.dart';

/// Configuration of one scope (usually one page / screen).
@immutable
class ScopeConfig {
  const ScopeConfig({
    required this.id,
    this.steps = const {},
    this.sequence,
    this.exclude = const {},
    this.autoStart,
    this.enabled,
    this.startDelay,
    this.theme,
  });

  final String id;

  /// Step data by step id. Insertion order is the default sequence.
  final Map<String, DolphinStep> steps;

  /// Explicit order of step ids. Steps not listed keep their natural order
  /// after the listed ones.
  final List<String>? sequence;

  /// Step ids that must never be shown.
  final Set<String> exclude;
  final bool? autoStart;
  final bool? enabled;

  /// Delay before an automatic start (lets page animations settle).
  final Duration? startDelay;
  final DolphinTheme? theme;

  ScopeConfig copyWith({
    Map<String, DolphinStep>? steps,
    List<String>? sequence,
    bool clearSequence = false,
    Set<String>? exclude,
    bool? autoStart,
    bool? enabled,
    Duration? startDelay,
    DolphinTheme? theme,
  }) =>
      ScopeConfig(
        id: id,
        steps: steps ?? this.steps,
        sequence: clearSequence ? null : (sequence ?? this.sequence),
        exclude: exclude ?? this.exclude,
        autoStart: autoStart ?? this.autoStart,
        enabled: enabled ?? this.enabled,
        startDelay: startDelay ?? this.startDelay,
        theme: theme ?? this.theme,
      );

  /// [other] wins where it sets something.
  ScopeConfig merge(ScopeConfig? other) {
    if (other == null) return this;
    final merged = <String, DolphinStep>{...steps};
    other.steps.forEach((k, v) => merged[k] = merged[k]?.merge(v) ?? v);
    return ScopeConfig(
      id: id,
      steps: merged,
      sequence: other.sequence ?? sequence,
      exclude: {...exclude, ...other.exclude},
      autoStart: other.autoStart ?? autoStart,
      enabled: other.enabled ?? enabled,
      startDelay: other.startDelay ?? startDelay,
      theme: (theme ?? const DolphinTheme()).merge(other.theme),
    );
  }

  factory ScopeConfig.fromJson(String id, Map<String, dynamic> json) {
    final steps = <String, DolphinStep>{};
    final raw = json['steps'];
    if (raw is List) {
      for (final s in raw) {
        final m = WJson.map(s);
        if (m != null && m['id'] != null) {
          final step = DolphinStep.fromJson(m);
          steps[step.id] = step;
        }
      }
    } else if (raw is Map) {
      WJson.map(raw)!.forEach((k, v) {
        final m = WJson.map(v);
        if (m != null) steps[k] = DolphinStep.fromJson(m, id: k);
      });
    }
    return ScopeConfig(
      id: id,
      steps: steps,
      sequence: WJson.strList(json['sequence'] ?? json['order']),
      exclude: (WJson.strList(json['exclude']) ?? const []).toSet(),
      autoStart: WJson.boolean(json['autoStart']),
      enabled: WJson.boolean(json['enabled']),
      startDelay: WJson.millis(json['startDelayMs']),
      theme: DolphinTheme.fromJson(json['theme']),
    );
  }
}

/// One leg of a cross-page [DolphinJourney]: show [steps] (or every
/// pending step) of [scope], then move to the next leg.
@immutable
class JourneyLeg {
  const JourneyLeg({
    required this.scope,
    this.steps,
    this.route,
    this.arguments,
  });

  final String scope;
  final List<String>? steps;

  /// Named route that opens this leg's page. Used by the default navigator.
  final String? route;
  final Object? arguments;

  factory JourneyLeg.fromJson(Map<String, dynamic> json) => JourneyLeg(
        scope: json['scope'].toString(),
        steps: WJson.strList(json['steps']),
        route: WJson.str(json['route']),
        arguments: json['arguments'],
      );
}

/// A guided path across several pages, e.g. 5 steps on page 4, then open
/// page 8 and show 3 steps there, and so on.
@immutable
class DolphinJourney {
  const DolphinJourney({required this.id, required this.legs});

  final String id;
  final List<JourneyLeg> legs;

  factory DolphinJourney.fromJson(String id, Object? json) {
    final legsRaw = json is List ? json : WJson.map(json)?['legs'];
    final legs = <JourneyLeg>[];
    if (legsRaw is List) {
      for (final l in legsRaw) {
        final m = WJson.map(l);
        if (m != null && m['scope'] != null) legs.add(JourneyLeg.fromJson(m));
      }
    }
    return DolphinJourney(id: id, legs: legs);
  }
}

/// The single source of truth for walkthrough content, usually loaded from a
/// JSON asset or your server. Widgets only need to carry an id.
///
/// ```json
/// {
///   "theme": { "barrierColor": "#B3000000" },
///   "scopes": {
///     "home": {
///       "sequence": ["search", "add"],
///       "steps": {
///         "search": { "title": "Search", "description": "Find anything", "shape": "circle" },
///         "add":    { "title": "Add", "description": "Create an item", "pointerX": 0.8 }
///       }
///     }
///   },
///   "journeys": {
///     "onboarding": [ { "scope": "page4", "steps": ["a","b"] },
///                     { "scope": "page8", "route": "/page8" } ]
///   }
/// }
/// ```
@immutable
class DolphinConfig {
  const DolphinConfig({
    this.scopes = const {},
    this.journeys = const {},
    this.theme,
    this.version,
  });

  static const empty = DolphinConfig();

  final Map<String, ScopeConfig> scopes;
  final Map<String, DolphinJourney> journeys;
  final DolphinTheme? theme;
  final int? version;

  /// [other] wins where it sets something; scopes and steps merge deeply.
  DolphinConfig merge(DolphinConfig? other) {
    if (other == null) return this;
    final s = <String, ScopeConfig>{...scopes};
    other.scopes.forEach((k, v) => s[k] = s[k]?.merge(v) ?? v);
    return DolphinConfig(
      scopes: s,
      journeys: {...journeys, ...other.journeys},
      theme: (theme ?? const DolphinTheme()).merge(other.theme),
      version: other.version ?? version,
    );
  }

  factory DolphinConfig.fromJson(Map<String, dynamic> json) {
    final scopes = <String, ScopeConfig>{};
    final raw = WJson.map(json['scopes'] ?? json['pages']) ?? const {};
    raw.forEach((k, v) {
      final m = WJson.map(v);
      if (m != null) scopes[k] = ScopeConfig.fromJson(k, m);
    });
    final journeys = <String, DolphinJourney>{};
    (WJson.map(json['journeys']) ?? const {}).forEach((k, v) {
      journeys[k] = DolphinJourney.fromJson(k, v);
    });
    return DolphinConfig(
      scopes: scopes,
      journeys: journeys,
      theme: DolphinTheme.fromJson(json['theme']),
      version: WJson.integer(json['version']),
    );
  }

  /// Parses a JSON string. Invalid JSON yields an empty config (and is
  /// reported through [onError]) rather than throwing.
  static DolphinConfig fromJsonString(String source,
      {void Function(Object error)? onError}) {
    try {
      final decoded = jsonDecode(source);
      final m = WJson.map(decoded);
      if (m == null) return empty;
      return DolphinConfig.fromJson(m);
    } catch (e) {
      onError?.call(e);
      return empty;
    }
  }
}
