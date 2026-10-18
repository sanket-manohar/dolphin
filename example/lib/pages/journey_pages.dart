import 'package:flutter/material.dart';
import 'package:dolphin/dolphin.dart';

class _Grid extends StatelessWidget {
  const _Grid({required this.scope, required this.ids, required this.title});
  final String scope;
  final List<String> ids;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DolphinScope(
      id: scope,
      // These pages only run as part of the journey.
      autoStart: false,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            for (final id in ids)
              DolphinTarget(
                id: id,
                child: Card(child: Center(child: Text(id))),
              ),
          ],
        ),
      ),
    );
  }
}

class Page4 extends StatelessWidget {
  const Page4({super.key});
  @override
  Widget build(BuildContext context) => const _Grid(
      scope: 'page4',
      title: 'Page 4',
      ids: ['p4a', 'p4b', 'p4c', 'p4d', 'p4e']);
}

class Page8 extends StatelessWidget {
  const Page8({super.key});
  @override
  Widget build(BuildContext context) =>
      const _Grid(scope: 'page8', title: 'Page 8', ids: ['p8a', 'p8b', 'p8c']);
}
