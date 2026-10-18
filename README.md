<p align="center">
  <img src="https://raw.githubusercontent.com/sanket-manohar/dolphin/main/doc/banner.png" alt="dolphin: guided walkthroughs for Flutter" width="100%">
</p>

<p align="center">
  <a href="https://pub.dev/packages/dolphin"><img src="https://img.shields.io/pub/v/dolphin.svg?label=pub.dev&color=1A4FD0" alt="pub version"></a>
  <a href="https://pub.dev/packages/dolphin/score"><img src="https://img.shields.io/pub/points/dolphin?color=1FB5D6" alt="pub points"></a>
  <a href="https://pub.dev/packages/dolphin/score"><img src="https://img.shields.io/pub/likes/dolphin?color=1FB5D6" alt="pub likes"></a>
  <a href="https://github.com/sanket-manohar/dolphin/actions/workflows/ci.yml"><img src="https://github.com/sanket-manohar/dolphin/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-BSD--3--Clause-blue.svg" alt="BSD 3-Clause license"></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-0B1530.svg" alt="Android, iOS and Web">
</p>

# dolphin

**Guided walkthroughs for Flutter that remember where every user left off.**

dolphin highlights any widget and shows a fully customisable tooltip next to it. It tracks which steps every user has seen on every page, resumes after navigation, runs guided journeys across pages, and gives you the progress as plain JSON so you can store it in your own database or server.

You don't write a manager class, keep a list of keys, or track "seen" flags yourself. Mark a page, wrap the widgets you want to explain, and dolphin does the rest.

