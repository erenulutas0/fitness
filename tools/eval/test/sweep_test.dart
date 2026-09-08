import 'dart:convert';
import 'dart:io';

import 'package:forma_eval/forma_eval.dart';
import 'package:forma_eval/sweep.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

final _squatFile = File('../../content/exercises/bw_squat.json');

ExerciseDefinition _squat() =>
    ExerciseDefinition.parse(_squatFile.readAsStringSync());

Map<String, dynamic> _json() =>
    json.decode(json.encode(_squat().toJson())) as Map<String, dynamic>;

Map<String, dynamic> _repSpec(Map<String, dynamic> json, String view) =>
    (json['rep']! as Map<String, dynamic>)[view]! as Map<String, dynamic>;

/// A corpus of synthetic front-view squats: three clean sets and three with
/// the knees caving in, every rep labelled, so precision and recall both mean
/// something.
EvalCorpus _syntheticCorpus() {
  final def = _squat();
  final fixtures = <LandmarkFixture>[];
  for (var i = 0; i < 3; i++) {
    fixtures
      ..add(
        LandmarkFixture(
          id: 'clean_$i',
          exerciseId: def.id,
          view: CameraView.front,
          synthetic: true,
          expectedReps: 3,
          frames: const SyntheticPose().squat(
            view: CameraView.front,
            reps: 3,
            noiseStd: 0,
          ),
        ),
      )
      ..add(
        LandmarkFixture(
          id: 'valgus_$i',
          exerciseId: def.id,
          view: CameraView.front,
          synthetic: true,
          expectedReps: 3,
          errorLabels: [
            for (var rep = 1; rep <= 3; rep++)
              FixtureLabel(rep: rep, rules: const ['knee_valgus']),
          ],
          frames: const SyntheticPose().squat(
            view: CameraView.front,
            reps: 3,
            valgus: 0.3,
            noiseStd: 0,
          ),
        ),
      );
  }
  return EvalCorpus(
    definitions: {def.id: def},
    catalog: const CueCatalog({}),
    fixtures: fixtures,
  );
}

