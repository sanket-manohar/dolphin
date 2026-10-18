import 'package:flutter/widgets.dart';

import '../core/json_utils.dart';
import '../ui/dolphin_theme.dart';

/// Rectangle expressed as fractions of the screen (0..1). Used as a last
/// resort when a target cannot be measured, e.g.
/// `FractionalRect(x: 0.85, y: 0.04, width: 0.12, height: 0.06)`.
@immutable
class FractionalRect {
  const FractionalRect(
      {required this.x, required this.y, this.width = 0, this.height = 0});

  final double x, y, width, height;

  Rect resolve(Size size) => Rect.fromLTWH(
        x * size.width,
        y * size.height,
        width * size.width,
        height * size.height,
      );

  static FractionalRect? fromJson(Object? json) {
    final m = WJson.map(json);
    if (m == null) return null;
    final x = WJson.dbl(m['x']), y = WJson.dbl(m['y']);
    if (x == null || y == null) return null;
    return FractionalRect(
      x: x,
      y: y,
      width: WJson.dbl(m['width'] ?? m['w']) ?? 0,
      height: WJson.dbl(m['height'] ?? m['h']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'width': width, 'height': height};
}

/// What to do when a step's target is missing, unmounted or has no size.
enum MissingTargetBehavior {
  /// Skip it silently (default). It stays unseen so it shows next time.
  skip,

  /// Skip it and mark it seen so it is never retried.
  skipAndMarkSeen,

  /// Show the tooltip centred on screen with no highlight.
  showCentered,
}

/// Content and options of one walkthrough step.
///
/// Every field except [id] is optional so the same class works for inline
/// data (on `DolphinTarget`) and for centralised data (JSON config). The
/// two are merged field by field; see `DataPrecedence`.
@immutable
class DolphinStep {
  const DolphinStep({
    required this.id,
    this.title,
    this.description,
    this.imageAsset,
    this.imageUrl,
    this.extra = const {},
    this.order,
    this.version,
    this.theme,
    this.tooltipBuilder,
    this.pointerMode,
    this.pointerX,
    this.pointerOffset,
    this.fallbackRect,
    this.missingTarget,
    this.counterText,
    this.autoAdvanceAfter,
    this.scrollIntoView,
    this.waitForTarget,
    this.conditionKey,
    this.condition,
    this.semanticsLabel,
  });

  /// Unique inside its scope (page).
  final String id;
  final String? title;
  final String? description;
  final String? imageAsset;
  final String? imageUrl;

  /// Free-form data for custom tooltip builders (e.g. a lottie name, a CTA).
  final Map<String, dynamic> extra;

  /// Position in the scope when no explicit sequence is configured.
  final int? order;

  /// Bump this when the content changes; users who saw an older version will
  /// see the step again.
  final int? version;

  /// Per-step look & behaviour overrides.
  final DolphinTheme? theme;

  /// Inline custom tooltip. Wins over every preset.
  final DolphinTooltipBuilder? tooltipBuilder;

  final PointerMode? pointerMode;

  /// Manual pointer position along the tooltip edge, 0 = start, 1 = end.
  /// Used when [pointerMode] is manual, or as backup when measuring fails.
  final double? pointerX;

  /// Manual pointer position in logical pixels from the tooltip's start edge.
  /// Takes precedence over [pointerX].
  final double? pointerOffset;

  /// Where the target is assumed to be when it cannot be measured.
  final FractionalRect? fallbackRect;
  final MissingTargetBehavior? missingTarget;

  /// Replaces the automatic "1/3" text for this step.
  final String? counterText;

  /// Moves on automatically after this delay.
  final Duration? autoAdvanceAfter;
  final bool? scrollIntoView;

  /// How long to wait for a target that is not mounted yet.
  final Duration? waitForTarget;

  /// Name of a condition registered with `controller.registerCondition`.
  /// Lets JSON config gate a step ("isPremium", "hasCart" ...).
  final String? conditionKey;

  /// Inline condition; the step is skipped (not marked) while it returns false.
  final bool Function()? condition;
  final String? semanticsLabel;

  /// Field-by-field merge: non-null values of [other] win.
  DolphinStep merge(DolphinStep? other) {
    if (other == null) return this;
    return DolphinStep(
      id: id,
      title: other.title ?? title,
      description: other.description ?? description,
      imageAsset: other.imageAsset ?? imageAsset,
      imageUrl: other.imageUrl ?? imageUrl,
      extra: {...extra, ...other.extra},
      order: other.order ?? order,
      version: other.version ?? version,
      theme: (theme ?? const DolphinTheme()).merge(other.theme),
      tooltipBuilder: other.tooltipBuilder ?? tooltipBuilder,
      pointerMode: other.pointerMode ?? pointerMode,
      pointerX: other.pointerX ?? pointerX,
      pointerOffset: other.pointerOffset ?? pointerOffset,
      fallbackRect: other.fallbackRect ?? fallbackRect,
      missingTarget: other.missingTarget ?? missingTarget,
      counterText: other.counterText ?? counterText,
      autoAdvanceAfter: other.autoAdvanceAfter ?? autoAdvanceAfter,
      scrollIntoView: other.scrollIntoView ?? scrollIntoView,
      waitForTarget: other.waitForTarget ?? waitForTarget,
      conditionKey: other.conditionKey ?? conditionKey,
      condition: other.condition ?? condition,
      semanticsLabel: other.semanticsLabel ?? semanticsLabel,
    );
  }

  /// Reads one step from JSON. Unknown keys go into [extra].
  factory DolphinStep.fromJson(Map<String, dynamic> json, {String? id}) {
    const known = {
      'id', 'title', 'description', 'imageAsset', 'imageUrl', 'extra',
      'order', 'version', 'theme', 'pointerMode', 'pointerX', 'pointerOffset',
      'fallbackRect', 'missingTarget', 'counterText', 'autoAdvanceMs',
      'scrollIntoView', 'waitForTargetMs', 'condition', 'semanticsLabel',
      // Shortcuts for theme keys:
      'position', 'targetTap', 'barrierTap',
    };
    final shortcuts = <String, dynamic>{
      if (json['position'] != null) 'tooltipPosition': json['position'],
      if (json['targetTap'] != null) 'targetTapBehavior': json['targetTap'],
      if (json['barrierTap'] != null) 'barrierTapBehavior': json['barrierTap'],
      for (final e in json.entries)
        if (DolphinTheme.jsonKeys.contains(e.key)) e.key: e.value,
    };
    final themeJson = {...shortcuts, ...?WJson.map(json['theme'])};
    return DolphinStep(
      id: id ?? json['id'].toString(),
      title: WJson.str(json['title']),
      description: WJson.str(json['description']),
      imageAsset: WJson.str(json['imageAsset']),
      imageUrl: WJson.str(json['imageUrl']),
      extra: {
        for (final e in json.entries)
          if (!known.contains(e.key) && !DolphinTheme.jsonKeys.contains(e.key))
            e.key: e.value,
        ...?WJson.map(json['extra']),
      },
      order: WJson.integer(json['order']),
      version: WJson.integer(json['version']),
      theme: themeJson.isEmpty ? null : DolphinTheme.fromJson(themeJson),
      pointerMode: WJson.enumByName(PointerMode.values, json['pointerMode']),
      pointerX: WJson.dbl(json['pointerX']),
      pointerOffset: WJson.dbl(json['pointerOffset']),
      fallbackRect: FractionalRect.fromJson(json['fallbackRect']),
      missingTarget:
          WJson.enumByName(MissingTargetBehavior.values, json['missingTarget']),
      counterText: WJson.str(json['counterText']),
      autoAdvanceAfter: WJson.millis(json['autoAdvanceMs']),
      scrollIntoView: WJson.boolean(json['scrollIntoView']),
      waitForTarget: WJson.millis(json['waitForTargetMs']),
      conditionKey: WJson.str(json['condition']),
      semanticsLabel: WJson.str(json['semanticsLabel']),
    );
  }
}

/// Everything a custom tooltip needs: the step, its position in the
/// sequence and the actions.
class DolphinTooltipContext {
  DolphinTooltipContext({
    required this.step,
    required this.scopeId,
    required this.index,
    required this.total,
    required this.counterText,
    required this.theme,
    required this.isFirst,
    required this.isLast,
    required this.next,
    required this.previous,
    required this.skipScope,
    required this.dismiss,
  });

  final DolphinStep step;
  final String scopeId;

  /// 1-based position of this step.
  final int index;
  final int total;

  /// Already formatted counter ("2/5", or the step's counterText).
  final String counterText;

  /// Fully resolved theme for this step.
  final DolphinTheme theme;
  final bool isFirst;
  final bool isLast;
  final VoidCallback next;
  final VoidCallback previous;

  /// Marks the remaining steps of this page only as seen and closes.
  final VoidCallback skipScope;

  /// Closes without marking anything; the step shows again next time.
  final VoidCallback dismiss;
}

typedef DolphinTooltipBuilder = Widget Function(
    BuildContext context, DolphinTooltipContext tooltip);
