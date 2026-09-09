import 'dart:io';

import 'package:forma_eval/forma_eval.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

EvalReport _report(Map<String, ExerciseStats> exercises) => EvalReport(
  exercises: exercises,
  fixtureCount: exercises.length,
  smoothing: true,
  generatedAt: DateTime.utc(2026),
);

ExerciseStats _stats(String id, {int tp = 0, int fp = 0, int fn = 0}) {
  final s = ExerciseStats(id);
  s.rule('r')
    ..tp = tp
    ..fp = fp
    ..fn = fn;
  return s;
}

void main() {
  group('gate 2', () {
    test('passes on evidence', () {
      expect(_report({'a': _stats('a', tp: 8, fp: 1, fn: 2)}).meetsGate2, true);
    });

    test('an exercise that measured nothing cannot pass', () {
      // precision and recall both default to 1 when there is nothing to
      // divide, so a corpus that proved nothing used to report PASS.
      expect(_report({'a': _stats('a')}).meetsGate2, isFalse);
      expect(_report({}).meetsGate2, isFalse);
      expect(
        _report({
          'a': _stats('a', tp: 8, fp: 1, fn: 2),
          'b': _stats('b'),
        }).meetsGate2,
        isFalse,
      );
    });

    test('a rule with no decisions prints n/a, not 100%', () {
      final md = _report({'a': _stats('a')}).toMarkdown();
      expect(md, contains('n/a'));
      expect(md, isNot(contains('100.0%')));
    });
  });

  test('cues per unit counts holds, not only reps', () {
    final s = ExerciseStats('plank')
      ..cues = 3
      ..detectedHolds = 2;
    expect(s.cuesPerRep, 1.5);
    final r = ExerciseStats('squat')
      ..cues = 3
      ..detectedReps = 6;
    expect(r.cuesPerRep, 0.5);
    expect(ExerciseStats('empty').cuesPerRep, 0);
  });

  test('a label the harness cannot evaluate is reported, not swallowed', () {
    final def = ExerciseDefinition.parse(
      File('../../content/exercises/bw_squat.json').readAsStringSync(),
    );
    final corpus = EvalCorpus(
      definitions: {def.id: def},
      catalog: const CueCatalog({}),
      fixtures: [
        LandmarkFixture(
          id: 'typo_fixture',
          exerciseId: def.id,
          view: CameraView.side,
          synthetic: true,
          expectedReps: 2,
          errorLabels: const [
            FixtureLabel(rep: 1, rules: ['shallow_dept']),
            FixtureLabel(rep: 2, rules: ['heel_rise']),
          ],
          frames: const SyntheticPose().squat(
            view: CameraView.side,
            reps: 2,
            noiseStd: 0,
          ),
        ),
      ],
    );
    final report = corpus.evaluate();
    expect(report.warnings, hasLength(2));
    expect(report.warnings.join(), contains('shallow_dept'));
    expect(report.warnings.join(), contains('heel_rise'));
  });
}
