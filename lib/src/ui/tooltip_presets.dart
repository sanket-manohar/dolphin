import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/dolphin_step.dart';
import 'dolphin_theme.dart';

/// Visual info a preset gives the overlay (pointer colour, layout hints).
class TooltipSpec {
  const TooltipSpec({required this.color, this.pinnedToEdge = false});

  /// Colour the arrow/dots default to so they blend with the tooltip.
  final Color color;

  /// True for the banner preset: full width, no pointer.
  final bool pinnedToEdge;
}

TooltipPreset? presetByName(String? name) {
  if (name == null) return null;
  for (final p in TooltipPreset.values) {
    if (p.name == name.toLowerCase()) return p;
  }
  return null;
}

TooltipSpec specFor(TooltipPreset preset, DolphinTheme t) {
  switch (preset) {
    case TooltipPreset.card:
      return TooltipSpec(color: t.tooltipBackgroundColor!);
    case TooltipPreset.bubble:
    case TooltipPreset.compact:
      return TooltipSpec(color: t.primaryColor!);
    case TooltipPreset.minimal:
      return const TooltipSpec(color: Colors.white);
    case TooltipPreset.glass:
      return const TooltipSpec(color: Color(0x66FFFFFF));
    case TooltipPreset.banner:
      return TooltipSpec(color: t.tooltipBackgroundColor!, pinnedToEdge: true);
  }
}

Widget buildPresetTooltip(
    BuildContext context, TooltipPreset preset, DolphinTooltipContext c) {
  switch (preset) {
    case TooltipPreset.card:
      return _Panel(
          c: c,
          background: c.theme.tooltipBackgroundColor!,
          foreground: c.theme.tooltipForegroundColor!,
          accent: c.theme.primaryColor!);
    case TooltipPreset.bubble:
      return _Panel(
        c: c,
        background: c.theme.primaryColor!,
        foreground: Colors.white,
        accent: Colors.white,
        filledNextForeground: c.theme.primaryColor,
        radius: (c.theme.tooltipBorderRadius ?? 14) + 6,
      );
    case TooltipPreset.minimal:
      return _Panel(
        c: c,
        background: Colors.transparent,
        foreground: Colors.white,
        accent: Colors.white,
        shadow: const [],
        textButtonsOnly: true,
      );
    case TooltipPreset.glass:
      final radius = c.theme.tooltipBorderRadius ?? 14;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: _Panel(
            c: c,
            background: const Color(0x33FFFFFF),
            foreground: Colors.white,
            accent: Colors.white,
            filledNextForeground: Colors.black87,
            border: Border.all(color: const Color(0x66FFFFFF)),
            shadow: const [],
          ),
        ),
      );
    case TooltipPreset.banner:
      return _Panel(
        c: c,
        background: c.theme.tooltipBackgroundColor!,
        foreground: c.theme.tooltipForegroundColor!,
        accent: c.theme.primaryColor!,
        expand: true,
      );
    case TooltipPreset.compact:
      return _Compact(c: c);
  }
}

/// The step counter honouring `counterBuilder`, `showCounter` and
/// `counterText`. Reuse it in custom tooltips.
class DolphinCounter extends StatelessWidget {
  const DolphinCounter(this.c, {super.key, this.color});
  final DolphinTooltipContext c;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (c.theme.showCounter == false) return const SizedBox.shrink();
    final b = c.theme.counterBuilder;
    if (b != null) return b(context, c.index, c.total);
    return Text(
      c.counterText,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: (color ?? Colors.black).withValues(alpha: 0.6),
      ).merge(c.theme.counterStyle),
    );
  }
}

/// Skip / Back / Next row honouring the theme flags and labels. Reuse it in
/// custom tooltips.
class DolphinButtons extends StatelessWidget {
  const DolphinButtons(
    this.c, {
    super.key,
    this.foreground = Colors.black,
    this.accent = Colors.indigo,
    this.filledNextForeground,
    this.textOnly = false,
    this.showCounter = true,
  });

  final DolphinTooltipContext c;
  final Color foreground;
  final Color accent;
  final Color? filledNextForeground;
  final bool textOnly;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    final t = c.theme;
    final style =
        const TextStyle(fontWeight: FontWeight.w600).merge(t.buttonTextStyle);
    final small = TextButton.styleFrom(
      foregroundColor: foreground.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: style,
    );
    final nextLabel = c.isLast ? t.finishLabel! : t.nextLabel!;
    return Row(
      children: [
        if (showCounter) DolphinCounter(c, color: foreground),
        const Spacer(),
        if (t.showSkip != false && !c.isLast)
          TextButton(
              onPressed: c.skipScope, style: small, child: Text(t.skipLabel!)),
        if (t.showPrevious != false && !c.isFirst)
          TextButton(
              onPressed: c.previous,
              style: small,
              child: Text(t.previousLabel!)),
        if (t.showNext != false) ...[
          const SizedBox(width: 4),
          textOnly
              ? TextButton(
                  onPressed: c.next,
                  style: small.copyWith(
                      foregroundColor: WidgetStatePropertyAll(accent)),
                  child: Text(nextLabel),
                )
              : FilledButton(
                  onPressed: c.next,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: filledNextForeground ??
                        (ThemeData.estimateBrightnessForColor(accent) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: style,
                  ),
                  child: Text(nextLabel),
                ),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.c,
    required this.background,
    required this.foreground,
    required this.accent,
    this.filledNextForeground,
    this.radius,
    this.shadow,
    this.border,
    this.textButtonsOnly = false,
    this.expand = false,
  });

  final DolphinTooltipContext c;
  final Color background;
  final Color foreground;
  final Color accent;
  final Color? filledNextForeground;
  final double? radius;
  final List<BoxShadow>? shadow;
  final BoxBorder? border;
  final bool textButtonsOnly;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final t = c.theme;
    final s = c.step;
    final title = TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: foreground,
            height: 1.25)
        .merge(t.titleStyle);
    final body = TextStyle(
            fontSize: 14,
            color: foreground.withValues(alpha: 0.85),
            height: 1.4)
        .merge(t.descriptionStyle);
    return Container(
      width: expand ? double.infinity : null,
      padding: t.tooltipPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(radius ?? t.tooltipBorderRadius ?? 14),
        boxShadow: shadow ?? t.tooltipShadow,
        border: border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.imageAsset != null || s.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: s.imageAsset != null
                    ? Image.asset(s.imageAsset!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink())
                    : Image.network(s.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (s.title != null) Text(s.title!, style: title),
          if (s.title != null && s.description != null)
            const SizedBox(height: 6),
          if (s.description != null) Text(s.description!, style: body),
          const SizedBox(height: 10),
          DolphinButtons(
            c,
            foreground: foreground,
            accent: accent,
            filledNextForeground: filledNextForeground,
            textOnly: textButtonsOnly,
          ),
        ],
      ),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact({required this.c});
  final DolphinTooltipContext c;

  @override
  Widget build(BuildContext context) {
    final t = c.theme;
    final text = c.step.title ?? c.step.description ?? '';
    return Material(
      color: t.primaryColor,
      shape: const StadiumBorder(),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(text,
                  style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)
                      .merge(t.titleStyle)),
            ),
            const SizedBox(width: 8),
            DolphinCounter(c, color: Colors.white),
            IconButton(
              onPressed: c.next,
              tooltip: c.isLast ? t.finishLabel : t.nextLabel,
              color: Colors.white,
              icon: Icon(c.isLast ? Icons.check : Icons.arrow_forward),
            ),
          ],
        ),
      ),
    );
  }
}
