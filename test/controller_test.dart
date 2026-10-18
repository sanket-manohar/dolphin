import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphin/dolphin.dart';

import 'test_utils.dart';

DolphinConfig cfg(Map<String, List<String>> scopes,
        {Map<String, dynamic> extra = const {}}) =>
    DolphinConfig.fromJson({
      'scopes': {
        for (final e in scopes.entries)
          e.key: {
            'steps': {
              for (final id in e.value)
                id: {'title': 'Title $id', 'description': 'About $id'}
            },
            ...?extra[e.key] as Map<String, dynamic>?,
          }
      }
    });

void main() {
  testWidgets('auto-starts, counts 1/2 -> 2/2, persists, does not restart',
      (tester) async {
    final store = MemoryDolphinStore();
    final c = makeController(
        config: cfg({
          'home': ['a', 'b']
        }),
        store: store);
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a', 'b'])));
    await settle(tester);

    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Title b'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Skip'), findsNothing, reason: 'no skip on the last step');
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Title b'), findsNothing);
    expect(c.scopeStatus('home'), ScopeStatus.completed);
    await c.flush();
    expect(store.progress.seenSteps('home').toSet(), {'a', 'b'});

    // Rebuild: nothing pending, nothing shows.
    await tester.pumpWidget(wrapApp(c,
        home: const SimplePage(
            key: ValueKey(2), scope: 'home', targets: ['a', 'b'])));
    await settle(tester);
    expect(find.text('Title a'), findsNothing);
  });

  testWidgets('inline data on the target works without any config',
      (tester) async {
    final c = makeController();
    await tester.pumpWidget(wrapApp(c,
        home: const DolphinScope(
          id: 'p',
          child: Scaffold(
            body: Center(
              child: DolphinTarget(
                id: 'fab',
                title: 'Inline title',
                description: 'Inline description',
                child: Icon(Icons.add),
              ),
            ),
          ),
        )));
    await settle(tester);
    expect(find.text('Inline title'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
  });

  testWidgets('central data wins over inline by default; inlineWins flips it',
      (tester) async {
    for (final precedence in DataPrecedence.values) {
      final c = makeController(
          config: DolphinConfig.fromJson({
        'scopes': {
          'p': {
            'steps': {
              's': {'title': 'Central'}
            }
          }
        }
      }))
        ..dataPrecedence = precedence;
      await tester.pumpWidget(wrapApp(c,
          home: DolphinScope(
            key: ValueKey(precedence),
            id: 'p',
            child: const Scaffold(
              body: Center(
                child: DolphinTarget(
                    id: 's',
                    title: 'Inline',
                    description: 'D',
                    child: Text('x')),
              ),
            ),
          )));
      await settle(tester);
      expect(
          find.text(
              precedence == DataPrecedence.centralWins ? 'Central' : 'Inline'),
          findsOneWidget);
      expect(find.text('D'), findsOneWidget, reason: 'fields merge');
      c.dismiss();
      await settle(tester);
    }
  });

  testWidgets('missing / unmounted targets are skipped and not counted',
      (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a', 'ghost', 'b']
    }));
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a', 'b'])));
    await settle(tester);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Title b'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(c.pendingSteps('home'), ['ghost'],
        reason: 'kept for when it mounts');
  });

  testWidgets('a target that disappears while shown moves on safely',
      (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a', 'b']
    }));
    final show = ValueNotifier(true);
    await tester.pumpWidget(wrapApp(c,
        home: DolphinScope(
          id: 'home',
          child: Scaffold(
            body: Column(children: [
              ValueListenableBuilder<bool>(
                valueListenable: show,
                builder: (_, v, __) => v
                    ? const DolphinTarget(id: 'a', child: Text('A'))
                    : const SizedBox(),
              ),
              const DolphinTarget(id: 'b', child: Text('B')),
            ]),
          ),
        )));
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
    show.value = false;
    await settle(tester);
    expect(find.text('Title b'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip all marks only that page', (tester) async {
    final c = makeController(
        config: cfg({
      'one': ['a', 'b', 'c'],
      'two': ['x']
    }));
    await tester.pumpWidget(wrapApp(c,
        home: const SimplePage(scope: 'one', targets: ['a', 'b', 'c']),
        routes: {
          '/two': (_) => const SimplePage(scope: 'two', targets: ['x'])
        }));
    await settle(tester);
    await tester.tap(find.text('Skip'));
    await settle(tester);
    expect(c.pendingSteps('one'), isEmpty);
    expect(c.progress.step('one', 'b')!.status, StepStatus.skipped);
    expect(c.pendingSteps('two'), ['x']);
  });

  testWidgets('tap-through navigation pauses and resumes where it left off',
      (tester) async {
    final c = makeController(
      config: cfg({
        'one': ['open', 'other'],
        'two': ['x']
      }, extra: {
        'one': {
          'steps': {
            'open': {
              'title': 'Title open',
              'targetTap': 'passThroughAndAdvance'
            },
            'other': {'title': 'Title other'},
          }
        }
      }),
    );
    await tester.pumpWidget(wrapApp(c,
        home: SimplePage(
          scope: 'one',
          targets: const ['open', 'other'],
          onTap: (ctx, id) {
            if (id == 'open') Navigator.of(ctx).pushNamed('/two');
          },
        ),
        routes: {
          '/two': (_) => const SimplePage(scope: 'two', targets: ['x'])
        }));
    await settle(tester);
    expect(find.text('Title open'), findsOneWidget);

    // Tap the real button through the hole.
    await tester.tap(find.text('btn open'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('page two'), findsOneWidget);
    expect(find.text('Title x'), findsOneWidget);
    expect(c.isSeen('one', 'open'), isTrue);
    await tester.tap(find.text('Done'));
    await settle(tester);

    Navigator.of(tester.element(find.text('page two'))).pop();
    await settle(tester);
    expect(find.text('Title other'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('dismiss keeps the step pending for next time', (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a']
    }));
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a'])));
    await settle(tester);
    c.dismiss();
    await settle(tester);
    expect(find.text('Title a'), findsNothing);
    expect(c.pendingSteps('home'), ['a']);
    expect(await c.start('home'), isTrue);
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('custom sequence and exclusion', (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a', 'b', 'c']
    }));
    await c.setSequence('home', ['c', 'a']);
    await c.exclude('home', ['b']);
    expect(c.stepsOf('home'), ['c', 'a'],
        reason: 'known from config before mounting');
    await tester.pumpWidget(wrapApp(c,
        home: const SimplePage(scope: 'home', targets: ['a', 'b', 'c'])));
    await settle(tester);
    expect(c.stepsOf('home'), ['c', 'a']);
    expect(find.text('Title c'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('reset page and reset all restart visible pages', (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a']
    }));
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a'])));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Title a'), findsNothing);

    await c.resetScope('home');
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);

    await c.resetAll();
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('bumping a step version shows it again', (tester) async {
    final store = MemoryDolphinStore(
      initial: DolphinProgress(steps: {
        'home/a': StepRecord(
            scope: 'home',
            step: 'a',
            status: StepStatus.seen,
            updatedAt: DateTime.utc(2026),
            version: 1),
      }),
    );
    final c = makeController(
        store: store,
        config: DolphinConfig.fromJson({
          'scopes': {
            'home': {
              'steps': {
                'a': {'title': 'Title a', 'version': 2}
              }
            }
          }
        }));
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a'])));
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets(
      'disabled walkthrough does not auto-start; manual start still works',
      (tester) async {
    final c = makeController(
        config: cfg({
      'home': ['a']
    }));
    await c.setEnabled(false);
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a'])));
    await settle(tester);
    expect(find.text('Title a'), findsNothing);
    await c.start('home');
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('journey: page4 steps, then opens page8 and continues',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final c = makeController(
      navigatorKey: nav,
      autoStart: false,
      config: DolphinConfig.fromJson({
        'scopes': {
          'page4': {
            'steps': {
              for (final id in ['a', 'b', 'z']) id: {'title': 'Title $id'}
            }
          },
          'page8': {
            'steps': {
              for (final id in ['c', 'd']) id: {'title': 'Title $id'}
            }
          },
        },
        'journeys': {
          'tour': [
            {
              'scope': 'page4',
              'steps': ['a', 'b']
            },
            {'scope': 'page8', 'route': '/page8'},
          ]
        }
      }),
    );
    await tester.pumpWidget(wrapApp(c,
        navigatorKey: nav,
        home: const SimplePage(scope: 'page4', targets: ['a', 'b', 'z']),
        routes: {
          '/page8': (_) => const SimplePage(scope: 'page8', targets: ['c', 'd'])
        }));
    await settle(tester);
    expect(find.text('Title a'), findsNothing, reason: 'autoStart off');

    c.startJourney('tour');
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.text('page page8'), findsOneWidget);
    expect(find.text('Title c'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(c.progress.journeys['tour']!.completed, isTrue);
    expect(c.pendingSteps('page4'), ['z'], reason: 'outside the journey leg');
  });

  group('sync', () {
    testWidgets('export from one device, import on another', (tester) async {
      final a = makeController(
          config: cfg({
        'home': ['a', 'b']
      }));
      await tester.pumpWidget(wrapApp(a,
          home: const SimplePage(scope: 'home', targets: ['a', 'b'])));
      await settle(tester);
      await tester.tap(find.text('Next'));
      await settle(tester);
      a.dismiss();
      await settle(tester);
      final exported = a.exportProgress();

      final storeB = MemoryDolphinStore();
      final b = makeController(
          config: cfg({
            'home': ['a', 'b']
          }),
          store: storeB);
      await b.importProgress(exported, useProvidedData: false);
      expect(b.isSeen('home', 'a'), isFalse,
          reason: 'flag says ignore the data');

      await b.importProgress(exported, updateLocal: false);
      expect(b.isSeen('home', 'a'), isTrue);
      await b.flush();
      expect(storeB.progress.steps, isEmpty, reason: 'session only');

      await b.importProgress(exported);
      await b.flush();
      expect(storeB.progress.isSeen('home', 'a'), isTrue);

      await tester.pumpWidget(wrapApp(b,
          home: const SimplePage(
              key: ValueKey('b'), scope: 'home', targets: ['a', 'b'])));
      await settle(tester);
      expect(find.text('Title b'), findsOneWidget,
          reason: 'only unseen steps show');
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('summaries report seen / pending per page', (tester) async {
      final c = makeController(
          config: cfg({
        'home': ['a', 'b'],
        'other': ['x']
      }));
      await c.importProgress({
        'steps': [
          {
            'scope': 'home',
            'step': 'a',
            'status': 'seen',
            'updatedAt': '2026-01-01T00:00:00Z'
          }
        ]
      });
      final s = c.summaries();
      expect(s['home']!.status, ScopeStatus.inProgress);
      expect(s['home']!.pending, ['b']);
      expect(s['other']!.status, ScopeStatus.notStarted);
    });

    test('onProgressChanged and events fire', () async {
      final events = <DolphinEventType>[];
      var changes = 0;
      final c = makeController()
        ..onEvent = ((e) => events.add(e.type))
        ..onProgressChanged = ((_) => changes++);
      await c.init();
      await c.importProgress({'steps': []});
      await c.resetAll(restart: false);
      expect(
          events,
          containsAll(
              [DolphinEventType.progressImported, DolphinEventType.reset]));
      expect(changes, greaterThan(0));
    });
  });

  testWidgets('every tooltip preset renders', (tester) async {
    for (final preset in TooltipPreset.values) {
      final c = makeController(
          config: cfg({
            'home': ['a']
          }),
          theme: DolphinTheme(tooltipStyle: preset.name, barrierBlur: 3));
      await tester.pumpWidget(wrapApp(c,
          home: SimplePage(
              key: ValueKey(preset), scope: 'home', targets: const ['a'])));
      await settle(tester);
      expect(find.text('Title a'), findsOneWidget, reason: preset.name);
      expect(tester.takeException(), isNull);
      c.dismiss();
      await settle(tester);
    }
  });

  testWidgets('registered custom tooltip by name from JSON', (tester) async {
    final c = makeController(
        config: DolphinConfig.fromJson({
      'scopes': {
        'home': {
          'steps': {
            'a': {'title': 'T', 'tooltipStyle': 'promo', 'cta': 'Buy now'}
          }
        }
      }
    }));
    c.registerTooltipBuilder(
        'promo',
        (context, t) => Material(
              child: TextButton(
                  onPressed: t.next,
                  child: Text('${t.step.extra['cta']} ${t.counterText}')),
            ));
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a'])));
    await settle(tester);
    expect(find.text('Buy now 1/1'), findsOneWidget);
  });

  testWidgets('condition from JSON gates a step', (tester) async {
    var premium = false;
    final c = makeController(
        config: DolphinConfig.fromJson({
      'scopes': {
        'home': {
          'steps': {
            'a': {'title': 'Title a', 'condition': 'isPremium'},
            'b': {'title': 'Title b'},
          }
        }
      }
    }));
    c.registerCondition('isPremium', () => premium);
    await tester.pumpWidget(
        wrapApp(c, home: const SimplePage(scope: 'home', targets: ['a', 'b'])));
    await settle(tester);
    expect(find.text('Title b'), findsOneWidget);
    premium = true;
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Title a'), findsOneWidget,
        reason: 'still pending, now allowed');
  });

  testWidgets('a target without a controller just renders its child',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: DolphinScope(
            id: 'x', child: DolphinTarget(id: 'a', child: Text('child')))));
    expect(find.text('child'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary keeps inline steps after the page closes',
      (tester) async {
    final c = makeController(
        config: cfg({
      'details': ['promo']
    }));
    await tester.pumpWidget(
        wrapApp(c, home: const Scaffold(body: Text('home')), routes: {
      '/details': (_) => const DolphinScope(
            id: 'details',
            child: Scaffold(
              body: Column(children: [
                DolphinTarget(
                    id: 'price', title: 'Price', order: 1, child: Text('p')),
                DolphinTarget(id: 'promo', child: Text('x')),
              ]),
            ),
          ),
    }));
    Navigator.of(tester.element(find.text('home'))).pushNamed('/details');
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);
    Navigator.of(tester.element(find.text('p'))).pop();
    await settle(tester);
    final s = c.summary('details');
    expect(s.stepIds.toSet(), {'price', 'promo'});
    expect(s.seen.length, 2);
    expect(s.status, ScopeStatus.completed);
  });
}
