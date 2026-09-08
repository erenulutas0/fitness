import 'dart:io';
import 'dart:math' as math;

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

void main() {
  final catalog = CueCatalog.parse(
    File('../../content/cues/cues.json').readAsStringSync(),
  );

  RepResult rep(
    int index, {
    List<String> failed = const [],
    double score = 100,
  }) => RepResult(
    index: index,
    summary: RepSummary(
      index: index,
      startMs: 0,
      peakMs: 900,
      extremeMs: 1000,
      endMs: 2000,
      startValue: 170,
      extremeValue: 90,
    ),
    score: RepScore(
      score: score,
      penalties: {for (final f in failed) f: 40},
      cleanThreshold: 85,
    ),
    ruleResults: {
      for (final f in failed)
        f: RuleResult(
          ruleId: f,
          triggered: true,
          confidence: 0.9,
          fraction: 0.6,
        ),
    },
  );

  RuleEvent ruleEvent(
    String id, {
    String? cue,
    int severity = 2,
    double confidence = 0.9,
    int rep = 1,
  }) => RuleEvent(
    ruleId: id,
    cue: cue ?? id,
    severity: severity,
    confidence: confidence,
    tMs: 0,
    evaluateAt: EvaluateAt.instant,
    repIndex: rep,
  );

  FeedbackScheduler make({
    FeedbackPolicy policy = const FeedbackPolicy(),
    String locale = 'tr',
  }) => FeedbackScheduler(
    catalog: catalog,
    policy: policy,
    locale: locale,
    random: math.Random(1),
  );

  test('rep completion produces the count cue first', () {
    final s = make();
    final out = s.handle([SessionRepCompleted(2000, rep(1))], nowMs: 2000);
    expect(out.first.clipId, 'count_1');
    expect(out.first.text, 'bir');
    expect(out.first.haptic, HapticKind.tick);
  });

  test('count cue is localized', () {
    final s = make(locale: 'en');
    final out = s.handle([SessionRepCompleted(2000, rep(3))], nowMs: 2000);
    expect(out.first.text, 'three');
  });

  test(
    'highest severity × confidence wins when several rules fire at once',
    () {
      final s = make();
      final out = s.handle(
        [
          SessionRuleTriggered(
            100,
            ruleEvent('heel_rise', cue: 'heels_down', severity: 2),
          ),
          SessionRuleTriggered(
            100,
            ruleEvent('knee_valgus', cue: 'knees_out', severity: 3),
          ),
          SessionRuleTriggered(
            100,
            ruleEvent(
              'torso_lean',
              cue: 'chest_up',
              severity: 2,
              confidence: 0.99,
            ),
          ),
        ],
        nowMs: 100,
      );
      expect(out.length, 1);
      expect(out.single.clipId, 'knees_out');
      expect(out.single.ruleId, 'knee_valgus');
      expect(out.single.haptic, HapticKind.pulse);
      expect(out.single.text, 'Dizlerini dışa aç');
    },
  );

  test('same cue respects the cooldown across reps', () {
    final s = make();
    final a = s.handle([
      SessionRuleTriggered(
        0,
        ruleEvent('knee_valgus', cue: 'knees_out', rep: 1),
      ),
    ], nowMs: 0);
    final b = s.handle([
      SessionRuleTriggered(
        1000,
        ruleEvent('knee_valgus', cue: 'knees_out', rep: 2),
      ),
    ], nowMs: 1000);
    final c = s.handle([
      SessionRuleTriggered(
        4500,
        ruleEvent('knee_valgus', cue: 'knees_out', rep: 2),
      ),
    ], nowMs: 4500);
    expect(a, isNotEmpty);
    expect(b, isEmpty);
    expect(c, isNotEmpty);
  });

  test('within the same rep / hold the same cue waits longer', () {
    final s = make();
    final a = s.handle([
      SessionRuleTriggered(0, ruleEvent('hip_sag', cue: 'hips_up', rep: 1)),
    ], nowMs: 0);
    final b = s.handle([
      SessionRuleTriggered(4500, ruleEvent('hip_sag', cue: 'hips_up', rep: 1)),
    ], nowMs: 4500);
    final c = s.handle([
      SessionRuleTriggered(6500, ruleEvent('hip_sag', cue: 'hips_up', rep: 1)),
    ], nowMs: 6500);
    expect(a, isNotEmpty);
    expect(b, isEmpty);
    expect(c, isNotEmpty);
  });

  test('low-confidence rule events never become cues', () {
    final s = make();
    final out = s.handle([
      SessionRuleTriggered(
        0,
        ruleEvent('knee_valgus', cue: 'knees_out', confidence: 0.3),
      ),
    ], nowMs: 0);
    expect(out, isEmpty);
  });

  test('persistent error: rephrase after 3 reps, mute after 5', () {
    final s = make();
    final variants = <int>[];
    var muted = false;
    for (var i = 1; i <= 7; i++) {
      final t = i * 5000;
      final out = s.handle(
        [
          SessionRepCompleted(t, rep(i, failed: ['knee_valgus'], score: 60)),
          SessionRuleTriggered(
            t,
            ruleEvent('knee_valgus', cue: 'knees_out', severity: 3, rep: i),
          ),
        ],
        nowMs: t,
      );
      final cue = out.where((c) => c.ruleId == 'knee_valgus').toList();
      if (cue.isEmpty) {
        muted = true;
      } else {
        expect(muted, isFalse, reason: 'cue came back after mute');
        variants.add(cue.single.variant);
      }
    }
    expect(variants.length, lessThan(7));
    expect(muted, isTrue);
    expect(s.mutedRules, contains('knee_valgus'));
    expect(
      variants.toSet().length,
      greaterThan(1),
      reason: 'phrasing should vary',
    );
  });

  test(
    'positive reinforcement every ~3 clean reps and never with a correction',
    () {
      final s = make(policy: const FeedbackPolicy(positiveJitter: 0));
      final positives = <int>[];
      for (var i = 1; i <= 9; i++) {
        final t = i * 3000;
        final out = s.handle([SessionRepCompleted(t, rep(i))], nowMs: t);
        if (out.any((c) => c.clipId == 'nice')) positives.add(i);
      }
      expect(positives, [3, 6, 9]);

      final s2 = make(policy: const FeedbackPolicy(positiveJitter: 0));
      for (var i = 1; i <= 2; i++) {
        s2.handle([SessionRepCompleted(i * 3000, rep(i))], nowMs: i * 3000);
      }
      final out = s2.handle(
        [
          SessionRepCompleted(9000, rep(3)),
          SessionRuleTriggered(
            9000,
            ruleEvent('shallow_depth', cue: 'go_deeper', rep: 3),
          ),
        ],
        nowMs: 9000,
      );
      expect(out.map((c) => c.clipId), isNot(contains('nice')));
    },
  );

  test('quiet mode keeps counts and only severity-3 cues', () {
    final s = make(policy: const FeedbackPolicy(quietMode: true));
    final out = s.handle(
      [
        SessionRepCompleted(0, rep(1)),
        SessionRuleTriggered(
          0,
          ruleEvent('shallow_depth', cue: 'go_deeper', severity: 2),
        ),
      ],
      nowMs: 0,
    );
    expect(out.map((c) => c.clipId), ['count_1']);
    final out2 = s.handle([
      SessionRuleTriggered(
        100,
        ruleEvent('knee_valgus', cue: 'knees_out', severity: 3),
      ),
    ], nowMs: 100);
    expect(out2.map((c) => c.clipId), ['knees_out']);
  });

  test('tracking loss says "cant_see_you" at most once per window', () {
    final s = make();
    final a = s.handle([
      const SessionTrackingChanged(0, tracking: false, confidence: 0.2),
    ], nowMs: 0);
    final b = s.handle([
      const SessionTrackingChanged(3000, tracking: false, confidence: 0.2),
    ], nowMs: 3000);
    final c = s.handle([
      const SessionTrackingChanged(9000, tracking: false, confidence: 0.2),
    ], nowMs: 9000);
    expect(a.single.clipId, 'cant_see_you');
    expect(a.single.interrupts, isTrue);
    expect(b, isEmpty);
    expect(c, isNotEmpty);
  });

  test('end-to-end: session events → cues for a valgus set', () {
    final def = ExerciseDefinition.parse(
      File('../../content/exercises/bw_squat.json').readAsStringSync(),
    );
    final session = ExerciseSession(
      definition: def,
      view: CameraView.front,
      config: const SessionConfig(smoothing: SmoothingConfig.none),
    );
    final scheduler = make();
    final cues = <CueCommand>[];
    for (final f in const SyntheticPose().squat(
      view: CameraView.front,
      reps: 3,
      valgus: 0.3,
    )) {
      cues.addAll(scheduler.handle(session.process(f), nowMs: f.timestampMs));
    }
    final ids = cues.map((c) => c.clipId).toList();
    expect(ids, contains('knees_out'));
    expect(ids, containsAll(['count_1', 'count_2', 'count_3']));
    expect(ids, isNot(contains('nice')));
  });
}
