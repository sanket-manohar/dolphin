import 'package:flutter/material.dart';
import 'package:dolphin/dolphin.dart';

/// All content for this page comes from assets/walkthrough.json. The widgets
/// only carry ids.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DolphinScope(
      id: 'home',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            DolphinTarget(
              id: 'search',
              child:
                  IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            ),
            DolphinTarget(
              id: 'settings',
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
                'Welcome! The guide starts by itself on every page that has unseen tips.'),
            const SizedBox(height: 24),
            Center(
              child: DolphinTarget(
                id: 'openDetails',
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open details'),
                  onPressed: () => Navigator.pushNamed(context, '/details'),
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  Dolphin.of(context).startJourney('tour', restart: true),
              child:
                  const Text('Start the cross-page journey (page 4 → page 8)'),
            ),
          ],
        ),
        floatingActionButton: DolphinTarget(
          id: 'fab',
          child: FloatingActionButton.extended(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
        ),
      ),
    );
  }
}
