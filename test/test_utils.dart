import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

const testTheme = DolphinTheme(animation: DolphinAnimation.none());

DolphinController makeController({
  DolphinConfig config = DolphinConfig.empty,
  MemoryDolphinStore? store,
  GlobalKey<NavigatorState>? navigatorKey,
  bool autoStart = true,
  DolphinTheme? theme,
  CounterMode counterMode = CounterMode.wholeScope,
}) =>
    DolphinController(
      store: store ?? MemoryDolphinStore(),
      config: config,
      theme: testTheme.merge(theme),
      startDelay: Duration.zero,
      waitForTarget: Duration.zero,
      autoStart: autoStart,
      navigatorKey: navigatorKey,
      counterMode: counterMode,
    );

Widget wrapApp(
  DolphinController c, {
  required Widget home,
  Map<String, WidgetBuilder> routes = const {},
  GlobalKey<NavigatorState>? navigatorKey,
}) =>
    Dolphin(
      controller: c,
      child:
          MaterialApp(navigatorKey: navigatorKey, home: home, routes: routes),
    );

/// Pumps enough frames for timers, post-frame callbacks and route
/// transitions to finish (the overlay itself has no endless animations
/// because tests use [testTheme]).
Future<void> settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }
}

class SimplePage extends StatelessWidget {
  const SimplePage({
    super.key,
    required this.scope,
    required this.targets,
    this.onTap,
    this.autoStart,
  });

  final String scope;
  final List<String> targets;
  final void Function(BuildContext context, String id)? onTap;
  final bool? autoStart;

  @override
  Widget build(BuildContext context) {
    return DolphinScope(
      id: scope,
      autoStart: autoStart,
      child: Scaffold(
        appBar: AppBar(title: Text('page $scope')),
        body: Column(
          children: [
            for (final id in targets)
              Padding(
                padding: const EdgeInsets.all(8),
                child: DolphinTarget(
                  id: id,
                  child: ElevatedButton(
                    onPressed: () => onTap?.call(context, id),
                    child: Text('btn $id'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
