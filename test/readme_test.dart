import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

import 'test_utils.dart';

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return DolphinScope(
      id: 'home',
      child: Scaffold(
        appBar: AppBar(actions: [
          DolphinTarget(
            id: 'search',
            title: 'Search',
            description: 'Find anything from here.',
            child: IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          ),
        ]),
      ),
    );
  }
}

void main() {
  testWidgets('the README quick start shows the step once', (tester) async {
    final store = MemoryDolphinStore();
    final guide = makeController(store: store);
    await tester.pumpWidget(wrapApp(guide, home: const _HomePage()));
    await settle(tester);

    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Find anything from here.'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Find anything from here.'), findsNothing);
    expect(guide.isSeen('home', 'search'), isTrue);

    final again = makeController(store: store);
    await tester.pumpWidget(wrapApp(again, home: const _HomePage()));
    await settle(tester);
    expect(find.text('Find anything from here.'), findsNothing);
  });
}
