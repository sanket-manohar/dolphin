import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

/// The hole the overlay laid out around the current target.
Rect? holeRect(WidgetTester tester) {
  for (final w in tester.widgetList<CustomMultiChildLayout>(
      find.byType(CustomMultiChildLayout))) {
    final d = w.delegate;
    if (d is TooltipLayoutDelegate) return d.hole;
  }
  return null;
}

DolphinController exactController(
        {DolphinThemeMode mode = DolphinThemeMode.app}) =>
    DolphinController(
      store: MemoryDolphinStore(),
      startDelay: Duration.zero,
      waitForTarget: Duration.zero,
      themeMode: mode,
      theme: const DolphinTheme(
        animation: DolphinAnimation.none(),
        shape: HighlightShape.rect(),
        highlightPadding: EdgeInsets.zero,
      ),
    );

class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/detail'),
            child: const Text('open'),
          ),
        ),
      );
}

class _Detail extends StatelessWidget {
  const _Detail();
  @override
  Widget build(BuildContext context) => const DolphinScope(
        id: 'detail',
        child: Scaffold(
          body: Padding(
            padding: EdgeInsets.only(left: 40, top: 160),
            child: Align(
              alignment: Alignment.topLeft,
              child: DolphinTarget(
                id: 'save',
                title: 'Save here',
                child: SizedBox(key: Key('save'), width: 120, height: 48),
              ),
            ),
          ),
        ),
      );
}

Future<void> pumpFrames(WidgetTester tester, int n, [int ms = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

void main() {
  testWidgets('highlight lands on the target after a page push',
      (tester) async {
    // A notch / status bar like a real phone.
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.resetPadding);
    final c = exactController();
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: MaterialApp(
        home: const _Home(),
        routes: {'/detail': (_) => const _Detail()},
      ),
    ));
    await tester.tap(find.text('open'));
    // Mid-transition: the page is still sliding, so nothing may be shown
    // (this is where a wrong position would be captured).
    await pumpFrames(tester, 5);
    expect(find.text('Save here'), findsNothing);

    await tester.pumpAndSettle();
    await pumpFrames(tester, 10, 50);
    await tester.pumpAndSettle();
    expect(find.text('Save here'), findsOneWidget);
    final target = tester.getRect(find.byKey(const Key('save')));
    final hole = holeRect(tester)!;
    expect(hole.left, closeTo(target.left, 0.01));
    expect(hole.top, closeTo(target.top, 0.01));
    expect(hole.size, target.size);
    expect(tester.takeException(), isNull);
    c.dispose();
  },
      variant: const TargetPlatformVariant(
          {TargetPlatform.iOS, TargetPlatform.android}));

  testWidgets('iOS: a cancelled swipe-back leaves the highlight on the target',
      (tester) async {
    final c = exactController();
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: MaterialApp(
        home: const _Home(),
        routes: {'/detail': (_) => const _Detail()},
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await pumpFrames(tester, 10, 50);
    await tester.pumpAndSettle();
    expect(find.text('Save here'), findsOneWidget);

    // Start the iOS back swipe from the left edge, go a little, let go.
    final gesture = await tester.startGesture(const Offset(2, 400));
    await gesture.moveBy(const Offset(60, 0));
    await pumpFrames(tester, 3);
    await gesture.up();
    await tester.pumpAndSettle();
    await pumpFrames(tester, 10, 50);
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(const Key('save')));
    expect(find.text('Save here'), findsOneWidget);
    final hole = holeRect(tester)!;
    expect(hole.left, closeTo(target.left, 0.01));
    expect(hole.top, closeTo(target.top, 0.01));
    expect(tester.takeException(), isNull);
    c.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final (mode, appDark, platformDark, expectDark) in [
    (DolphinThemeMode.app, true, false, true),
    (DolphinThemeMode.app, false, true, false),
    (DolphinThemeMode.system, false, true, true),
    (DolphinThemeMode.light, true, true, false),
    (DolphinThemeMode.dark, false, false, true),
  ]) {
    testWidgets(
        'theme mode ${mode.name} (app dark: $appDark, phone dark: $platformDark)',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue =
          platformDark ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final c = exactController(mode: mode)
        ..darkTheme =
            const DolphinTheme(tooltipBackgroundColor: Color(0xFF101010));
      Color? seen;
      c.registerTooltipBuilder('probe', (context, ctx) {
        seen = ctx.theme.tooltipBackgroundColor;
        return Text(ctx.step.title ?? '');
      });
      await tester.pumpWidget(Dolphin(
        controller: c,
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: appDark ? ThemeMode.dark : ThemeMode.light,
          home: const DolphinScope(
            id: 'p',
            theme: DolphinTheme(tooltipStyle: 'probe'),
            child: Scaffold(
                body: DolphinTarget(id: 'a', title: 'Tip', child: Text('A'))),
          ),
        ),
      ));
      await pumpFrames(tester, 10, 50);
      await tester.pumpAndSettle();
      expect(find.text('Tip'), findsOneWidget);
      expect(
          seen,
          expectDark
              ? const Color(0xFF101010)
              : DolphinTheme.fallback.tooltipBackgroundColor);
      c.dispose();
    });
  }

  testWidgets('every shape, border and pointer option renders without errors',
      (tester) async {
    var customCalls = 0;
    final pointers = [
      const PointerStyle.dots(sizes: [10, 7, 4]).copyWith(
          dotShape: DotShape.diamond,
          dotColors: const [Colors.red, Colors.green]),
      const PointerStyle().copyWith(dotShape: DotShape.square),
      const PointerStyle().copyWith(dotShape: DotShape.roundedSquare),
      PointerStyle.custom(
          length: 20,
          painter: (canvas, size, dir, style) {
            customCalls++;
            canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
          }),
      PointerStyle.custom(
          length: 20, painter: (canvas, size, dir, style) => throw 'boom'),
      const PointerStyle.line(),
      const PointerStyle.none(),
    ];
    final shapes = [
      const HighlightShape.diamond(),
      const HighlightShape.circle(cover: true),
      const HighlightShape.stadium(),
      const HighlightShape.oval(),
      HighlightShape.fromJson({'type': 'beveled', 'radius': 8})!,
    ];
    final steps = <Widget>[];
    for (var i = 0; i < pointers.length; i++) {
      steps.add(DolphinTarget(
        id: 's$i',
        title: 'Step $i',
        theme: DolphinTheme(
          pointer: pointers[i],
          shape: shapes[i % shapes.length],
          highlightBorderWidth: 3,
          highlightBorderColor: Colors.amber,
          highlightBorderDash: i.isEven ? const [6, 4] : null,
          highlightBorderGradient: i.isOdd
              ? const LinearGradient(colors: [Colors.red, Colors.blue])
              : null,
          highlightOffset: const Offset(2, 2),
          barrierOpacity: 0.4,
        ),
        child: const SizedBox(width: 60, height: 30),
      ));
    }
    final c = exactController();
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: MaterialApp(
        home: DolphinScope(
          id: 'p',
          child: Scaffold(
              body: SingleChildScrollView(child: Column(children: steps))),
        ),
      ),
    ));
    for (var i = 0; i < pointers.length; i++) {
      await pumpFrames(tester, 6, 50);
      expect(find.text('Step $i'), findsOneWidget);
      c.next();
    }
    await pumpFrames(tester, 6, 50);
    expect(customCalls, greaterThan(0));
    expect(tester.takeException(), isNull);
    c.dispose();
  });
}
