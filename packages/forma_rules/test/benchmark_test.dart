import 'dart:io';

import 'package:forma_rules/forma_rules.dart';
import 'package:test/test.dart';

/// docs/10 Prompt 4: < 2 ms per frame at 30 Hz on a laptop; on a phone the
/// budget is looser but the whole Dart side must stay far below the 33 ms
/// frame period.
void main() {
  test('full pipeline stays under 2 ms per frame (average)', () {
    final def = ExerciseDefinition.parse(
      File('../../content/exercises/bw_squat.json').readAsStringSync(),
    );
    final frames = const SyntheticPose().squat(
      view: CameraView.front,
      reps: 20,
      valgus: 0.3,
      noiseStd: 0.004,
    );
    final session = ExerciseSession(definition: def, view: CameraView.front);
    final scheduler = FeedbackScheduler(
      catalog: CueCatalog.parse(
        File('../../content/cues/cues.json').readAsStringSync(),
      ),
    );
    // warm-up
    for (final f in frames.take(60)) {
      scheduler.handle(session.process(f), nowMs: f.timestampMs);
    }
    final sw = Stopwatch()..start();
    for (final f in frames.skip(60)) {
      scheduler.handle(session.process(f), nowMs: f.timestampMs);
    }
    sw.stop();
    final perFrameUs = sw.elapsedMicroseconds / (frames.length - 60);
    stdout.writeln(
      'pipeline: ${perFrameUs.toStringAsFixed(0)} µs/frame over ${frames.length - 60} frames',
    );
    expect(session.reps.length, 20);
    expect(perFrameUs, lessThan(2000));
  });

  test('a live correction fires within 400 ms of the error appearing', () {
    // Kapı 2 budget (docs/05 §10): movement → cue start ≤ 400 ms. This
    // measures the part we control — from the first frame on which the rule
    // is actually true, to the frame whose events carry the cue. Speaker and
    // engine latency sit on top and are measured on a device.
    final def = ExerciseDefinition.parse(
      File('../../content/exercises/bw_squat.json').readAsStringSync(),
    );
    final rule = def.rules.firstWhere((r) => r.id == 'knee_valgus');
    final frames = const SyntheticPose().squat(
      view: CameraView.front,
      reps: 6,
      valgus: 0.3,
      noiseStd: 0,
    );
    final session = ExerciseSession(
      definition: def,
      view: CameraView.front,
      config: const SessionConfig(smoothing: SmoothingConfig.none),
    );
    final scheduler = FeedbackScheduler(
      catalog: CueCatalog.parse(
        File('../../content/cues/cues.json').readAsStringSync(),
      ),
    );
    const evaluator = ExpressionEvaluator();

    final latencies = <int>[];
    int? trueSince;
    for (final f in frames) {
      final events = session.process(f);
      final fs = session.lastFeatures;
      final isTrue =
          fs != null && evaluator.eval(rule.exprAst, FrameScope(fs)).truthy;
      if (isTrue) {
        trueSince ??= f.timestampMs;
      } else {
        trueSince = null;
      }
      final cued = scheduler
          .handle(events, nowMs: f.timestampMs)
          .any((c) => c.ruleId == rule.id);
      if (cued && trueSince != null) {
        latencies.add(f.timestampMs - trueSince);
        trueSince = null; // next occurrence is a new measurement
      }
    }

    expect(latencies, isNotEmpty, reason: 'the rule never cued');
    latencies.sort();
    final worst = latencies.last;
    stdout.writeln(
      'cue latency: ${latencies.join(", ")} ms '
      '(median ${latencies[latencies.length ~/ 2]}, worst $worst)',
    );
    expect(worst, lessThan(400));
  });
}
