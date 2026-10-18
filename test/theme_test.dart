import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

import 'test_utils.dart';

void main() {
  group('dark theme resolution', () {
    test('light mode ignores every dark override', () {
      final c = makeController(
        theme: const DolphinTheme(
          tooltipBackgroundColor: Colors.white,
          dark: DolphinTheme(tooltipBackgroundColor: Colors.black),
        ),
      )..darkTheme = const DolphinTheme(primaryColor: Colors.teal);
      final t = c.resolveTheme('p', const DolphinStep(id: 'a'));
      expect(t.tooltipBackgroundColor, Colors.white);
      expect(t.primaryColor, DolphinTheme.fallback.primaryColor);
    });

    test('dark mode layers: fallbackDark < app < darkTheme < step', () {
      final c =
          makeController(theme: const DolphinTheme(primaryColor: Colors.red))
            ..darkTheme = const DolphinTheme(primaryColor: Colors.teal);
      final plain =
          c.resolveTheme('p', const DolphinStep(id: 'a'), isDark: true);
      expect(plain.primaryColor, Colors.teal);
      expect(plain.tooltipBackgroundColor,
          DolphinTheme.fallbackDark.tooltipBackgroundColor);

      // A step's own colour still beats the app's dark defaults.
      final step = c.resolveTheme(
          'p',
          const DolphinStep(
              id: 'a', theme: DolphinTheme(primaryColor: Colors.pink)),
          isDark: true);
      expect(step.primaryColor, Colors.pink);

      // ...and the step's own dark override beats its light value.
      final stepDark = c.resolveTheme(
          'p',
          const DolphinStep(
              id: 'a',
              theme: DolphinTheme(
                  primaryColor: Colors.pink,
                  dark: DolphinTheme(primaryColor: Colors.amber))),
          isDark: true);
      expect(stepDark.primaryColor, Colors.amber);
    });

    test('resolve() applies a theme\'s own dark block', () {
      const t = DolphinTheme(
          barrierColor: Colors.black, dark: DolphinTheme(barrierOpacity: 0.9));
      expect(t.resolve(isDark: false).barrierOpacity, isNull);
      expect(t.resolve(isDark: true).barrierOpacity, 0.9);
    });
  });

  test('new theme keys parse from JSON', () {
    final t = DolphinTheme.fromJson({
      'barrierOpacity': 0.5,
      'highlightOffset': [4, -2],
      'highlightBorderDash': [6, 3],
      'highlightBorderGradient': ['#ff0000', '#0000ff'],
      'shape': 'diamond',
      'dark': {'tooltipBackgroundColor': '#222222', 'barrierOpacity': 0.8},
      'pointer': {
        'kind': 'dots',
        'dotSizes': [10, 6, 3],
        'dotColors': ['#ff0000', '#00ff00'],
        'dotShape': 'roundedSquare',
      },
    })!;
    expect(t.barrierOpacity, 0.5);
    expect(t.highlightOffset, const Offset(4, -2));
    expect(t.highlightBorderDash, [6, 3]);
    expect(t.highlightBorderGradient, isA<LinearGradient>());
    expect(t.shape, isA<DiamondHighlight>());
    expect(t.dark!.tooltipBackgroundColor, const Color(0xFF222222));
    expect(t.dark!.barrierOpacity, 0.8);
    expect(t.pointer!.dotColors,
        [const Color(0xFFFF0000), const Color(0xFF00FF00)]);
    expect(t.pointer!.dotShape, DotShape.roundedSquare);
    expect(DolphinTheme.jsonKeys,
        containsAll(['barrierOpacity', 'dark', 'highlightOffset']));
  });

  test('bad values for the new keys are ignored, never thrown', () {
    final t = DolphinTheme.fromJson({
      'barrierOpacity': 'lots',
      'highlightOffset': 'left',
      'highlightBorderGradient': ['#ff0000'],
      'dark': 'yes',
      'pointer': {'dotColors': 'red', 'dotShape': 'star'},
    })!;
    expect(t.barrierOpacity, isNull);
    expect(t.highlightOffset, isNull);
    expect(t.highlightBorderGradient, isNull);
    expect(t.dark, isNull);
    expect(t.pointer!.dotColors, isNull);
    expect(t.pointer!.dotShape, DotShape.circle);
  });

  test('pointer styles compare by value, so layout is not redone needlessly',
      () {
    expect(const PointerStyle.dots(sizes: [8, 6, 4]),
        PointerStyle.dots(sizes: List.of(const [8.0, 6.0, 4.0])));
    expect(
        const PointerStyle.dots(sizes: [8, 6, 4]) ==
            const PointerStyle.dots(sizes: [4, 6, 8]),
        isFalse);
    expect(const PointerStyle.custom(painter: _noop, length: 30).extent, 30);
    expect(const PointerStyle.dots(sizes: [12, 4]).crossExtent, 12);
  });

  test('diamond shape touches the middle of each side', () {
    final b = const HighlightShape.diamond()
        .getBounds(const Rect.fromLTWH(0, 0, 100, 40));
    expect(b, const Rect.fromLTWH(0, 0, 100, 40));
  });
}

void _noop(Canvas c, Size s, AxisDirection d, PointerStyle p) {}
