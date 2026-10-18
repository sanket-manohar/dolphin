import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dolphin/dolphin.dart';

StepRecord rec(String scope, String step, DateTime at,
        {StepStatus status = StepStatus.seen, int version = 0}) =>
    StepRecord(
        scope: scope,
        step: step,
        status: status,
        updatedAt: at,
        version: version);

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = DateTime.utc(2026, 1, 2);
  final t2 = DateTime.utc(2026, 1, 3);

  group('DolphinConfig.fromJson', () {
    test('parses scopes, steps (map and list), sequence, exclude, journeys',
        () {
      final c = DolphinConfig.fromJson({
        'theme': {'barrierColor': '#80000000', 'tooltipStyle': 'bubble'},
        'scopes': {
          'home': {
            'sequence': ['b', 'a'],
            'exclude': ['c'],
            'autoStart': false,
            'steps': {
              'a': {
                'title': 'A',
                'shape': 'circle',
                'pointerX': 0.8,
                'cta': 'go'
              },
              'b': {'title': 'B', 'position': 'above', 'version': 2},
            },
          },
          'list': {
            'steps': [
              {
                'id': 'x',
                'title': 'X',
                'shape': {'type': 'rounded', 'radius': 20}
              },
            ],
          },
        },
        'journeys': {
          'onboarding': [
            {
              'scope': 'home',
              'steps': ['a']
            },
            {'scope': 'list', 'route': '/list'},
          ],
        },
      });
      expect(c.theme!.barrierColor, const Color(0x80000000));
      expect(c.theme!.tooltipStyle, 'bubble');
      final home = c.scopes['home']!;
      expect(home.sequence, ['b', 'a']);
      expect(home.exclude, {'c'});
      expect(home.autoStart, false);
      expect(home.steps['a']!.theme!.shape, isA<CircleHighlight>());
      expect(home.steps['a']!.pointerX, 0.8);
      expect(home.steps['a']!.extra['cta'], 'go');
      expect(home.steps['b']!.theme!.tooltipPosition, TooltipPosition.above);
      expect(home.steps['b']!.version, 2);
      final x = c.scopes['list']!.steps['x']!;
      expect((x.theme!.shape! as RoundedRectHighlight).radius, 20);
      expect(c.journeys['onboarding']!.legs.length, 2);
      expect(c.journeys['onboarding']!.legs[1].route, '/list');
    });

    test('garbage never throws', () {
      expect(DolphinConfig.fromJsonString('{not json').scopes, isEmpty);
      final c = DolphinConfig.fromJson({
        'scopes': {
          'p': {
            'steps': {
              's': {'title': 5, 'shape': 42, 'pointerX': 'abc', 'theme': 'x'},
              'bad': 'nope',
            },
            'sequence': 7,
          },
          'q': 'nope',
        },
        'journeys': {'j': 'nope'},
      });
      expect(c.scopes['p']!.steps['s']!.title, '5');
      expect(c.scopes['p']!.steps['s']!.pointerX, isNull);
      expect(c.scopes.containsKey('q'), isFalse);
      expect(c.journeys['j']!.legs, isEmpty);
    });

    test('merge prefers the other side field by field', () {
      const a =
          DolphinStep(id: 's', title: 'inline', description: 'inline desc');
      const b = DolphinStep(id: 's', title: 'central');
      final m = a.merge(b);
      expect(m.title, 'central');
      expect(m.description, 'inline desc');
    });
  });

  group('DolphinProgress', () {
    test('json round trip', () {
      final p = DolphinProgress(
        steps: {'h/a': rec('h', 'a', t1, version: 3)},
        scopes: {
          'h': ScopeRecord(
              scope: 'h', knownSteps: const ['a', 'b'], completedAt: t1)
        },
        journeys: {
          'j': JourneyRecord(id: 'j', legIndex: 1, active: true, updatedAt: t1)
        },
        resetAt: t0,
      );
      final back = DolphinProgress.fromJson(p.toJson());
      expect(back.step('h', 'a')!.version, 3);
      expect(back.scopes['h']!.knownSteps, ['a', 'b']);
      expect(back.journeys['j']!.legIndex, 1);
      expect(back.resetAt, t0);
      expect(back.scopeStatus('h'), ScopeStatus.inProgress);
    });

    test('union merge: seen anywhere wins, resets are respected', () {
      final local = DolphinProgress(steps: {'h/a': rec('h', 'a', t1)});
      final remote = DolphinProgress(steps: {
        'h/b': rec('h', 'b', t1),
        'h/c': rec('h', 'c', t0, status: StepStatus.unseen),
      });
      final m = local.merge(remote);
      expect(m.seenSteps('h').toSet(), {'a', 'b'});

      // Local reset of scope h after the remote records were written.
      final resetLocal = DolphinProgress(
          scopes: {'h': ScopeRecord(scope: 'h', resetAt: t2, updatedAt: t2)});
      expect(resetLocal.merge(remote).seenSteps('h'), isEmpty);

      // Global reset.
      final g = DolphinProgress(resetAt: t2);
      expect(g.merge(remote).steps, isEmpty);
    });

    test('remoteWins and localWins', () {
      final local = DolphinProgress(steps: {'h/a': rec('h', 'a', t1)});
      final remote = DolphinProgress(steps: {'h/b': rec('h', 'b', t1)});
      expect(
          local
              .merge(remote, strategy: MergeStrategy.remoteWins)
              .seenSteps('h'),
          ['b']);
      expect(
          local
              .merge(remote, strategy: MergeStrategy.localWins)
              .seenSteps('h')
              .toSet(),
          {'a', 'b'});
    });

    test('version: an older seen version does not count', () {
      final p = DolphinProgress(steps: {'h/a': rec('h', 'a', t1, version: 1)});
      expect(p.isSeen('h', 'a', version: 1), isTrue);
      expect(p.isSeen('h', 'a', version: 2), isFalse);
    });
  });

  group('SqfliteDolphinStore', () {
    setUpAll(sqfliteFfiInit);

    test('round trip with deltas, deletes and flags', () async {
      final store = SqfliteDolphinStore(
          databaseName: inMemoryDatabasePath,
          databaseFactory: databaseFactoryFfi);
      await store.init();
      var p = DolphinProgress(
        steps: {'h/a': rec('h', 'a', t1), 'h/b': rec('h', 'b', t1)},
        scopes: {
          'h': const ScopeRecord(scope: 'h', knownSteps: ['a', 'b'])
        },
        resetAt: t0,
      );
      await store.saveProgress(p, ProgressDelta.full());
      p = p.copyWith(steps: {'h/a': rec('h', 'a', t2)});
      await store.saveProgress(p, ProgressDelta(steps: {'h/a', 'h/b'}));
      final loaded = await store.loadProgress();
      expect(loaded.steps.keys, ['h/a']);
      expect(loaded.step('h', 'a')!.updatedAt, t2);
      expect(loaded.scopes['h']!.knownSteps, ['a', 'b']);
      expect(loaded.resetAt, t0);

      await store.setFlag('enabled', false);
      await store.setFlag('disabledScopes', ['x', 'y']);
      final flags = await store.loadFlags();
      expect(flags['enabled'], false);
      expect(flags['disabledScopes'], ['x', 'y']);
      await store.clearProgress();
      expect((await store.loadProgress()).isEmpty, isTrue);
      await store.dispose();
    });
  });
}
