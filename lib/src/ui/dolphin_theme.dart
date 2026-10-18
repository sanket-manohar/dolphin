import 'package:flutter/material.dart';

import '../core/json_utils.dart';
import 'highlight_shape.dart';
import 'pointer_style.dart';

/// Ready-made tooltip designs. Use [DolphinTheme.tooltipStyle] with one of
/// these names, or register your own builder under any name with
/// `DolphinController.registerTooltipBuilder`.
enum TooltipPreset {
  /// White card with title, description, counter and buttons.
  card,

  /// Coloured speech bubble using the primary colour.
  bubble,

  /// Text only, drawn straight on the dark barrier. Tap anywhere to continue.
  minimal,

  /// Full-width panel pinned to the top or bottom of the screen.
  banner,

  /// Frosted, translucent glass card.
  glass,

  /// One-line chip with a next arrow.
  compact,
}

/// Where the tooltip sits relative to its target.
enum TooltipPosition { auto, above, below, left, right, center }

/// How the pointer's position along the tooltip edge is decided.
enum PointerMode {
  /// Measured from the target's RenderBox (default). If measuring fails, the
  /// manual value is used, then the tooltip centre.
  auto,

  /// Always use the manual `pointerX` / `pointerOffset` from the step data.
  manual,
}

/// What a tap inside the highlighted hole does.
enum TargetTapBehavior {
  /// Moves to the next step. The target itself does not receive the tap.
  advance,

  /// The target receives the tap; the walkthrough stays on this step.
  passThrough,

  /// The target receives the tap and the step is marked seen. If the tap
  /// navigates to another page, the walkthrough pauses and resumes from the
  /// next step when the user comes back.
  passThroughAndAdvance,

  /// Nothing happens.
  block,
}

/// What a tap on the dark barrier does.
enum BarrierTapBehavior { none, next, dismiss, skipScope }

/// What the Android back button / predictive back does while visible.
enum BackButtonBehavior { dismiss, previous, block, passThrough }

/// How the tooltip enters.
enum TooltipTransition { none, fade, scale, slide }

@immutable
class DolphinAnimation {
  const DolphinAnimation({
    this.enabled = true,
    this.fadeDuration = const Duration(milliseconds: 250),
    this.moveDuration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.transition = TooltipTransition.scale,
    this.pulse = true,
    this.pulseDuration = const Duration(milliseconds: 1400),
  });

  /// No animation at all.
  const DolphinAnimation.none()
      : this(enabled: false, pulse: false, transition: TooltipTransition.none);

  final bool enabled;
  final Duration fadeDuration;

  /// Duration of the highlight sliding from one target to the next.
  final Duration moveDuration;
  final Curve curve;
  final TooltipTransition transition;

  /// A soft ring that breathes around the target.
  final bool pulse;
  final Duration pulseDuration;

  Duration get effectiveFade => enabled ? fadeDuration : Duration.zero;
  Duration get effectiveMove => enabled ? moveDuration : Duration.zero;

  static DolphinAnimation? fromJson(Object? json) {
    if (json is bool) {
      return json ? const DolphinAnimation() : const DolphinAnimation.none();
    }
    final m = WJson.map(json);
    if (m == null) return null;
    const d = DolphinAnimation();
    return DolphinAnimation(
      enabled: WJson.boolean(m['enabled']) ?? d.enabled,
      fadeDuration: WJson.millis(m['fadeMs']) ?? d.fadeDuration,
      moveDuration: WJson.millis(m['moveMs']) ?? d.moveDuration,
      transition: WJson.enumByName(TooltipTransition.values, m['transition']) ??
          d.transition,
      pulse: WJson.boolean(m['pulse']) ?? d.pulse,
      pulseDuration: WJson.millis(m['pulseMs']) ?? d.pulseDuration,
    );
  }
}

/// Builds the "1/3" counter. Return any widget.
typedef CounterBuilder = Widget Function(
    BuildContext context, int current, int total);