void main() {
  group('SweepAxis', () {
    test('parses a start:end:step range', () {
      final axis = SweepAxis.parse('rules.shallow_depth.threshold=100:110:2.5');
      expect(axis.path, 'rules.shallow_depth.threshold');
      expect(axis.values, [100, 102.5, 105, 107.5, 110]);
      expect(axis.ruleId, 'shallow_depth');
    });

    test('parses a list and an exercise prefix', () {
      final axis = SweepAxis.parse('push_up/rep.side.peakThreshold=90, 95,100');
      expect(axis.exerciseId, 'push_up');
      expect(axis.path, 'rep.side.peakThreshold');
      expect(axis.values, [90, 95, 100]);
    });

    test('a fractional step does not drift', () {
      expect(SweepAxis.parse('smoothing.beta=0:0.3:0.1').values, [
        0,
        0.1,
        0.2,
        0.3,
      ]);
    });

    test('rejects nonsense', () {
      expect(() => SweepAxis.parse('no-range'), throwsA(isA<SweepException>()));
      expect(
        () => SweepAxis.parse('a.b=1:2'),
        throwsA(isA<SweepException>()),
      );
      expect(
        () => SweepAxis.parse('a.b=10:1:1'),
        throwsA(isA<SweepException>()),
      );
      expect(
        () => SweepAxis.parse('a.b=1:10:0'),
        throwsA(isA<SweepException>()),
      );
    });

    test('session-level paths are recognised', () {
      expect(SweepAxis.parse('smoothing.beta=0,1').isSessionLevel, isTrue);
      expect(
        SweepAxis.parse('session.maxShinThighRatio=1,2').isSessionLevel,
        isTrue,
      );
      expect(
        SweepAxis.parse('rep.side.hysteresis=5,8').isSessionLevel,
        isFalse,
      );
    });
  });

  group('parameter paths', () {
    test('reads and writes a rep threshold', () {
      final json = _json();
      expect(readOverride(json, 'rep.side.peakThreshold'), 125);
      applyOverride(json, 'rep.side.peakThreshold', 118);
      expect(readOverride(json, 'rep.side.peakThreshold'), 118);
      expect(
        ExerciseDefinition.fromJson(
          json,
        ).repFor(CameraView.side)!.peakThreshold,
        118,
      );
    });

    test('millisecond fields stay integers', () {
      final json = _json();
      applyOverride(json, 'rep.side.minDurationMs', 800);
      expect(_repSpec(json, 'side')['minDurationMs'], isA<int>());
    });

    test('reads and rewrites the number inside a rule expression', () {
      final json = _json();
      expect(readOverride(json, 'rules.shallow_depth.threshold'), 105);
      applyOverride(json, 'rules.shallow_depth.threshold', 112.5);
      final rule = (json['rules'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'shallow_depth');
      expect(rule['expr'], 'min(knee_angle) > 112.5');
    });

    test('a digit inside an identifier is not a threshold', () {
      final json = _json();
      applyOverride(json, 'rules.shallow_depth_front.threshold', 110);
      final rule = (json['rules'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'shallow_depth_front');
      expect(rule['expr'], 'min(knee_angle_3d) > 110');
    });

    test('one threshold written twice moves as one', () {
      final json = _json();
      applyOverride(json, 'rules.knee_valgus.threshold', 0.8);
      final rule = (json['rules'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'knee_valgus');
      expect(
        rule['expr'],
        'knee_ankle_ratio_l < 0.8 || knee_ankle_ratio_r < 0.8',
      );
    });

    test(
      'an expression with two different numbers has to be disambiguated',
      () {
        final json = _json();
        final rule = (json['rules'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((r) => r['id'] == 'shallow_depth');
        rule['expr'] = 'min(knee_angle) > 105 && max(torso_angle) < 60';
        expect(
          () => applyOverride(json, 'rules.shallow_depth.threshold', 110),
          throwsA(isA<SweepException>()),
        );
        applyOverride(json, 'rules.shallow_depth.threshold@105', 110);
        expect(rule['expr'], 'min(knee_angle) > 110 && max(torso_angle) < 60');
      },
    );

    test('unknown paths fail loudly', () {
      final json = _json();
      expect(
        () => applyOverride(json, 'rules.nope.threshold', 1),
        throwsA(isA<SweepException>()),
      );
      expect(
        () => applyOverride(json, 'rep.restThreshold', 150),
        throwsA(isA<SweepException>()),
      );
      expect(
        () => applyOverride(json, 'score.nope', 1),
        throwsA(isA<SweepException>()),
      );
    });
  });

  group('runSweep', () {
    test('finds the threshold that separates the labelled sets', () {
      final result = runSweep(
        corpus: _syntheticCorpus(),
        axes: [SweepAxis.parse('rules.knee_valgus.threshold=0.70:0.95:0.05')],
        exerciseId: 'bw_squat',
      );
      expect(result.objective.label, 'knee_valgus F1');
      expect(result.points, hasLength(6));
      expect(result.currentValues.single, 0.85);
      // The valgus sets are labelled and the clean ones are not, so a usable
      // threshold has to score better than one that fires on everything.
      expect(result.best.score, greaterThan(0));
      expect(
        result.best.score,
        greaterThanOrEqualTo(result.points.first.score),
      );
    });

    test('a rep-threshold sweep is scored on rep counting', () {
      final result = runSweep(
        corpus: _syntheticCorpus(),
        axes: [SweepAxis.parse('rep.front.peakThreshold=120:130:5')],
        exerciseId: 'bw_squat',
      );
      expect(result.objective.higherIsBetter, isFalse);
      expect(result.objective.label, 'rep MAE');
      expect(result.baseline.repMae, 0);
      expect(result.supported, isTrue);
    });

    test('refuses a grid that would take all day', () {
      expect(
        () => runSweep(
          corpus: _syntheticCorpus(),
          axes: [SweepAxis.parse('rules.knee_valgus.threshold=0:1:0.001')],
          exerciseId: 'bw_squat',
        ),
        throwsA(isA<SweepException>()),
      );
    });

    test('says so when the corpus cannot answer the question', () {
      final corpus = _syntheticCorpus();
      final unlabelled = EvalCorpus(
        definitions: corpus.definitions,
        catalog: corpus.catalog,
        fixtures: [
          for (final f in corpus.fixtures)
            if (f.errorLabels.isEmpty) f,
        ],
      );
      final result = runSweep(
        corpus: unlabelled,
        axes: [SweepAxis.parse('rules.knee_valgus.threshold=0.8:0.9:0.05')],
        exerciseId: 'bw_squat',
      );
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first, contains('error label'));
      expect(result.supported, isFalse);
      expect(result.toMarkdown(), contains('No suggestion.'));
    });

    test('never writes to content', () {
      final before = _squatFile.readAsStringSync();
      runSweep(
        corpus: _syntheticCorpus(),
        axes: [SweepAxis.parse('rules.knee_valgus.threshold=0.70:0.95:0.05')],
        exerciseId: 'bw_squat',
      );
      expect(_squatFile.readAsStringSync(), before);
      final markdown = runSweep(
        corpus: _syntheticCorpus(),
        axes: [SweepAxis.parse('rules.knee_valgus.threshold=0.80:0.90:0.05')],
        exerciseId: 'bw_squat',
      ).toMarkdown();
      expect(
        markdown,
        contains('Nothing was written').or(
          contains('no reason to change'),
        ),
      );
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