**[Website](https://sanket-manohar.github.io/dolphin/)** · **[Setup and Developer Guide (PDF)](https://sanket-manohar.github.io/dolphin/dolphin-guide.pdf)** · **[Example app](example)**

| Light | Dark | Bubble style | Progress and reset |
| :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/sanket-manohar/dolphin/main/doc/screenshots/light.png" width="200" alt="Card tooltip in light mode"> | <img src="https://raw.githubusercontent.com/sanket-manohar/dolphin/main/doc/screenshots/dark.png" width="200" alt="Card tooltip in dark mode"> | <img src="https://raw.githubusercontent.com/sanket-manohar/dolphin/main/doc/screenshots/bubble.png" width="200" alt="Bubble tooltip with dots pointer"> | <img src="https://raw.githubusercontent.com/sanket-manohar/dolphin/main/doc/screenshots/progress.png" width="200" alt="Settings page with progress"> |

## Features

| | |
| --- | --- |
| **Auto-start per page** | A page with unseen steps starts its walkthrough by itself, pauses when covered, and resumes when the user comes back. |
| **Journeys across pages** | Show 5 steps on page 4, open page 8 for 3 more, and continue until the pattern ends. |
| **Progress sync** | Export progress as JSON, import it on a new device with `union`, `remoteWins` or `localWins`, or call `syncWithServer`. |
| **Reset and rewatch** | `resetAll` for a settings button, or reset one section, single steps, or one journey. |
| **Sequence and exclude** | Custom step order and hidden steps per page, for the session or saved. |
| **Central JSON** | One config for every page's text and styling, changeable from your server without an app update. |
| **Six tooltip presets** | `card`, `bubble`, `minimal`, `banner`, `glass`, `compact`, plus custom builders. |
| **Highlight shapes and pointers** | Rect, rounded, circle, oval, stadium, diamond, beveled or custom, with solid, dashed or gradient borders, and an arrow-and-dots pointer (or your own) measured from the real target. |
| **Light and dark mode** | Follows the app's theme automatically, or the phone setting, or forced light or dark, with separate dark colours at any level. |
| **iOS, Android and web** | Measures targets against the overlay after page transitions finish, re-measures every frame, and stays clear of the notch. Tested with the iOS and Android transitions. |
| **Pluggable storage** | SharedPreferences and SQLite by default, or your own `DolphinStore` for any database or cloud storage. |
| **Safe by design** | Missing or late targets are skipped, and storage and JSON errors are reported instead of thrown. |

## Contents

1. [How it works: the scope-based approach](#how-it-works-the-scope-based-approach)
2. [Install](#install)
3. [Quick start](#quick-start)
4. [Where step data comes from](#where-step-data-comes-from)
5. [Customising the look](#customising-the-look)
6. [Behaviour: taps, back button, missing targets](#behaviour)
7. [Pages, resume, and auto-start](#pages-resume-and-auto-start)
8. [Journeys across pages](#journeys)
9. [Sequence and exclude](#sequence-and-exclude)
10. [Reset and rewatch](#reset-and-rewatch)
11. [Progress, storage, and server sync](#progress-storage-and-server-sync)
12. [Events and analytics](#events-and-analytics)
13. [Reliability guarantees](#reliability-guarantees)
14. [JSON reference](#json-reference)
15. [API cheat sheet](#api-cheat-sheet)
16. [Testing your app with dolphin](#testing-your-app-with-dolphin)
17. [Example app](#example-app)
18. [License and disclaimer](#license-and-disclaimer)

## How it works: the scope-based approach

dolphin is built from three widgets. Each one has a single job, so you can add a walkthrough to an existing app without restructuring it.

```text
Dolphin(controller)              once, above MaterialApp: owns progress, storage and the overlay
 └─ MaterialApp
     └─ DolphinScope(id: 'home') one per page or section: the unit that starts, pauses and resumes
         └─ Scaffold
             ├─ DolphinTarget(id: 'search')   one per widget to highlight
             └─ DolphinTarget(id: 'profile')
```

* **`Dolphin`** wraps the app once. It holds the `DolphinController`, which stores progress and draws the overlay on top of every page.
* **`DolphinScope`** marks a page or a section. A scope is the unit of progress: it knows its steps, starts by itself when its page is visible and has unseen steps, pauses when another page covers it, and resumes from the same step when the user comes back. Skipping or resetting a scope never touches other scopes.
* **`DolphinTarget`** wraps a widget to highlight. It only needs an `id`; the text and styling can live on the target, on the scope, or in one central JSON.

A scope doesn't have to wrap the `Scaffold`. Put it wherever the page's content starts, around a single tab, or around a section of a long page. A target outside its scope's subtree can still join it with `DolphinTarget(scope: 'home', ...)`.

## Install

**1. Add the package** from your project folder:

```bash
flutter pub add dolphin
```

Or add it to `pubspec.yaml` yourself and run `flutter pub get`:

```yaml
dependencies:
  dolphin: ^1.0.0
```

**2. Import it** where you use it:

```dart
import 'package:dolphin/dolphin.dart';
```

**3. Platform setup:** none. dolphin has no native code of its own and needs no permissions. It works on Android, iOS and web with the default project settings, and also runs on macOS, Windows and Linux. Progress is saved with SharedPreferences and SQLite on Android, iOS and macOS, and with SharedPreferences elsewhere.

**Requirements:** Flutter 3.27 or newer, Dart 3.6 or newer.

## Quick start

**1. Create one controller for the app** and put `Dolphin` above `MaterialApp`:

```dart
final guide = DolphinController();

void main() => runApp(
      Dolphin(
        controller: guide,
        child: MaterialApp(home: const HomePage()),
      ),
    );
```

**2. Mark the page** with `DolphinScope` (one scope = one page or section):

**3. Wrap each widget to highlight** with `DolphinTarget`:

```dart
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
```

That's it. When the page opens and has unseen steps, the guide starts by itself, shows "1/1", marks the step seen when the user taps Next, and never shows it again (until you reset it). You don't need a manager class, a key list, or "mark as seen" code.

## Where step data comes from

You can use any of these three sources, or mix them.

| Source | Where | Best for |
| --- | --- | --- |
| Inline on the target | `DolphinTarget(title:, description:, step:)` | Quick, local tips |
| On the page | `DolphinScope(steps: [DolphinStep(...)])` | Keeping a page's tips together |
| Central JSON | `DolphinConfig` loaded from an asset or your API | One single source of truth for the whole app |

With central data, widgets carry only an id:

```dart
final json = jsonDecode(await rootBundle.loadString('assets/guide.json'));
guide.loadConfigJson(json);          // merge, or replace: true

DolphinTarget(id: 'search', child: ...) // content comes from JSON
```

```json
{
  "scopes": {
    "home": {
      "steps": {
        "search": { "title": "Search", "description": "Find anything.", "shape": "circle" }
      }
    }
  }
}
```

When the same step has data in both places, they merge field by field. `dataPrecedence: DataPrecedence.centralWins` is the default, so your server can change the text without an app update. Use `inlineWins` to flip it.

You can fetch config from your server at any time and call `guide.setConfig(...)` or `guide.mergeConfig(...)`. Pages update immediately.

## Customising the look

Everything visual lives in `DolphinTheme`. Themes cascade: package defaults, then `controller.theme`, then the JSON `theme`, then the scope theme, then the step theme. A later layer wins only on the fields it sets.

```dart
DolphinController(
  theme: const DolphinTheme(
    barrierColor: Color(0xCC000000),
    barrierBlur: 3,                                   // blur everything except the target
    shape: HighlightShape.rounded(radius: 16),
    highlightPadding: EdgeInsets.all(8),
    highlightBorderColor: Colors.amber,
    highlightBorderWidth: 2,
    highlightGlowColor: Colors.amber, highlightGlowBlur: 10,
    tooltipStyle: 'card',
    tooltipPosition: TooltipPosition.auto,
    tooltipBackgroundColor: Colors.white,
    primaryColor: Colors.indigo,
    tooltipMaxWidth: 320,
    pointer: PointerStyle.arrowAndDots(sizes: [8, 6, 4]),
    counterFormat: '{current} of {total}',
    nextLabel: 'Next', previousLabel: 'Back', skipLabel: 'Skip all', finishLabel: 'Got it',
    showSkip: true, showPrevious: true, showCounter: true,
    animation: DolphinAnimation(transition: TooltipTransition.scale, pulse: true),
  ),
);
```

`DolphinTheme.fromMaterial(Theme.of(context))` follows your app's colour scheme.

### Overlay colour and opacity

`barrierColor` sets the colour, and `barrierOpacity` (0 to 1) overrides only its opacity, so you can change one without the other. `barrierBlur` blurs the page behind.

### Light and dark mode

By default (`themeMode: DolphinThemeMode.app`) the overlay is dark whenever your app's `Theme` is dark, so it follows `MaterialApp.themeMode` with no extra code. Other modes: `system` (the phone setting, whatever the app does), `light` and `dark`.

In dark mode the built-in dark defaults (`DolphinTheme.fallbackDark`: dark tooltip, light text, a stronger barrier) apply first, so all six presets get a dark version. Set only what you want different:

```dart
DolphinController(
  theme: const DolphinTheme(primaryColor: Colors.indigo),
  darkTheme: const DolphinTheme(primaryColor: Color(0xFFB4BEFF), barrierOpacity: 0.8),
  themeMode: DolphinThemeMode.app,
);

// Per page or per step, inside any theme:
DolphinTheme(tooltipBackgroundColor: Colors.white, dark: DolphinTheme(tooltipBackgroundColor: Color(0xFF222222)))
```

In JSON, put the dark overrides under `"dark": { ... }` inside any theme or step. A step's own colours still beat the app's dark defaults; only its own `dark` block beats them in dark mode. Switching the phone or app between light and dark restyles the step on screen right away.

### Highlight shapes

`rect`, `rounded`, `circle` (use `cover: true` to contain the whole widget), `oval`, `stadium`, `diamond`, `HighlightShape.border(anyShapeBorder)` (e.g. `BeveledRectangleBorder`), and `HighlightShape.custom((rect) => yourPath)`.

Around the shape you control:

* `highlightPadding`: space between the widget and the hole, per side.
* `highlightOffset`: nudges the hole by x/y pixels.
* `highlightBorderColor` and `highlightBorderWidth`, `highlightBorderDash: [6, 4]` for a dashed border, and `highlightBorderGradient` for a gradient border.
* `highlightGlowColor` and `highlightGlowBlur`, and `pulseColor` for the pulse.
* `targetGap` between the hole and the pointer, and `screenMargin` between the tooltip and the screen edges.

### Tooltip presets (6) and custom builders

| Preset | Look |
| --- | --- |
| `card` | White card with title, text, counter, and buttons (default) |
| `bubble` | Coloured speech bubble in the primary colour |
| `minimal` | Text only, straight on the dark background |
| `banner` | Full-width panel at the top or bottom edge, no pointer |
| `glass` | Frosted translucent card |
| `compact` | One-line pill with a next arrow |

Custom tooltips can be set per step inline (`tooltipBuilder:`) or registered by name so the JSON can use them:

```dart
guide.registerTooltipBuilder('promo', (context, t) => MyPromoCard(
  title: t.step.title,
  cta: t.step.extra['cta'],          // any extra JSON keys land in `extra`
  counter: t.counterText,            // "2/5", already formatted
  onNext: t.next, onBack: t.previous,
  onSkipPage: t.skipScope, onLater: t.dismiss,
  isLast: t.isLast,
));
```

```json
{ "title": "Go premium", "tooltipStyle": "promo", "cta": "Try it free" }
```

`DolphinCounter` and `DolphinButtons` are public, so custom tooltips can reuse the standard counter and button row.

### Pointer: arrow and dots

```dart
PointerStyle.arrowAndDots(sizes: [8, 6, 4])   // default: arrow + 3 dots
PointerStyle.dots(sizes: [12, 9, 6, 3])        // any number of dots, each size set separately
PointerStyle.arrow(width: 20, height: 10)
PointerStyle.line(length: 30)
PointerStyle.none()
```

Dot sizes are listed from the tooltip towards the target, so `[10, 7, 4]` puts the biggest dot next to the tooltip and the smallest next to the target. The order flips by itself when the target is above, below, left or right of the tooltip.

Colours default to the tooltip colour. `color` and `dotColor` override them, and `dotColors: [Colors.red, Colors.orange, Colors.yellow]` sets each dot separately. `dotShape` can be `circle`, `square`, `roundedSquare` or `diamond`.

For a pointer of your own, draw it:

```dart
PointerStyle.custom(
  length: 28,   // space between tooltip and target
  width: 20,    // size across
  painter: (canvas, size, direction, style) {
    // direction is the way to the target: up means the target is above.
    // Draw from the tooltip edge (bottom of `size` for up, top for down).
  },
)
```

A custom painter that throws is ignored, so it can't break the page.

### Step counter

The counter is automatic ("1/3", "2/3"). Change it with `counterFormat: 'Step {current} of {total}'`, replace it entirely with `counterBuilder: (ctx, current, total) => ...`, or set a custom text per step with `counterText`. `CounterMode.wholeScope` (the default) counts seen steps too, so a resumed page shows "3/5". `CounterMode.remainingOnly` counts only what's left ("1/3").

## Pointer alignment (the x-axis problem)

The tooltip and its pointer are placed by one layout delegate that measures the target's real `RenderBox` and knows the tooltip's real size in the same layout pass. Nothing is estimated, so the arrow points at the target's centre on every screen size, in RTL, after rotation, and while scrolling. Near the screen edges it slides as close as the rounded corners allow.

Backups, in order, if measuring ever fails:

1. `pointerOffset` (pixels from the tooltip's start edge) or `pointerX` (0..1 along the tooltip edge) from the step data, inline or JSON.
2. The tooltip centre.

Set `pointerMode: PointerMode.manual` to always use your value. A whole target that can't be measured can use `fallbackRect` (screen fractions) as a stand-in:

```json
{ "title": "Profile", "fallbackRect": { "x": 0.85, "y": 0.03, "width": 0.12, "height": 0.06 } }
```

## Behaviour

| Setting | Options | Default |
| --- | --- | --- |
| `targetTapBehavior` | `advance`, `passThrough`, `passThroughAndAdvance`, `block` | `advance` |
| `barrierTapBehavior` | `none`, `next`, `dismiss`, `skipScope` | `none` |
| `backButtonBehavior` | `dismiss`, `previous`, `block`, `passThrough` | `dismiss` |
| `missingTarget` (per step or controller) | `skip`, `skipAndMarkSeen`, `showCentered` | `skip` |
| `scrollIntoView` | Scrolls a target that is off screen into view first | `true` |
| `waitForTarget` | Waits this long for a target that mounts late | 600 ms |
| `autoAdvanceAfter` | Moves on by itself after a delay | off |
| `condition` / `conditionKey` | Shows the step only when the condition is true | none |
| `version` | Bump it to show a changed step again | 0 |

Use `passThroughAndAdvance` for "tap this button" steps that open another page. The user taps the real button, the step is marked seen, the new page opens (and runs its own guide), and the first page resumes at its next step when the user comes back.

Conditions can be registered by name for JSON:

```dart
guide.registerCondition('notPremium', () => !user.isPremium);
// JSON: { "title": "Go premium", "condition": "notPremium" }
```

## Pages, resume, and auto-start

* Each `DolphinScope` tracks its own steps. A scope starts automatically when its route is current, has finished animating, is not covered by another route or dialog, and is not in an inactive tab (offstage `IndexedStack` children count as hidden).
* When another page is pushed on top, the scope pauses. When the user comes back, it resumes from where it stopped.
* Auto-start can be turned off globally (`autoStart: false`), per scope (`DolphinScope(autoStart: false)` or `"autoStart": false` in JSON), or by the user (`guide.setEnabled(false)`, which is persisted). `guide.setScopeEnabled('home', false)` turns off one page.
* You can start a page by hand at any time with `guide.start('home')` (from the next unseen step) or `guide.replay('home')` (every step again, without forgetting progress).
* "Skip" (`skipScope`) marks only the current page's remaining steps as skipped. Other pages are untouched.
* "Dismiss" (`dismiss`) closes without marking anything, so the step shows again on the next visit.

A target can belong to a scope without being under it: `DolphinTarget(id: 'x', scope: 'home', ...)`.

## Journeys

A journey runs steps across pages in a fixed pattern, for example 5 steps on page 4, then open page 8 and show 3 steps there, and so on.

```json
"journeys": {
  "tour": [
    { "scope": "page4", "steps": ["a", "b", "c", "d", "e"], "route": "/page4" },
    { "scope": "page8", "steps": ["f", "g", "h"], "route": "/page8" },
    { "scope": "home",  "route": "/" }
  ]
}
```

```dart
final guide = DolphinController(navigatorKey: navigatorKey);   // same key as MaterialApp
await guide.startJourney('tour');                 // resumes where it stopped
await guide.startJourney('tour', restart: true);  // from leg 1, shows steps again
```

* When a leg's steps are done, dolphin opens the next leg's route with `pushNamed(route, arguments:)`. For any other router, pass `journeyNavigator: (context, leg, journey) async => context.go(...)`.
* If the page is already on screen, it starts there without navigating.
* Journey position is persisted, so `guide.resumeActiveJourney()` on app start continues an interrupted journey.
* Leaving out `steps` in a leg means "every pending step of that page".
* Skipping inside a leg stops the journey by default (`JourneySkipBehavior.continueJourney` keeps going).
* Journeys can also be defined in Dart: `guide.registerJourney(DolphinJourney(id: 'tour', legs: [...]))`.

## Sequence and exclude

```dart
await guide.setSequence('home', ['fab', 'search', 'profile']);   // custom order
await guide.exclude('home', ['beta_feature']);                   // never show
await guide.include('home', ['beta_feature']);                   // undo
// add persist: true to remember them across launches
```

Or in JSON: `"sequence": [...]`, `"exclude": [...]`, or on the page: `DolphinScope(sequence: [...], exclude: {...})`. Steps not listed in a sequence follow the listed ones in their natural order. A step's `order` field is another way to sort.

## Reset and rewatch

```dart
await guide.resetAll();                     // "Rewatch walkthrough" in settings
await guide.resetScope('home');             // reset one section
await guide.resetScopes(['home', 'cart']);
await guide.resetSteps('home', ['search']); // single steps
await guide.resetJourney('tour');
```

Visible pages restart right away (pass `restart: false` to stop that). Resets are timestamped, so a later server merge does not bring old "seen" records back.

## Progress, storage, and server sync

### What is tracked

For every step: seen, skipped, or unseen, plus when and which content version. For every page: its step list, the last step shown, and when it was completed. For every journey: its current leg and whether it is active or completed.

```dart
guide.isSeen('home', 'search');
guide.pendingSteps('home');        // ['fab', 'profile']
guide.scopeStatus('home');         // notStarted / inProgress / completed
guide.summary('home');             // ScopeSummary: steps, seen, pending, status
guide.summaries();                 // every known page
guide.progress;                    // DolphinProgress snapshot
guide.progressListenable;          // ValueListenable for UI
```

### Local storage (automatic)

The default store keeps small flags (enabled, disabled pages, saved sequences) in **SharedPreferences** and progress in a local **SQLite** database (one row per step, page, and journey) on Android, iOS, and macOS. On web, Windows, and Linux, SharedPreferences holds both. If SQLite fails to open, dolphin falls back to SharedPreferences by itself.

To use your own database or cloud storage, implement `DolphinStore` or use the built-in ones:

```dart
DolphinController(store: MyDatabaseDolphinStore());
DolphinController(store: MemoryDolphinStore());   // nothing persisted locally
DolphinController(store: HybridDolphinStore(flags: SharedPreferencesDolphinStore(), progress: SqfliteDolphinStore()));
```

### Giving data to your backend

dolphin never needs to know your schema. It hands you the data, and you store it however you like:

```dart
DolphinController(
  onProgressChanged: (progress) => api.saveGuideProgress(progress.toJson()),
);
// or anytime:
final json = guide.exportProgress();
```

### Loading data from your backend (device change)

```dart
await guide.importProgress(
  serverJson,               // what you fetched
  useProvidedData: true,    // false = ignore it and keep using local data
  updateLocal: true,        // true = write it to local storage, false = this session only
  strategy: MergeStrategy.union,   // union (default) / remoteWins / localWins
);
```

With `union`, a step seen on either device counts as seen, so a user who changes phones only sees the steps they haven't seen yet. One call can do the whole round trip:

```dart
await guide.syncWithServer(
  fetch: () => api.getGuideProgress(),
  push: (merged) => api.saveGuideProgress(merged),
);
```

## Events and analytics

```dart
DolphinController(onEvent: (e) => analytics.log(e.type.name, {'scope': e.scope, 'step': e.step}));
guide.events.listen(...);  // the same events as a stream
```

Event types include `scopeStarted`, `stepShown`, `stepCompleted`, `stepSkippedMissingTarget` (with the reason), `scopeCompleted`, `scopeSkipped`, `dismissed`, `paused`, `resumed`, `journeyLegStarted`, `journeyCompleted`, `journeyStopped`, `reset`, and `progressImported`. Set `debugLogging: true` to print them.

## Reliability guarantees

* **A RenderBox error never breaks your page.** Every geometry read goes through `TargetGeometry.measure`, which checks `mounted`, `attached`, `hasSize`, empty and non-finite sizes, and catches everything. Layout values are clamped and checked for NaN.
* **Targets that aren't there are skipped,** whether unregistered, unmounted, zero-sized, or off screen and impossible to scroll to. They stay unseen and show on a later visit (`skipAndMarkSeen` changes that). A target that disappears while it is showing moves the guide on to the next step.
* **No page breaks without setup.** `DolphinTarget` and `DolphinScope` without an `Dolphin` ancestor render their child untouched.
* **Storage and JSON errors are reported, not thrown.** Bad JSON produces an empty config, unknown keys are ignored, and store failures go to `onError` while dolphin keeps working from memory.
* **The highlight follows the target** through scrolling, keyboard, rotation, and animations. It re-measures after each frame and never schedules frames on its own.
* **Same position on iOS, Android and web.** Targets are measured against the overlay they are drawn on (not the screen), and a page only starts after its route transition has finished, so the slower iOS slide and the swipe-back gesture can't capture a half-moved position. Tests cover both platforms' transitions, a notch, and a cancelled iOS swipe-back. `example/integration_test` runs the same check on a real phone.
* **Lazy lists:** a `ListView.builder` item that hasn't been built yet doesn't exist, so it is treated as missing (use `waitForTarget`, or point the step at a widget that is built).

## JSON reference

```jsonc
{
  "version": 1,
  "theme": { /* any theme key below */ },
  "scopes": {
    "<scopeId>": {
      "autoStart": true,
      "enabled": true,
      "startDelayMs": 350,
      "sequence": ["a", "b"],
      "exclude": ["c"],
      "theme": { },
      "steps": {                     // or a list of objects with "id"
        "<stepId>": {
          "title": "", "description": "", "imageAsset": "", "imageUrl": "",
          "order": 1, "version": 1,
          "condition": "registeredConditionName",
          "position": "auto|above|below|left|right|center",
          "targetTap": "advance|passThrough|passThroughAndAdvance|block",
          "barrierTap": "none|next|dismiss|skipScope",
          "pointerMode": "auto|manual", "pointerX": 0.8, "pointerOffset": 40,
          "fallbackRect": { "x": 0.85, "y": 0.03, "width": 0.1, "height": 0.05 },
          "missingTarget": "skip|skipAndMarkSeen|showCentered",
          "counterText": "Last one!",
          "autoAdvanceMs": 4000, "waitForTargetMs": 1000, "scrollIntoView": true,
          "semanticsLabel": "",
          "theme": { },              // theme keys can also go directly on the step
          "anyOtherKey": "goes to step.extra for custom builders"
        }
      }
    }
  },
  "journeys": {
    "<journeyId>": [ { "scope": "page4", "steps": ["a"], "route": "/page4", "arguments": {} } ]
  }
}
```

**Theme keys:** `barrierColor`, `barrierOpacity` (0 to 1), `barrierBlur`, `shape` (`"circle"`, `"diamond"`, `"beveled"` or `{"type":"rounded","radius":16}`), `highlightPadding` (a number, `[h,v]`, `[l,t,r,b]`, or an object), `highlightOffset` (`[x, y]`), `highlightBorderColor`, `highlightBorderWidth`, `highlightBorderDash` (`[6, 4]`), `highlightBorderGradient` (`["#ff0000", "#0000ff"]` or `{colors, begin, end}`), `highlightGlowColor`, `highlightGlowBlur`, `pulseColor`, `tooltipStyle`, `tooltipPosition`, `tooltipBackgroundColor`, `tooltipForegroundColor`, `primaryColor`, `tooltipBorderRadius`, `tooltipPadding`, `tooltipMaxWidth`, `screenMargin`, `targetGap`, `titleStyle` / `descriptionStyle` / `counterStyle` / `buttonTextStyle` (`{color, fontSize, fontWeight, height}`), `pointer` (`{kind, dotSizes, dotSpacing, dotColors, dotShape, arrowWidth, arrowHeight, color, dotColor, lineWidth, lineLength, edgeInset}`), `counterFormat`, `showCounter`, `showSkip`, `showPrevious`, `showNext`, `nextLabel`, `previousLabel`, `skipLabel`, `finishLabel`, `animation` (`true`/`false` or `{enabled, fadeMs, moveMs, transition, pulse, pulseMs}`), `targetTapBehavior`, `barrierTapBehavior`, `backButtonBehavior`, `respectSafeArea`, `dark` (an object with any of these keys, used in dark mode). Colours are `#RRGGBB`, `#AARRGGBB`, or `0xAARRGGBB`.

## API cheat sheet

| Need | Call |
| --- | --- |
| Start or continue a page | `start(scope)` |
| Show a page again without forgetting | `replay(scope)` |
| Next / back / skip page / close | `next()` / `previous()` / `skipScope()` / `dismiss()` |
| Pause / resume | `pause()` / `resume([scope])` |
| Turn tips on or off | `setEnabled(bool)`, `setScopeEnabled(scope, bool)` |
| Order and hide steps | `setSequence`, `clearSequence`, `exclude`, `include` |
| Rewatch | `resetAll()`, `resetScope()`, `resetScopes()`, `resetSteps()`, `resetJourney()` |
| Journeys | `startJourney(id)`, `stopJourney()`, `resumeActiveJourney()`, `registerJourney()` |
| Data out | `exportProgress()`, `progress`, `progressListenable`, `onProgressChanged` |
| Data in | `importProgress(data, useProvidedData:, updateLocal:, strategy:)`, `syncWithServer()` |
| Reports | `isSeen`, `pendingSteps`, `hasPending`, `scopeStatus`, `summary`, `summaries`, `stepsOf` |
| Config | `setConfig`, `mergeConfig`, `loadConfigJson`, `registerTooltipBuilder`, `registerCondition` |
| State | `isShowing`, `activeStep`, `activeScope`, `activeJourney`, `events` |

## Testing your app with dolphin

Use `MemoryDolphinStore()`, `startDelay: Duration.zero`, and `theme: DolphinTheme(animation: DolphinAnimation.none())`. The pulse animation repeats forever, so `pumpAndSettle` never settles while it is on. See `test/` for examples covering auto-start, tap-through navigation and resume, journeys, missing targets, sync, every preset, dark mode, and the iOS and Android transitions.

To check a real phone, run the device test from the example app: `cd example && flutter test integration_test -d <device id>`.

## Example app

The [`example`](example) folder is a complete app that shows every feature: central JSON, inline data, all tooltip presets, the dots pointer, tap-through navigation with resume, a journey from page 4 to page 8, light and dark mode, and a settings page with rewatch, per-section reset, progress JSON and a simulated device change.

```bash
git clone https://github.com/sanket-manohar/dolphin.git
cd dolphin/example
flutter run
```

## License and disclaimer

dolphin is free to use in personal and commercial apps under the [BSD 3-Clause License](LICENSE). You may not use the author's name, the dolphin name or its logo to promote or publish a copy or a modified version as the original.

dolphin is provided "as is", without warranty of any kind. The author is not responsible for any bug, crash, misbehaviour or loss caused by using it in your project, or for any data in your app, including the walkthrough progress it stores on the device and anything you sync with your own servers. dolphin makes no network requests and collects no personal data. See [DISCLAIMER.md](DISCLAIMER.md) for the full notice.

Made by [Sanket Manohar](https://sanketmanohar.com).