/// Which theme the overlay uses.
enum DolphinThemeMode {
  /// Follow the app: dark when `Theme.of(context)` is dark (this already
  /// honours `MaterialApp.themeMode`). The default.
  app,

  /// Follow the phone's light / dark setting, whatever the app does.
  system,

  /// Always the light theme.
  light,

  /// Always the dark theme.
  dark,
}

/// Every visual and behavioural knob of the walkthrough.
///
/// All fields are optional so a theme can be used as a partial override: the
/// controller merges `DolphinTheme.fallback`, then your global theme, then
/// the scope theme, then the step theme (`a.merge(b)`: non-null fields of `b`
/// win).
@immutable
class DolphinTheme {
  const DolphinTheme({
    this.barrierColor,
    this.barrierOpacity,
    this.barrierBlur,
    this.shape,
    this.highlightPadding,
    this.highlightOffset,
    this.highlightBorderColor,
    this.highlightBorderWidth,
    this.highlightBorderDash,
    this.highlightBorderGradient,
    this.highlightGlowColor,
    this.highlightGlowBlur,
    this.pulseColor,
    this.tooltipStyle,
    this.tooltipPosition,
    this.tooltipBackgroundColor,
    this.tooltipForegroundColor,
    this.primaryColor,
    this.tooltipBorderRadius,
    this.tooltipPadding,
    this.tooltipMaxWidth,
    this.tooltipShadow,
    this.screenMargin,
    this.targetGap,
    this.titleStyle,
    this.descriptionStyle,
    this.counterStyle,
    this.buttonTextStyle,
    this.pointer,
    this.counterFormat,
    this.counterBuilder,
    this.showCounter,
    this.showSkip,
    this.showPrevious,
    this.showNext,
    this.nextLabel,
    this.previousLabel,
    this.skipLabel,
    this.finishLabel,
    this.animation,
    this.targetTapBehavior,
    this.barrierTapBehavior,
    this.backButtonBehavior,
    this.respectSafeArea,
    this.dark,
  });

  // Barrier
  final Color? barrierColor;

  /// Overrides the alpha of [barrierColor] (0 = invisible, 1 = solid), so the
  /// opacity can be changed without touching the colour.
  final double? barrierOpacity;

  /// Gaussian blur sigma applied to everything except the target. 0 = none.
  final double? barrierBlur;

  // Highlight
  final HighlightShape? shape;
  final EdgeInsets? highlightPadding;

  /// Moves the hole (and the tooltip with it) by this many pixels.
  final Offset? highlightOffset;
  final Color? highlightBorderColor;
  final double? highlightBorderWidth;

  /// Dash pattern for the border, e.g. `[6, 4]` = 6px dash, 4px gap.
  /// Null or empty draws a solid border.
  final List<double>? highlightBorderDash;

  /// Paints the border with a gradient instead of [highlightBorderColor].
  final Gradient? highlightBorderGradient;
  final Color? highlightGlowColor;
  final double? highlightGlowBlur;
  final Color? pulseColor;

  // Tooltip
  /// A [TooltipPreset] name or the name of a registered custom builder.
  final String? tooltipStyle;
  final TooltipPosition? tooltipPosition;
  final Color? tooltipBackgroundColor;
  final Color? tooltipForegroundColor;
  final Color? primaryColor;
  final double? tooltipBorderRadius;
  final EdgeInsets? tooltipPadding;
  final double? tooltipMaxWidth;
  final List<BoxShadow>? tooltipShadow;

  /// Minimum distance between the tooltip and the screen edges.
  final EdgeInsets? screenMargin;

  /// Extra distance between the highlighted hole and the pointer.
  final double? targetGap;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;
  final TextStyle? counterStyle;
  final TextStyle? buttonTextStyle;
  final PointerStyle? pointer;

  // Counter & buttons
  /// Template for the counter. `{current}` and `{total}` are replaced.
  final String? counterFormat;
  final CounterBuilder? counterBuilder;
  final bool? showCounter;
  final bool? showSkip;
  final bool? showPrevious;
  final bool? showNext;
  final String? nextLabel;
  final String? previousLabel;
  final String? skipLabel;
  final String? finishLabel;

