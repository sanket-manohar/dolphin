# dolphin example

A complete app that shows every dolphin feature. Run it to try them on a phone, an emulator or in the browser:

```bash
cd example
flutter pub get
flutter run
```

## What to try

| Page | What it shows |
| --- | --- |
| Home | Auto-start, central JSON, the card and bubble styles, and a "tap the real button" step that opens the next page |
| Details | Inline step data, the dots pointer, and a custom tooltip registered by name |
| Journey | One tap runs 5 steps on page 4, opens page 8 and shows 3 more |
| Settings | Turn tips off, rewatch everything, reset one section, see the progress JSON, and simulate a new device |

Switch your phone or browser between light and dark mode to see the overlay follow it.

## The smallest setup

```dart
import 'package:flutter/material.dart';
import 'package:dolphin/dolphin.dart';

final guide = DolphinController();

void main() => runApp(
      Dolphin(
        controller: guide,
        child: const MaterialApp(home: HomePage()),
      ),
    );

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
              title: 'Search',
              description: 'Find anything from here.',
              child: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

The full source is in [`lib/main.dart`](lib/main.dart) and [`lib/pages`](lib/pages), and the step text lives in [`assets/walkthrough.json`](assets/walkthrough.json).

## Device test

`integration_test/device_test.dart` checks that highlights line up on a real device:

```bash
flutter test integration_test -d <device id>
```
