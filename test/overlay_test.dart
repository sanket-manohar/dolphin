import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('default animations (fade, morph, pulse) run without errors',
      (tester) async {
    final c = DolphinController(
      store: MemoryDolphinStore(),
      startDelay: Duration.zero,
      waitForTarget: Duration.zero,
      theme: const DolphinTheme(
        barrierBlur: 4,
        highlightBorderColor: Colors.amber,
        highlightBorderWidth: 2,
        highlightGlowColor: Colors.amber,
        highlightGlowBlur: 8,
        pointer: PointerStyle.dots(sizes: [10, 7, 4]),
      ),
    );
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: const MaterialApp(
        home: DolphinScope(
          id: 'p',
          child: Scaffold(
            body: Column(children: [
              DolphinTarget(id: 'a', title: 'First', child: Text('A')),
              SizedBox(height: 300),
              DolphinTarget(
                id: 'b',
                title: 'Second',
                theme: DolphinTheme(shape: HighlightShape.circle()),
                child: Icon(Icons.star),
              ),
            ]),
          ),
        ),
      ),
    ));
    await frames(tester);
    expect(find.text('First'), findsOneWidget);
    c.next();
    await frames(tester);
    expect(find.text('Second'), findsOneWidget);
    c.next();
    await frames(tester);
    expect(find.text('Second'), findsNothing);
    expect(tester.takeException(), isNull);
    c.dispose();
  });

  testWidgets('offscreen target in a list is scrolled into view',
      (tester) async {
    final c = DolphinController(
      store: MemoryDolphinStore(),
      startDelay: Duration.zero,
      waitForTarget: Duration.zero,
      theme: const DolphinTheme(animation: DolphinAnimation.none()),
    );
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: MaterialApp(
        home: DolphinScope(
          id: 'list',
          child: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
              for (var i = 0; i < 40; i++)
                SizedBox(
                  height: 80,
                  child: i == 30
                      ? const DolphinTarget(
                          id: 'row30', title: 'Deep row', child: Text('row 30'))
                      : Text('row $i'),
                ),
            ])),
          ),
        ),
      ),
    ));
    await frames(tester, 30);
    expect(find.text('Deep row'), findsOneWidget);
    final rect = tester.getRect(find.text('row 30'));
    expect(rect.top, greaterThan(0));
    expect(rect.bottom, lessThan(600));
  });

  testWidgets('back button dismisses by default', (tester) async {
    final c = DolphinController(
      store: MemoryDolphinStore(),
      startDelay: Duration.zero,
      waitForTarget: Duration.zero,
      theme: const DolphinTheme(animation: DolphinAnimation.none()),
    );
    await tester.pumpWidget(Dolphin(
      controller: c,
      child: const MaterialApp(
        home: DolphinScope(
          id: 'p',
          child: Scaffold(
              body: DolphinTarget(id: 'a', title: 'Tip', child: Text('A'))),
        ),
      ),
    ));
    await frames(tester);
    expect(find.text('Tip'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(find.text('Tip'), findsNothing);
    expect(c.pendingSteps('p'), ['a']);
  });
}