  // Behaviour
  final DolphinAnimation? animation;
  final TargetTapBehavior? targetTapBehavior;
  final BarrierTapBehavior? barrierTapBehavior;
  final BackButtonBehavior? backButtonBehavior;
  final bool? respectSafeArea;

  /// Overrides used in dark mode, on top of this theme. Set it at any level
  /// (app, page, step) or as `"dark": {...}` in JSON.
  final DolphinTheme? dark;

  /// Defaults used when nothing else is set.
  static const DolphinTheme fallback = DolphinTheme(
    barrierColor: Color(0xB3000000),
    barrierBlur: 0,
    shape: HighlightShape.rounded(radius: 12),
    highlightPadding: EdgeInsets.all(6),
    highlightBorderColor: Color(0x00000000),
    highlightBorderWidth: 0,
    highlightGlowColor: Color(0x00000000),
    highlightGlowBlur: 0,
    pulseColor: Color(0x66FFFFFF),
    tooltipStyle: 'card',
    tooltipPosition: TooltipPosition.auto,
    tooltipBackgroundColor: Color(0xFFFFFFFF),
    tooltipForegroundColor: Color(0xFF1C1B1F),
    primaryColor: Color(0xFF3F51B5),
    tooltipBorderRadius: 14,
    tooltipPadding: EdgeInsets.fromLTRB(16, 14, 16, 10),
    tooltipMaxWidth: 340,
    tooltipShadow: [
      BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))
    ],
    screenMargin: EdgeInsets.all(12),
    targetGap: 4,
    pointer: PointerStyle(),
    counterFormat: '{current}/{total}',
    showCounter: true,
    showSkip: true,
    showPrevious: true,
    showNext: true,
    nextLabel: 'Next',
    previousLabel: 'Back',
    skipLabel: 'Skip',
    finishLabel: 'Done',
    animation: DolphinAnimation(),
    targetTapBehavior: TargetTapBehavior.advance,
    barrierTapBehavior: BarrierTapBehavior.none,
    backButtonBehavior: BackButtonBehavior.dismiss,
    respectSafeArea: true,
  );

  /// Dark-mode defaults, applied over [fallback] when the overlay is dark.
  /// Every preset reads its colours from the theme, so this gives each
  /// preset a dark version.
  static const DolphinTheme fallbackDark = DolphinTheme(
    barrierColor: Color(0xCC000000),
    tooltipBackgroundColor: Color(0xFF2B2930),
    tooltipForegroundColor: Color(0xFFE6E1E5),
    primaryColor: Color(0xFF9FA8DA),
    tooltipShadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6))
    ],
    pulseColor: Color(0x55FFFFFF),
  );

  /// This theme with its [dark] overrides applied when [isDark] is true.
  DolphinTheme resolve({required bool isDark}) =>
      isDark && dark != null ? merge(dark) : this;

  /// Builds a theme that follows the app's Material colour scheme.
  factory DolphinTheme.fromMaterial(ThemeData theme) {
    final cs = theme.colorScheme;
    return DolphinTheme(
      tooltipBackgroundColor: cs.surface,
      tooltipForegroundColor: cs.onSurface,
      primaryColor: cs.primary,
      titleStyle: theme.textTheme.titleMedium,
      descriptionStyle: theme.textTheme.bodyMedium,
    );
  }

  /// Returns a copy where every non-null field of [other] wins.
  DolphinTheme merge(DolphinTheme? other) {
    if (other == null) return this;
    return DolphinTheme(
      barrierColor: other.barrierColor ?? barrierColor,
      barrierOpacity: other.barrierOpacity ?? barrierOpacity,
      barrierBlur: other.barrierBlur ?? barrierBlur,
      shape: other.shape ?? shape,
      highlightPadding: other.highlightPadding ?? highlightPadding,
      highlightOffset: other.highlightOffset ?? highlightOffset,
      highlightBorderColor: other.highlightBorderColor ?? highlightBorderColor,
      highlightBorderWidth: other.highlightBorderWidth ?? highlightBorderWidth,
      highlightBorderDash: other.highlightBorderDash ?? highlightBorderDash,
      highlightBorderGradient:
          other.highlightBorderGradient ?? highlightBorderGradient,
      highlightGlowColor: other.highlightGlowColor ?? highlightGlowColor,
      highlightGlowBlur: other.highlightGlowBlur ?? highlightGlowBlur,
      pulseColor: other.pulseColor ?? pulseColor,
      tooltipStyle: other.tooltipStyle ?? tooltipStyle,
      tooltipPosition: other.tooltipPosition ?? tooltipPosition,
      tooltipBackgroundColor:
          other.tooltipBackgroundColor ?? tooltipBackgroundColor,
      tooltipForegroundColor:
          other.tooltipForegroundColor ?? tooltipForegroundColor,
      primaryColor: other.primaryColor ?? primaryColor,
      tooltipBorderRadius: other.tooltipBorderRadius ?? tooltipBorderRadius,
      tooltipPadding: other.tooltipPadding ?? tooltipPadding,
      tooltipMaxWidth: other.tooltipMaxWidth ?? tooltipMaxWidth,
      tooltipShadow: other.tooltipShadow ?? tooltipShadow,
      screenMargin: other.screenMargin ?? screenMargin,
      targetGap: other.targetGap ?? targetGap,
      titleStyle: titleStyle?.merge(other.titleStyle) ?? other.titleStyle,
      descriptionStyle: descriptionStyle?.merge(other.descriptionStyle) ??
          other.descriptionStyle,
      counterStyle:
          counterStyle?.merge(other.counterStyle) ?? other.counterStyle,
      buttonTextStyle: buttonTextStyle?.merge(other.buttonTextStyle) ??
          other.buttonTextStyle,
      pointer: other.pointer ?? pointer,
      counterFormat: other.counterFormat ?? counterFormat,
      counterBuilder: other.counterBuilder ?? counterBuilder,
      showCounter: other.showCounter ?? showCounter,
      showSkip: other.showSkip ?? showSkip,
      showPrevious: other.showPrevious ?? showPrevious,
      showNext: other.showNext ?? showNext,
      nextLabel: other.nextLabel ?? nextLabel,
      previousLabel: other.previousLabel ?? previousLabel,
      skipLabel: other.skipLabel ?? skipLabel,
      finishLabel: other.finishLabel ?? finishLabel,
      animation: other.animation ?? animation,
      targetTapBehavior: other.targetTapBehavior ?? targetTapBehavior,
      barrierTapBehavior: other.barrierTapBehavior ?? barrierTapBehavior,
      backButtonBehavior: other.backButtonBehavior ?? backButtonBehavior,
      respectSafeArea: other.respectSafeArea ?? respectSafeArea,
      dark: dark == null ? other.dark : dark!.merge(other.dark),
    );
  }

  /// Keys understood by [fromJson]. They may also be written directly on a
  /// step in JSON.
  static const jsonKeys = {
    'animation',
    'backButtonBehavior',
    'barrierBlur',
    'barrierColor',
    'barrierOpacity',
    'barrierTapBehavior',
    'buttonTextStyle',
    'counterFormat',
    'counterStyle',
    'dark',
    'descriptionStyle',
    'finishLabel',
    'highlightBorderColor',
    'highlightBorderDash',
    'highlightBorderGradient',
    'highlightBorderWidth',
    'highlightGlowBlur',
    'highlightGlowColor',
    'highlightOffset',
    'highlightPadding',
    'nextLabel',
    'pointer',
    'previousLabel',
    'primaryColor',
    'pulseColor',
    'respectSafeArea',
    'screenMargin',
    'shape',
    'showCounter',
    'showNext',
    'showPrevious',
    'showSkip',
    'skipLabel',
    'targetGap',
    'targetTapBehavior',
    'titleStyle',
    'tooltipBackgroundColor',
    'tooltipBorderRadius',
    'tooltipForegroundColor',
    'tooltipMaxWidth',
    'tooltipPadding',
    'tooltipPosition',
    'tooltipStyle'
  };

  /// Reads a theme override from JSON (central config). Colours are hex
  /// strings, paddings are numbers or lists, enums are their names.
  static DolphinTheme? fromJson(Object? json) {
    final m = WJson.map(json);
    if (m == null) return null;
    TextStyle? text(Object? v) {
      final t = WJson.map(v);
      if (t == null) return null;
      final weight = WJson.integer(t['fontWeight']);
      return TextStyle(
        color: WJson.color(t['color']),
        fontSize: WJson.dbl(t['fontSize']),
        fontWeight: weight == null
            ? null
            : FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
        height: WJson.dbl(t['height']),
      );
    }

    return DolphinTheme(
      barrierColor: WJson.color(m['barrierColor']),
      barrierOpacity: WJson.dbl(m['barrierOpacity']),
      barrierBlur: WJson.dbl(m['barrierBlur']),
      shape: HighlightShape.fromJson(m['shape']),
      highlightPadding: WJson.insets(m['highlightPadding']),
      highlightOffset: WJson.offset(m['highlightOffset']),
      highlightBorderColor: WJson.color(m['highlightBorderColor']),
      highlightBorderWidth: WJson.dbl(m['highlightBorderWidth']),
      highlightBorderDash: WJson.dblList(m['highlightBorderDash']),
      highlightBorderGradient: WJson.gradient(m['highlightBorderGradient']),
      highlightGlowColor: WJson.color(m['highlightGlowColor']),
      highlightGlowBlur: WJson.dbl(m['highlightGlowBlur']),
      pulseColor: WJson.color(m['pulseColor']),
      tooltipStyle: WJson.str(m['tooltipStyle']),
      tooltipPosition:
          WJson.enumByName(TooltipPosition.values, m['tooltipPosition']),
      tooltipBackgroundColor: WJson.color(m['tooltipBackgroundColor']),
      tooltipForegroundColor: WJson.color(m['tooltipForegroundColor']),
      primaryColor: WJson.color(m['primaryColor']),
      tooltipBorderRadius: WJson.dbl(m['tooltipBorderRadius']),
      tooltipPadding: WJson.insets(m['tooltipPadding']),
      tooltipMaxWidth: WJson.dbl(m['tooltipMaxWidth']),
      screenMargin: WJson.insets(m['screenMargin']),
      targetGap: WJson.dbl(m['targetGap']),
      titleStyle: text(m['titleStyle']),
      descriptionStyle: text(m['descriptionStyle']),
      counterStyle: text(m['counterStyle']),
      buttonTextStyle: text(m['buttonTextStyle']),
      pointer: PointerStyle.fromJson(m['pointer']),
      counterFormat: WJson.str(m['counterFormat']),
      showCounter: WJson.boolean(m['showCounter']),
      showSkip: WJson.boolean(m['showSkip']),
      showPrevious: WJson.boolean(m['showPrevious']),
      showNext: WJson.boolean(m['showNext']),
      nextLabel: WJson.str(m['nextLabel']),
      previousLabel: WJson.str(m['previousLabel']),
      skipLabel: WJson.str(m['skipLabel']),
      finishLabel: WJson.str(m['finishLabel']),
      animation: DolphinAnimation.fromJson(m['animation']),
      targetTapBehavior:
          WJson.enumByName(TargetTapBehavior.values, m['targetTapBehavior']),
      barrierTapBehavior:
          WJson.enumByName(BarrierTapBehavior.values, m['barrierTapBehavior']),
      backButtonBehavior:
          WJson.enumByName(BackButtonBehavior.values, m['backButtonBehavior']),
      respectSafeArea: WJson.boolean(m['respectSafeArea']),
      dark: DolphinTheme.fromJson(m['dark']),
    );
  }
}
