import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dolphin/dolphin.dart';

import 'fake_server.dart';
import 'pages/details_page.dart';
import 'pages/home_page.dart';
import 'pages/journey_pages.dart';
import 'pages/settings_page.dart';

final navigatorKey = GlobalKey<NavigatorState>();
bool isPremium = false;

late final DolphinController walkthrough;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  walkthrough = DolphinController(
    // Default store: SharedPreferences for flags + SQLite for progress.
    navigatorKey: navigatorKey,
    debugLogging: true,
    theme: const DolphinTheme(
      pointer: PointerStyle.arrowAndDots(sizes: [8, 6, 4]),
    ),
    // Only what differs in dark mode; the rest comes from `theme`.
    darkTheme: const DolphinTheme(
        primaryColor: Color(0xFFB4BEFF), barrierOpacity: 0.8),
    // Push every change to "your server" (here: an in-memory fake).
    onProgressChanged: (p) => FakeServer.instance.save(p.toJson()),
    onEvent: (e) => debugPrint('analytics: $e'),
  );

  // 1. Central data: one JSON for every page. Could come from your API.
  final raw = await rootBundle.loadString('assets/walkthrough.json');
  walkthrough.loadConfigJson(jsonDecode(raw) as Map<String, dynamic>);

  // 2. Names usable from JSON.
  walkthrough.registerCondition('notPremium', () => !isPremium);
  walkthrough.registerTooltipBuilder('promo', (context, t) {
    return Card(
      color: Colors.deepPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.step.title ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Text(t.counterText,
                  style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              TextButton(
                  onPressed: t.dismiss,
                  child: const Text('Later',
                      style: TextStyle(color: Colors.white70))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black),
                onPressed: t.next,
                child: Text('${t.step.extra['cta'] ?? 'OK'}'),
              ),
            ]),
          ],
        ),
      ),
    );
  });

  await walkthrough.init();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Dolphin(
      controller: walkthrough,
      child: MaterialApp(
        title: 'dolphin demo',
        navigatorKey: navigatorKey,
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        // The walkthrough follows this automatically (DolphinThemeMode.app).
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            useMaterial3: true,
            brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        routes: {
          '/': (_) => const HomePage(),
          '/details': (_) => const DetailsPage(),
          '/settings': (_) => const SettingsPage(),
          '/page4': (_) => const Page4(),
          '/page8': (_) => const Page8(),
        },
      ),
    );
  }
}
