// Runs on a real phone, emulator or simulator:
//   cd example
//   flutter test integration_test -d <device id>     (see `flutter devices`)
//
// Checks the parts that differ per platform: the real page transition
// (Cupertino on iOS), the notch / status bar, and the default storage
// (SharedPreferences + SQLite on Android / iOS).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dolphin/dolphin.dart';

Rect? holeRect(WidgetTester tester) {
  for (final w in tester.widgetList<CustomMultiChildLayout>(
      find.byType(CustomMultiChildLayout))) {
    final d = w.delegate;
    if (d is TooltipLayoutDelegate) return d.hole;
  }
  return null;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('highlight sits exactly on the target after navigation',
      (tester) async {
    final c = DolphinController(
      theme: const DolphinTheme(
        shape: HighlightShape.rect(),
        highlightPadding: EdgeInsets.zero,
      ),
    );
    await c.init();
    await c.resetAll();

    await tester.pumpWidget(Dolphin(
      controller: c,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => DolphinScope(
                    id: 'deviceTest',
                    child: Scaffold(
                      appBar: AppBar(title: const Text('Detail')),
                      body: ListView(children: [
                        for (var i = 0; i < 6; i++)
                          ListTile(title: Text('Row $i')),
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: DolphinTarget(
                            id: 'save',
                            title: 'Save here',
                            child: SizedBox(
                                key: Key('save'), width: 140, height: 48),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);

    expect(find.text('Save here'), findsOneWidget);
    final target = tester.getRect(find.byKey(const Key('save')));
    final hole = holeRect(tester)!;
    expect(hole.left, closeTo(target.left, 0.5));
    expect(hole.top, closeTo(target.top, 0.5));
    expect(hole.width, closeTo(target.width, 0.5));
    expect(hole.height, closeTo(target.height, 0.5));

    // Finishing the step is saved to the device's real storage.
    c.next();
    await settle(tester);
    await c.flush();
    expect(c.isSeen('deviceTest', 'save'), isTrue);

    final reloaded = DolphinController();
    await reloaded.init();
    expect(reloaded.isSeen('deviceTest', 'save'), isTrue);
    await c.resetAll();
    c.dispose();
    reloaded.dispose();
  });
}
